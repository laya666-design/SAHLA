const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
admin.initializeApp();

// Forfaits d'abonnement magasin — doivent rester identiques à
// `kSubscriptionPlans` côté Flutter (lib/services/marketplace_models.dart).
// Définis ici côté serveur pour que le prix ne dépende jamais de ce que
// le client envoie (sécurité : un client ne choisit qu'un planId, jamais
// un montant).
const PLANS = {
  mensuel: { nom: 'Mensuel', dureeJours: 30, prixDA: 2000 },
  trimestriel: { nom: 'Trimestriel', dureeJours: 90, prixDA: 5000 },
  annuel: { nom: 'Annuel', dureeJours: 365, prixDA: 18000 },
};

// Config Chargily Pay (à définir une fois avant déploiement) :
//   firebase functions:config:set chargily.secret_key="test_sk_xxx" \
//     chargily.webhook_secret="xxx" chargily.mode="test"
// Passer chargily.mode à "live" + une clé "live_sk_xxx" une fois prêt à
// encaisser réellement.
function chargilyConfig() {
  const cfg = functions.config().chargily || {};
  const live = cfg.mode === 'live';
  return {
    secretKey: cfg.secret_key,
    webhookSecret: cfg.webhook_secret,
    baseUrl: live
      ? 'https://pay.chargily.net/api/v2'
      : 'https://pay.chargily.net/test/api/v2',
  };
}

/**
 * Notifie tous les magasins actifs (avec token FCM enregistré) dès
 * qu'une nouvelle demande de pièce est diffusée.
 *
 * C'est LE morceau qui nécessite un vrai backend : la diffusion "push"
 * ne peut pas se faire depuis l'app cliente elle-même (elle n'a pas les
 * droits d'envoyer des notifications à d'autres utilisateurs). D'où
 * Cloud Functions ici.
 */
exports.notifyStoresOnNewRequest = functions.firestore
  .document('part_requests/{requestId}')
  .onCreate(async (snap) => {
    const requestData = snap.data();

    const storesSnap = await admin
      .firestore()
      .collection('stores')
      .where('actif', '==', true)
      .get();

    const tokens = storesSnap.docs
      .map((doc) => doc.data().fcmToken)
      .filter((t) => !!t);

    if (tokens.length === 0) {
      console.log('Aucun magasin actif avec token FCM — rien à notifier.');
      return null;
    }

    const message = {
      notification: {
        title: 'Nouvelle demande de pièce',
        body: requestData.pieceNom
          ? `Pièce recherchée : ${requestData.pieceNom}`
          : 'Un client recherche une pièce.',
      },
      data: {
        requestId: snap.id,
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `Notifications envoyées : ${response.successCount} succès, ${response.failureCount} échecs.`
    );
    return response;
  });

/**
 * Fait passer automatiquement à "expire" tout magasin dont l'essai
 * gratuit ou l'abonnement payé est terminé. Tourne une fois par jour.
 *
 * C'est nécessaire côté serveur (Admin SDK, donc au-delà des Firestore
 * Rules) : un client ne peut jamais modifier son propre
 * `subscriptionStatus` (voir firestore.rules), donc rien côté app ne
 * peut faire cette bascule — sinon un essai resterait "essai" pour
 * toujours une fois sa date dépassée.
 */
exports.checkExpiredSubscriptions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const db = admin.firestore();

    const essaisExpires = await db
      .collection('stores')
      .where('subscriptionStatus', '==', 'essai')
      .where('trialEndDate', '<=', now)
      .get();

    const abonnementsExpires = await db
      .collection('stores')
      .where('subscriptionStatus', '==', 'actif')
      .where('subscriptionEndDate', '<=', now)
      .get();

    const batch = db.batch();
    [...essaisExpires.docs, ...abonnementsExpires.docs].forEach((doc) => {
      batch.update(doc.ref, { subscriptionStatus: 'expire' });
    });

    const total = essaisExpires.size + abonnementsExpires.size;
    if (total === 0) {
      console.log('Aucun essai/abonnement à expirer aujourd\'hui.');
      return null;
    }
    await batch.commit();
    console.log(`${total} magasin(s) passé(s) en "expire".`);
    return null;
  });

/**
 * Valide une preuve de paiement reçue et active/renouvelle l'abonnement
 * du magasin. Réservée à un compte admin identifié (custom claim
 * `admin: true` sur le compte Firebase Auth de l'admin — voir plus bas
 * comment le poser).
 *
 * Sécurité : SEUL un utilisateur authentifié avec ce claim admin peut
 * appeler cette fonction. Sans ça, n'importe qui connaissant un
 * storeId/paymentId pouvait s'auto-valider un abonnement gratuitement.
 */
exports.validatePayment = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Réservé à un compte admin.'
    );
  }

  const { storeId, paymentId } = data;
  if (!storeId || !paymentId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'storeId et paymentId sont requis.'
    );
  }

  const db = admin.firestore();
  const storeRef = db.collection('stores').doc(storeId);
  const paymentRef = storeRef.collection('payment_requests').doc(paymentId);

  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Preuve de paiement introuvable.'
    );
  }
  const paymentData = paymentSnap.data();
  if (paymentData.statut !== 'en_attente') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Cette preuve de paiement est déjà "${paymentData.statut}".`
    );
  }

  // Durée selon le forfait choisi (planId stocké sur la preuve de
  // paiement) — avant ce correctif, un abonnement trimestriel ou annuel
  // n'était activé que pour 30 jours par erreur, quel que soit le prix
  // payé.
  const plan = PLANS[paymentData.planId] || PLANS.mensuel;
  const subscriptionEndDate = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + plan.dureeJours * 24 * 60 * 60 * 1000)
  );

  await db.runTransaction(async (tx) => {
    tx.update(paymentRef, {
      statut: 'valide',
      validePar: context.auth.uid,
      valideLe: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(storeRef, {
      subscriptionStatus: 'actif',
      subscriptionEndDate,
      currentPlanId: paymentData.planId || 'mensuel',
    });
  });

  return { success: true, subscriptionEndDate: subscriptionEndDate.toDate() };
});

/**
 * Liste toutes les preuves de paiement en attente, tous magasins
 * confondus — réservée à un compte admin (voir setAdmin.js). Utilise le
 * SDK admin (collectionGroup), donc pas besoin d'ouvrir les règles
 * Firestore pour ça : seule cette fonction peut voir les paiements de
 * tous les magasins à la fois.
 */
exports.listPendingPayments = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Réservé à un compte admin.'
    );
  }

  const db = admin.firestore();
  const snap = await db
    .collectionGroup('payment_requests')
    .where('statut', '==', 'en_attente')
    .orderBy('dateEnvoi', 'asc')
    .get();

  const results = await Promise.all(
    snap.docs.map(async (doc) => {
      const d = doc.data();
      const storeId = doc.ref.parent.parent.id;
      const storeSnap = await db.collection('stores').doc(storeId).get();
      const storeNom = storeSnap.exists ? storeSnap.data().nom : '(magasin inconnu)';
      return {
        paymentId: doc.id,
        storeId,
        storeNom,
        montant: d.montant,
        methode: d.methode,
        recuUrl: d.recuUrl,
        planId: d.planId || 'mensuel',
        dateEnvoi: d.dateEnvoi ? d.dateEnvoi.toDate().toISOString() : null,
      };
    })
  );

  return { payments: results };
});

/**
 * Refuse une preuve de paiement (ex: reçu illisible, montant incorrect).
 * Réservée à un compte admin — ne touche pas au statut de l'abonnement
 * du magasin, juste au statut de la preuve.
 */
exports.rejectPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Réservé à un compte admin.'
    );
  }

  const { storeId, paymentId, raison } = data;
  if (!storeId || !paymentId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'storeId et paymentId sont requis.'
    );
  }

  const paymentRef = db_ref(storeId, paymentId);
  await paymentRef.update({
    statut: 'refuse',
    raisonRefus: raison || null,
    traitePar: context.auth.uid,
    traiteLe: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Réinitialisation de mot de passe pour les comptes créés par téléphone
 * (magasin ou acheteur) : ces comptes utilisent un email technique
 * invisible ("0556653220@elbouni.local" / "@vroumclient.local") auquel
 * Firebase ne peut jamais livrer d'email réel.
 *
 * Solution 100% Firebase (pas de service tiers) : la première fois que
 * le magasin/acheteur demande une réinitialisation, on bascule l'email
 * réel du compte Firebase Auth vers l'adresse qu'il fournit (Admin SDK —
 * seule une fonction serveur peut changer l'email d'un compte auquel on
 * n'est pas connecté). Une fois ce changement fait, Firebase peut
 * envoyer nativement un vrai email de réinitialisation à cette adresse
 * (le client appelle ensuite `sendPasswordResetEmail` normalement).
 *
 * Demandes suivantes pour ce même numéro : l'email fourni doit
 * correspondre exactement à celui déjà associé, sinon la demande est
 * refusée (empêche n'importe qui connaissant juste le numéro de
 * détourner le compte).
 */
exports.attacherEmailRecuperationTelephone = functions.https.onCall(
  async (data, context) => {
    const numero = (data.telephone || '').toString().replace(/[^0-9]/g, '');
    const email = (data.email || '').toString().trim().toLowerCase();
    const type = data.type === 'buyer' ? 'buyer' : 'store';

    if (numero.length !== 10 || !numero.startsWith('0')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Numéro invalide.'
      );
    }
    if (!email || !email.includes('@')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email invalide.'
      );
    }

    const domaineTechnique = type === 'buyer' ? 'vroumclient.local' : 'elbouni.local';
    const emailTechniqueParDefaut = `${numero}@${domaineTechnique}`;
    const collection = type === 'buyer' ? 'buyer_accounts' : 'stores';

    const db = admin.firestore();
    const docRef = db.collection(collection).doc(numero);
    const doc = await docRef.get();
    const authEmailActuel =
      (doc.exists && doc.data().authEmail) || emailTechniqueParDefaut;

    // Vérifie que le compte Firebase Auth existe bien pour ce numéro.
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(authEmailActuel);
    } catch (e) {
      throw new functions.https.HttpsError(
        'not-found',
        'Aucun compte avec ce numéro.'
      );
    }

    const recuperationDejaFaite = authEmailActuel !== emailTechniqueParDefaut;

    if (recuperationDejaFaite) {
      // Une récupération a déjà eu lieu pour ce numéro : l'email fourni
      // doit correspondre exactement à celui déjà associé au compte.
      if (authEmailActuel.toLowerCase() !== email) {
        throw new functions.https.HttpsError(
          'permission-denied',
          "Cet email ne correspond pas à celui enregistré pour ce compte. Contacte le support si tu ne t'en souviens plus."
        );
      }
      // Rien à changer : l'email réel est déjà celui-là, le client peut
      // directement demander la réinitialisation Firebase standard.
      return { email: authEmailActuel };
    }

    // Première récupération pour ce numéro : on bascule l'email réel du
    // compte, afin que Firebase puisse ensuite lui envoyer un vrai email
    // de réinitialisation (natif, gratuit, sans service tiers).
    await admin.auth().updateUser(userRecord.uid, {
      email,
      emailVerified: false,
    });
    await docRef.set({ authEmail: email }, { merge: true });

    return { email };
  }
);

/**
 * Connexion admin par téléphone (secours si l'email est bloqué / oublié).
 *
 * Le lien numéro -> compte admin est créé UNE FOIS à l'avance, à la main,
 * via le script functions/linkAdminPhone.js (jamais depuis l'app) : il
 * écrit un doc `admin_phones/{numero}` = { uid }. Cette fonction est le
 * seul moyen de lire ce doc (les règles Firestore ne l'exposent à aucun
 * client) : elle vérifie que le compte a bien le claim admin, puis
 * renvoie son email actuel pour que le client fasse ensuite un
 * signInWithEmailAndPassword classique.
 */
exports.getAdminEmailByPhone = functions.https.onCall(async (data) => {
  const numero = (data.telephone || '').toString().replace(/[^0-9]/g, '');
  if (numero.length !== 10 || !numero.startsWith('0')) {
    throw new functions.https.HttpsError('invalid-argument', 'Numéro invalide.');
  }

  const db = admin.firestore();
  const lienDoc = await db.collection('admin_phones').doc(numero).get();
  if (!lienDoc.exists || !lienDoc.data().uid) {
    throw new functions.https.HttpsError(
      'not-found',
      'Aucun compte admin associé à ce numéro.'
    );
  }

  const uid = lienDoc.data().uid;
  let userRecord;
  try {
    userRecord = await admin.auth().getUser(uid);
  } catch (e) {
    throw new functions.https.HttpsError('not-found', 'Compte admin introuvable.');
  }

  const claims = userRecord.customClaims || {};
  if (claims.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Ce compte n\'a pas les droits admin.'
    );
  }
  if (!userRecord.email) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Ce compte admin n\'a pas d\'email associé.'
    );
  }

  return { email: userRecord.email };
});

function db_ref(storeId, paymentId) {
  return admin
    .firestore()
    .collection('stores')
    .doc(storeId)
    .collection('payment_requests')
    .doc(paymentId);
}

/**
 * Crée une session de paiement Chargily Pay pour le forfait choisi et
 * renvoie l'URL de checkout à ouvrir dans le navigateur. Appelée depuis
 * l'app (PaymentService.createCheckout) — jamais de clé secrète côté
 * client, tout part d'ici.
 */
exports.createChargilyCheckout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Connecte-toi d\'abord.');
  }
  const planId = data.planId;
  const plan = PLANS[planId];
  if (!plan) {
    throw new functions.https.HttpsError('invalid-argument', 'Forfait inconnu.');
  }

  const { secretKey, baseUrl } = chargilyConfig();
  if (!secretKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Paiement automatique non configuré (clé Chargily manquante).'
    );
  }

  // Même logique que StoreService.currentStoreDocId côté app : pour les
  // comptes téléphone + mot de passe, l'email technique est
  // "0556653220@elbouni.local" et le document magasin est stocké sous
  // "0556653220" (pas sous l'UID Firebase Auth généré). Pour les anciens
  // comptes (Google / email classique), on retombe sur l'UID.
  const authEmail = context.auth.token.email || '';
  const storeId = authEmail.endsWith('@elbouni.local')
    ? authEmail.split('@')[0]
    : context.auth.uid;

  const res = await fetch(`${baseUrl}/checkouts`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: plan.prixDA,
      currency: 'dzd',
      description: `Abonnement El Bouni Pièces Auto — forfait ${plan.nom}`,
      success_url: 'https://elbouni-pieces-auto.web.app/abonnement-succes',
      failure_url: 'https://elbouni-pieces-auto.web.app/abonnement-echec',
      webhook_endpoint:
        'https://us-central1-fakerni-b96c2.cloudfunctions.net/chargilyWebhook',
      locale: 'fr',
      metadata: { storeId, planId },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    console.error('Erreur création checkout Chargily :', res.status, errText);
    throw new functions.https.HttpsError(
      'internal',
      'Impossible de créer la session de paiement.'
    );
  }

  const checkout = await res.json();
  return { checkoutUrl: checkout.checkout_url };
});

/**
 * Webhook Chargily Pay : reçoit la confirmation "checkout.paid" et active
 * automatiquement l'abonnement du magasin concerné pour la durée du
 * forfait payé. C'est ce qui rend le paiement "automatique" — le magasin
 * n'a rien d'autre à faire une fois la carte validée sur la page Chargily.
 */
exports.chargilyWebhook = functions.https.onRequest(async (req, res) => {
  const { webhookSecret } = chargilyConfig();
  const signature = req.headers['signature'];

  if (webhookSecret) {
    const expected = crypto
      .createHmac('sha256', webhookSecret)
      .update(req.rawBody)
      .digest('hex');
    if (!signature || signature !== expected) {
      console.warn('Signature webhook Chargily invalide — requête ignorée.');
      res.status(401).send('Signature invalide.');
      return;
    }
  }

  const event = req.body;
  if (event.type !== 'checkout.paid') {
    // On ignore les autres événements (checkout.failed, etc.) — le
    // magasin reste simplement en 'paiement_en_attente'.
    res.status(200).send('OK');
    return;
  }

  const checkout = event.data;
  const storeId = checkout.metadata?.storeId;
  const planId = checkout.metadata?.planId;
  const plan = PLANS[planId];

  if (!storeId || !plan) {
    console.error('Webhook Chargily sans storeId/planId exploitable.', checkout.metadata);
    res.status(200).send('OK'); // on accuse réception quand même
    return;
  }

  const subscriptionEndDate = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + plan.dureeJours * 24 * 60 * 60 * 1000)
  );

  const db = admin.firestore();
  const storeRef = db.collection('stores').doc(storeId);
  const paymentRef = storeRef.collection('payment_requests').doc();

  await db.runTransaction(async (tx) => {
    tx.set(paymentRef, {
      storeId,
      planId,
      montant: plan.prixDA,
      methode: 'Chargily (carte)',
      statut: 'valide',
      dateEnvoi: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(storeRef, {
      subscriptionStatus: 'actif',
      subscriptionEndDate,
      currentPlanId: planId,
    });
  });

  console.log(`Abonnement activé automatiquement pour ${storeId} (${planId}).`);
  res.status(200).send('OK');
});

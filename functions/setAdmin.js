/**
 * Script à exécuter UNE SEULE FOIS EN LOCAL (jamais déployé, jamais dans
 * l'app) pour donner le droit admin à ton propre compte Firebase Auth.
 * Ce droit est ce qui te permet ensuite d'appeler validatePayment()
 * depuis l'app pour valider les paiements des magasins.
 *
 * Étapes :
 * 1. Console Firebase > Paramètres du projet > Comptes de service
 *    > "Générer une nouvelle clé privée" → télécharge le fichier JSON,
 *    place-le ici sous le nom "serviceAccountKey.json" (ne JAMAIS le
 *    commiter sur GitHub — ajoute-le à .gitignore).
 * 2. Récupère ton UID admin : Console Firebase > Authentication > liste
 *    des utilisateurs > copie l'UID du compte que tu veux rendre admin.
 * 3. Dans ce dossier (functions/) : npm install firebase-admin (si pas
 *    déjà fait), puis :
 *      node setAdmin.js TON_UID_ICI
 * 4. Déconnecte-toi et reconnecte-toi dans l'app avec ce compte (le
 *    nouveau claim n'est pris en compte qu'au prochain token).
 */
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
if (!uid) {
  console.error('Usage : node setAdmin.js <UID_DU_COMPTE_ADMIN>');
  process.exit(1);
}

admin
  .auth()
  .setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log(`✅ Le compte ${uid} est maintenant admin.`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Erreur :', err);
    process.exit(1);
  });

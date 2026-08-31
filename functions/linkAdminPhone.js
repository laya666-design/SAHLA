/**
 * Script à exécuter UNE SEULE FOIS EN LOCAL (jamais déployé, jamais dans
 * l'app) pour associer un numéro de téléphone à ton compte admin — utilisé
 * ensuite comme connexion de secours sur l'écran Espace Admin si l'email
 * est bloqué ou oublié.
 *
 * Prérequis : avoir déjà rendu le compte admin via setAdmin.js.
 *
 * Étapes :
 * 1. Même fichier serviceAccountKey.json que pour setAdmin.js (voir ce
 *    fichier si tu ne l'as pas déjà).
 * 2. Récupère l'UID du compte admin (Console Firebase > Authentication).
 * 3. Dans ce dossier (functions/) :
 *      node linkAdminPhone.js TON_UID_ICI 0556653220
 *    (numéro au format local à 10 chiffres, commençant par 0)
 * 4. Sur l'écran Espace Admin, l'onglet "Téléphone" fonctionne
 *    immédiatement avec ce numéro + le mot de passe du compte admin.
 */
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
const numeroBrut = process.argv[3];
const numero = (numeroBrut || '').replace(/[^0-9]/g, '');

if (!uid || numero.length !== 10 || !numero.startsWith('0')) {
  console.error(
    'Usage : node linkAdminPhone.js <UID_DU_COMPTE_ADMIN> <NUMERO_10_CHIFFRES_COMMENCANT_PAR_0>'
  );
  process.exit(1);
}

admin
  .auth()
  .getUser(uid)
  .then((user) => {
    if (!user.customClaims || user.customClaims.admin !== true) {
      console.error(
        `❌ Le compte ${uid} n'a pas encore le claim admin. Lance d'abord : node setAdmin.js ${uid}`
      );
      process.exit(1);
    }
    return admin.firestore().collection('admin_phones').doc(numero).set({ uid });
  })
  .then(() => {
    console.log(`✅ Le numéro ${numero} est maintenant lié au compte admin ${uid}.`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Erreur :', err);
    process.exit(1);
  });

# Phase 3 & 4 — mise en route

## Phase 3 — Bannière partenaire assurance ✅
Rien à configurer côté backend. La bannière (`lib/widgets/partner_banner.dart`)
s'affiche automatiquement dans l'écran Assurance dès que le badge passe en
orange/rouge (≤30j ou expiré). Pour brancher le vrai partenaire une fois le
contrat signé : modifie `_partnerName` et `_partnerUrl` dans ce fichier, puis
rebuild — pas besoin de backend pour ça.

## Phase 4 — Marketplace pièces

### 1) Active les services dans la console Firebase
Sur https://console.firebase.google.com, projet `el_bouni_pieces_auto` :
- **Firestore Database** → créer une base (mode production)
- **Storage** → activer (pour les photos des demandes)
- **Authentication** → activer le fournisseur **Email/Mot de passe**
  (utilisé pour les comptes magasins)

Ces trois services tournent sur le plan gratuit **Spark**, aucune carte
bancaire requise.

### 2) Déploie les règles de sécurité
```bash
firebase deploy --only firestore:rules
```
(le fichier `firestore.rules` est à la racine du projet)

### 3) Notifications push aux magasins — ⏸️ plus tard (payant)
Le code de la Cloud Function est prêt (`functions/index.js`), mais **je ne
le déploie pas maintenant** : Cloud Functions nécessite le plan **Blaze**
(carte bancaire enregistrée, même si l'usage réel reste dans le quota
gratuit). Comme demandé, on laisse ce qui implique un passage payant pour
plus tard.

En attendant, **le marketplace fonctionne quand même sans ça** : un magasin
avec l'app ouverte (dashboard Espace Pro) voit les nouvelles demandes
apparaître en temps réel via Firestore — il ne reçoit juste pas de
notification s'il a l'app fermée. Le jour où tu veux activer les push :
```bash
cd functions
npm install
firebase deploy --only functions
```

### 4) Index Firestore
Deux requêtes composites sont utilisées (`clientId` + `dateCreation`, et
`statut` + `dateCreation`). Firestore refusera ces requêtes tant que les
index n'existent pas — mais il te donnera **un lien direct** dans les logs
de l'app (ou dans la console Firebase) pour les créer en un clic la première
fois que la requête échoue. Pas besoin de les créer à la main.

### 5) Activer un magasin
Un magasin qui s'inscrit dans l'app est créé avec `actif: false` — il ne
voit ni ne reçoit aucune demande tant que tu ne l'as pas validé. Pour
l'activer : Firestore console → collection `stores` → document du magasin
→ passer `actif` à `true`. (Pas d'interface d'admin pour l'instant — à
prévoir si le volume de magasins grossit.)

### Ce qui reste volontairement simplifié (MVP)
- **Pas de filtre par proximité/catégorie** : tous les magasins actifs
  voient toutes les demandes ouvertes. À affiner plus tard (géoloc, filtre
  par type de pièce).
- **Pas d'app séparée pour les magasins** : ils utilisent la même app, via
  un espace "Pro" dédié (bouton boutique dans la barre du haut).
- **SMS / appel automatique en Premium** : toujours un mock (juste un
  interrupteur local). L'envoi réel nécessite un service tiers payant
  (Twilio ou équivalent) + une Cloud Function pour déclencher l'envoi —
  non construit, car ça implique un choix de fournisseur et de la
  facturation que je ne peux pas décider à ta place.

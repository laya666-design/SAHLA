# VROUM DZ — Choix de rôle (pack complet)

## Ce que contient ce pack

| Fichier | Action |
|---------|--------|
| `lib/models/user_role.dart` | **Nouveau** |
| `lib/screens/role_selection_screen.dart` | **Nouveau** |
| `lib/screens/rappels_screen.dart` | **Nouveau** |
| `lib/screens/marketplace/magasin_shell_screen.dart` | **Nouveau** |
| `lib/screens/sos/depanneuse_shell_screen.dart` | **Nouveau** |
| `lib/screens/splash_screen.dart` | **Remplacer** |
| `lib/services/vehicule_service.dart` | **Remplacer** (ou merger le bloc `userRole`) |
| `lib/services/sos_service.dart` | **Remplacer** (ajoute `myAcceptedAlertsStream`) |
| `lib/screens/home_screen.dart` | **Remplacer** (retire appui long SOS) |
| `lib/screens/marketplace/store_login_screen.dart` | **Remplacer** (redirige vers MagasinShell) |
| `lib/screens/marketplace/store_phone_login_screen.dart` | **Remplacer** (redirige vers MagasinShell) |
| `lib/screens/marketplace/store_complete_profile_screen.dart` | **Remplacer** (redirige vers MagasinShell) |
| `lib/screens/sos/depanneuse_portal_screen.dart` | **Remplacer** |
| `lib/screens/sos/depanneuse_auth_screen.dart` | **Remplacer** |

---

## Comment faire sur GitHub (garder l’ancienne version)

### 1. Ouvre ton projet local (clone GitHub)

```bash
cd chemin/vers/VROUM-DZ
# ou
git clone https://github.com/TON_USER/TON_REPO.git
cd TON_REPO
```

### 2. Crée une branche (main reste intact)

```bash
git checkout main
git pull
git checkout -b feature/role-selection
```

### 3. Copie les fichiers de ce pack

Depuis le dossier décompressé `vroum-role-complete/` :

```bash
# À adapter selon où tu as extrait le zip
SRC=~/Downloads/vroum-role-complete   # ou le chemin du pack

mkdir -p lib/models

cp "$SRC/lib/models/user_role.dart"                         lib/models/
cp "$SRC/lib/screens/role_selection_screen.dart"            lib/screens/
cp "$SRC/lib/screens/rappels_screen.dart"                   lib/screens/
cp "$SRC/lib/screens/splash_screen.dart"                    lib/screens/
cp "$SRC/lib/screens/home_screen.dart"                      lib/screens/
cp "$SRC/lib/services/vehicule_service.dart"                lib/services/
cp "$SRC/lib/services/sos_service.dart"                     lib/services/
cp "$SRC/lib/screens/marketplace/magasin_shell_screen.dart" lib/screens/marketplace/
cp "$SRC/lib/screens/marketplace/store_login_screen.dart"   lib/screens/marketplace/
cp "$SRC/lib/screens/marketplace/store_phone_login_screen.dart" lib/screens/marketplace/
cp "$SRC/lib/screens/marketplace/store_complete_profile_screen.dart" lib/screens/marketplace/
cp "$SRC/lib/screens/sos/depanneuse_shell_screen.dart"      lib/screens/sos/
cp "$SRC/lib/screens/sos/depanneuse_portal_screen.dart"     lib/screens/sos/
cp "$SRC/lib/screens/sos/depanneuse_auth_screen.dart"       lib/screens/sos/
```

### 4. Vérifie que ça compile

```bash
flutter pub get
flutter analyze
# ou
flutter run
```

### 5. Commit + push la branche

```bash
git add lib/
git status   # vérifie les fichiers

git commit -m "feat: choix de rôle au lancement + portails Magasin/Dépanneuse

- RoleSelectionScreen obligatoire au premier lancement
- 1 compte = 1 rôle (Hive SettingsService)
- MagasinShell: Demandes · Rappels · Profil + SOS discret
- DepanneuseShell: Alertes · Historique · Rappels · Profil (sans SOS)
- Splash route selon le rôle
- Retrait accès caché appui-long SOS"

git push -u origin feature/role-selection
```

### 6. Sur GitHub

- Va sur ton dépôt → branche `feature/role-selection`
- Tu peux ouvrir une **Pull Request** vers `main` plus tard
- Tant que tu n’as pas merge, **`main` = ancienne version**

---

## Test

1. Désinstalle l’app (ou efface les données) pour simuler un premier lancement
2. Lance → après le splash → **Qui es-tu ?**
3. Conducteur → onboarding / home + SOS
4. Magasin → login puis shell (Demandes / Rappels / Profil)
5. Dépanneuse → auth puis shell (Alertes / Historique / Rappels / Profil)
6. Relance l’app → doit rouvrir directement le bon portail

Pour retester le choix de rôle : effacer les données de l’app (le rôle est dans Hive).

---

## Architecture

```
Splash
  └─ pas de rôle → RoleSelectionScreen
  └─ conducteur  → Onboarding / HomeScreen (+ SOS flottant)
  └─ magasin     → MagasinShell (login si besoin)
  └─ dépanneuse  → DepanneuseShell (auth si besoin)
```

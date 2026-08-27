# Images de fond VROUM23

Dépose ici 4 photos (format .jpg, ~1200px de large suffit, poids < 300 Ko
chacune pour ne pas alourdir l'APK) avec exactement ces noms :

- `bg_voiture.jpg`   → derrière l'onglet Véhicules
- `bg_moto.jpg`      → derrière l'onglet Motos & scooters
- `bg_pieces.jpg`    → derrière l'onglet Pièces
- `bg_magasin.jpg`   → derrière l'Espace Pro Magasin

Tant qu'un fichier manque, l'écran affiche un dégradé + icône à la place
(rien ne casse), donc tu peux les ajouter un par un.

## Où trouver des photos gratuites (libres de droits, sans attribution)

- Pexels : https://www.pexels.com/fr-fr/recherche/voiture/
- Pixabay : https://pixabay.com/fr/images/search/voiture/

Choisis des photos assez sombres/contrastées en haut (le voile blanc de
l'app éclaircit le bas de l'image, le haut reste plus visible), et plutôt
au format paysage.

Une fois les 4 fichiers ajoutés ici, ils sont déjà déclarés dans
`pubspec.yaml` (dossier `assets/images/`) — aucune autre modification
n'est nécessaire, il suffit de relancer le build.

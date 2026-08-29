import 'package:flutter/material.dart';

/// Catégorie d'image de fond selon le contenu de l'écran.
enum BackgroundCategory { voiture, moto, pieces, magasin, generique }

/// Habille un écran avec une photo de fond thématique (voiture derrière
/// l'onglet Véhicules, moto derrière l'onglet Motos, etc.). Un voile
/// dégradé est posé entre la photo et le contenu (plus marqué en haut,
/// là où le titre n'a pas de carte derrière lui) pour garder le texte
/// lisible quelle que soit la luminosité de la photo, tout en laissant
/// la photo reconnaissable.
///
/// Les photos ne sont PAS embarquées ici (droits d'auteur, fiabilité) :
/// elles doivent être ajoutées par toi dans `assets/images/` — voir
/// `assets/images/README.md` pour les 4 fichiers attendus et des sources
/// gratuites. Tant qu'un fichier n'existe pas, l'écran affiche un fond
/// dégradé + une icône en filigrane à la place, donc rien ne casse.
class ScreenBackground extends StatelessWidget {
  final BackgroundCategory category;
  final Widget child;
  final Color accentColor;

  const ScreenBackground({
    super.key,
    required this.category,
    required this.child,
    this.accentColor = const Color(0xFF22C55E),
  });

  String get _assetPath {
    switch (category) {
      case BackgroundCategory.voiture:
        return 'assets/images/bg_voiture.jpg';
      case BackgroundCategory.moto:
        return 'assets/images/bg_moto.jpg';
      case BackgroundCategory.pieces:
        return 'assets/images/bg_pieces.jpg';
      case BackgroundCategory.magasin:
        return 'assets/images/bg_magasin.jpg';
      case BackgroundCategory.generique:
        return 'assets/images/bg_generique.jpg';
    }
  }

  IconData get _fallbackIcon {
    switch (category) {
      case BackgroundCategory.voiture:
        return Icons.directions_car;
      case BackgroundCategory.moto:
        return Icons.two_wheeler;
      case BackgroundCategory.pieces:
        return Icons.build;
      case BackgroundCategory.magasin:
        return Icons.storefront;
      case BackgroundCategory.generique:
        return Icons.directions_car_filled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo de fond si le fichier existe dans assets/images/, sinon
        // fallback dégradé + icône en filigrane.
        Image.asset(
          _assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accentColor.withValues(alpha: 0.07), Colors.white],
              ),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 36, right: 16),
                child: Icon(_fallbackIcon,
                    size: 110, color: accentColor.withValues(alpha: 0.10)),
              ),
            ),
          ),
        ),
        // Voile de lisibilité : blanc, plus marqué en haut (zone du
        // titre/sous-titre, sans carte derrière) et plus léger en bas
        // (zone des cartes, déjà opaques). Garde la photo reconnaissable
        // tout en assurant un contraste suffisant pour le texte sombre.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCCFFFFFF),
                Color(0x99FFFFFF),
                Color(0x66FFFFFF),
              ],
              stops: [0.0, 0.35, 1.0],
            ),
          ),
        ),
        // IMPORTANT : sans Positioned.fill, le child (souvent un Column
        // avec Expanded) ne reçoit pas de contraintes de hauteur serrées
        // et l'Expanded du ListView se retrouve avec une hauteur de 0 →
        // liste invisible alors que nbDocs > 0 (cas vu sur le dashboard
        // magasin).
        Positioned.fill(child: child),
      ],
    );
  }
}

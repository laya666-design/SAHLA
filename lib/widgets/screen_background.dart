import 'package:flutter/material.dart';

/// Catégorie d'image de fond selon le contenu de l'écran.
enum BackgroundCategory { voiture, moto, pieces, magasin, generique }

/// Habille un écran avec une photo de fond thématique (voiture derrière
/// l'onglet Véhicules, moto derrière l'onglet Motos, etc.) surmontée d'un
/// voile blanc pour garder le texte lisible.
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
        // Voile blanc dégradé : la photo reste visible en haut, le
        // contenu redevient parfaitement lisible plus bas.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.32],
              colors: [
                Colors.white.withValues(alpha: 0.60),
                Colors.white.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

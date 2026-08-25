import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

class _FixedStore {
  final String nom;
  final String adresse;
  const _FixedStore(this.nom, this.adresse);
}

const _elBouniStores = [
  _FixedStore('El Bouni Auto Pièces', 'Route principale, El Bouni, Annaba'),
  _FixedStore('Sidi Achour Pièces Auto', 'Sidi Achour, El Bouni, Annaba'),
  _FixedStore('Cours Annaba Pièces', 'Cours de la Révolution, Annaba'),
];

class MapScreen extends StatelessWidget {
  final AppConfig config;
  const MapScreen({super.key, required this.config});

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('El Bouni - Annaba',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Localise les magasins de pièces détachées.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),

          // Vignette au style de marque plutôt qu'un gris neutre générique.
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.10),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on,
                      size: 28, color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'El Bouni, Annaba',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openMaps('El Bouni Annaba pièces détachées'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir Google Maps El Bouni'),
          ),
          const SizedBox(height: 28),
          Text('Magasins', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ..._elBouniStores.map((s) => Card(
                shape: AppTheme.cardShape,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(s.nom,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.adresse),
                  trailing: IconButton(
                    icon: const Icon(Icons.directions),
                    color: AppColors.primary,
                    onPressed: () => _openMaps('${s.nom} ${s.adresse}'),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

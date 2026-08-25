import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
          Text('El Bouni - Annaba',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Localise les magasins de pièces détachées.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          // Placeholder de carte statique (pas de flutter_map -> évite les
          // instabilités de build listées dans le cahier des charges).
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 48, color: Colors.grey.shade500),
                const SizedBox(height: 8),
                Text('El Bouni, Annaba',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openMaps('El Bouni Annaba pièces détachées'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ouvrir Google Maps El Bouni'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: config.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Magasins',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ..._elBouniStores.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.storefront),
                  title: Text(s.nom),
                  subtitle: Text(s.adresse),
                  trailing: IconButton(
                    icon: const Icon(Icons.directions),
                    onPressed: () => _openMaps('${s.nom} ${s.adresse}'),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/sos_models.dart';

/// Écran affiché à la dépanneuse juste après avoir appuyé sur "J'y vais" :
/// confirme la prise en charge et donne tout de suite le numéro du client
/// et sa position, pour partir dépanner sans repasser par la liste.
class DepanneuseAlertAcceptedScreen extends StatelessWidget {
  final AppConfig config;
  final SosAlert alerte;

  const DepanneuseAlertAcceptedScreen({
    super.key,
    required this.config,
    required this.alerte,
  });

  Future<void> _appeler(String tel) async {
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _ouvrirCarte(String lien) async {
    final uri = Uri.parse(lien);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = config.sosColor;
    final lienMaps = alerte.lienMapsPosition;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: sos,
        foregroundColor: Colors.white,
        title: const Text('Alerte acceptée'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: config.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Panne prise en charge — Wilaya de ${alerte.wilaya}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Le client voit désormais ton nom et ton numéro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 28),
            if (alerte.clientTel.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _appeler(alerte.clientTel),
                  style: FilledButton.styleFrom(backgroundColor: config.primaryColor),
                  icon: const Icon(Icons.call),
                  label: Text('Appeler le client (${alerte.clientTel})'),
                ),
              )
            else
              const Text(
                'Numéro du client indisponible.',
                style: TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: lienMaps == null ? null : () => _ouvrirCarte(lienMaps),
                icon: const Icon(Icons.location_on_outlined),
                label: Text(
                  lienMaps == null
                      ? 'Position du véhicule non disponible'
                      : 'Voir la position du véhicule',
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour à la liste des alertes'),
            ),
          ],
        ),
      ),
    );
  }
}

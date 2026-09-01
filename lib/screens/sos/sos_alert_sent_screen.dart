import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/sos_models.dart';
import '../../services/sos_service.dart';

/// Écran affiché juste après l'envoi d'une alerte SOS : suit le statut
/// en direct ("En attente..." puis coordonnées de la dépanneuse qui a
/// accepté).
class SosAlertSentScreen extends StatelessWidget {
  final AppConfig config;
  final String alertId;
  final String wilaya;

  const SosAlertSentScreen({
    super.key,
    required this.config,
    required this.alertId,
    required this.wilaya,
  });

  Future<void> _appeler(String tel) async {
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _annuler(BuildContext context) async {
    await SosService.cancelAlert(alertId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sos = config.sosColor;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: sos,
        foregroundColor: Colors.white,
        title: const Text('Alerte SOS'),
      ),
      body: StreamBuilder<SosAlert?>(
        stream: SosService.watchAlert(alertId),
        builder: (context, snap) {
          final alerte = snap.data;
          final accepte = alerte?.estAcceptee ?? false;
          final annulee = alerte?.statut == SosStatus.annulee;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (annulee) ...[
                    const Icon(Icons.cancel_outlined, size: 64, color: Colors.black38),
                    const SizedBox(height: 16),
                    const Text('Alerte annulée.', style: TextStyle(fontSize: 18)),
                  ] else if (!accepte) ...[
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(color: sos, strokeWidth: 4),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Alerte envoyée aux dépanneuses de la wilaya de $wilaya',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'En attente qu\'une dépanneuse accepte...',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton(
                      onPressed: () => _annuler(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black54),
                      child: const Text('Annuler l\'alerte'),
                    ),
                  ] else ...[
                    Icon(Icons.check_circle, size: 64, color: config.primaryColor),
                    const SizedBox(height: 16),
                    const Text(
                      'Une dépanneuse arrive !',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alerte?.acceptedByDepanneuseNom ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    if ((alerte?.acceptedByDepanneuseTel ?? '').isNotEmpty)
                      Builder(builder: (context) {
                        final tel = alerte!.acceptedByDepanneuseTel!;
                        return SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => _appeler(tel),
                            style: FilledButton.styleFrom(backgroundColor: config.primaryColor),
                            icon: const Icon(Icons.call),
                            label: Text('Appeler $tel'),
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

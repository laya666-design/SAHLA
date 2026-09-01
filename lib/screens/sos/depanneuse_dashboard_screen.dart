import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/sos_models.dart';
import '../../services/sos_service.dart';

/// Tableau de bord dépanneuse : liste des alertes SOS ouvertes dans sa
/// wilaya, avec bouton "J'y vais" pour accepter (affiche alors le
/// téléphone de la dépanneuse côté utilisateur).
class DepanneuseDashboardScreen extends StatefulWidget {
  final AppConfig config;
  const DepanneuseDashboardScreen({super.key, required this.config});

  @override
  State<DepanneuseDashboardScreen> createState() =>
      _DepanneuseDashboardScreenState();
}

class _DepanneuseDashboardScreenState
    extends State<DepanneuseDashboardScreen> {
  late final Stream<DepanneuseProfile?> _profileStream =
      SosService.myProfileStream();

  @override
  void initState() {
    super.initState();
    SosService.saveFcmToken();
  }

  Future<void> _logout() async {
    await SosService.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _accepter(SosAlert alerte) async {
    try {
      await SosService.acceptAlert(alerte.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerte acceptée — ton numéro est visible côté client.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = widget.config.sosColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: sos,
        foregroundColor: Colors.white,
        title: const Text('Alertes SOS'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<DepanneuseProfile?>(
        stream: _profileStream,
        builder: (context, profileSnap) {
          if (!profileSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = profileSnap.data;
          if (profile == null) {
            return const Center(child: Text('Profil introuvable.'));
          }
          if (!profile.actif) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top, size: 48, color: Colors.orange.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Compte en attente de validation',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile.nom} — ${profile.wilaya}\nTon compte sera activé manuellement avant de recevoir les alertes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<List<SosAlert>>(
            stream: SosService.openAlertsForMyWilaya(profile.wilaya),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final alertes = snap.data!;
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: sos.withOpacity(0.08),
                    child: Text(
                      '${profile.nom} — Wilaya de ${profile.wilaya}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: sos),
                    ),
                  ),
                  if (alertes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Aucune alerte en attente dans ta wilaya.'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: alertes.length,
                        itemBuilder: (context, i) {
                          final a = alertes[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: sos.withOpacity(0.12),
                                child: Icon(Icons.sos, color: sos),
                              ),
                              title: Text(
                                'Panne — ${a.wilaya}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                a.aUnePosition
                                    ? 'Position GPS disponible\n${a.dateCreation.hour.toString().padLeft(2, '0')}:${a.dateCreation.minute.toString().padLeft(2, '0')}'
                                    : 'Sans position GPS\n${a.dateCreation.hour.toString().padLeft(2, '0')}:${a.dateCreation.minute.toString().padLeft(2, '0')}',
                              ),
                              isThreeLine: true,
                              trailing: FilledButton(
                                onPressed: () => _accepter(a),
                                style: FilledButton.styleFrom(backgroundColor: sos),
                                child: const Text("J'y vais"),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

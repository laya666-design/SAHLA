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

  // Cache du flux d'alertes par wilaya : sans ça, chaque nouvelle valeur
  // émise par _profileStream (ex: écriture du fcmToken juste après
  // l'ouverture de l'écran) recréait un tout nouveau flux Firestore ici,
  // qui repartait de zéro (même bug que l'onglet Commandes du portail
  // magasin, corrigé en hoistant le flux au lieu de le recréer à chaque
  // build).
  String? _wilayaEnCours;
  Stream<List<SosAlert>>? _alertesStream;

  Stream<List<SosAlert>> _alertesStreamPour(String wilaya) {
    if (_wilayaEnCours != wilaya) {
      _wilayaEnCours = wilaya;
      _alertesStream = SosService.openAlertsForMyWilaya(wilaya);
    }
    return _alertesStream!;
  }

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
          if (profileSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur profil : ${profileSnap.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!profileSnap.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Chargement du profil…'),
                ],
              ),
            );
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
            stream: _alertesStreamPour(profile.wilaya),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur requête alertes (wilaya="${profile.wilaya}") : ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text('Recherche des alertes pour "${profile.wilaya}"…'),
                    ],
                  ),
                );
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
                  // Bandeau de debug temporaire : confirme que le flux a bien
                  // répondu (0 alerte ou plus) — à retirer une fois le bug
                  // résolu.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.black87,
                    child: Text(
                      'DEBUG: ${alertes.length} alerte(s) trouvée(s) pour wilaya="${profile.wilaya}"',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ),
                  if (alertes.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Aucune alerte en attente dans ta wilaya.',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.black,
                      child: Text(
                        'IDs: ${alertes.map((a) => "${a.id.substring(0, a.id.length > 6 ? 6 : a.id.length)}/${a.statut}").join(", ")}',
                        style: const TextStyle(color: Colors.amber, fontSize: 10),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: alertes.length,
                        itemBuilder: (context, i) {
                          final a = alertes[i];
                          return Container(
                            color: Colors.yellow,
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '#$i — id=${a.id} statut=${a.statut} wilaya=${a.wilaya}',
                              style: const TextStyle(color: Colors.black, fontSize: 12),
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

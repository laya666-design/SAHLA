import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_config.dart';
import '../../services/marketplace_models.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import 'store_login_screen.dart';
import 'subscription_screen.dart';

class StoreDashboardScreen extends StatefulWidget {
  final AppConfig config;
  const StoreDashboardScreen({super.key, required this.config});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  // CORRECTIF (cause confirmée par le diagnostic) : le flux des demandes
  // est créé UNE SEULE FOIS ici, pas dans build(). Avant,
  // "StoreService.openRequests()" était appelé directement dans le
  // StreamBuilder plus bas -> comme ce widget est imbriqué dans un AUTRE
  // StreamBuilder (celui du profil magasin, qui se redéclenche à chaque
  // changement du document), Flutter annulait et recréait une toute
  // nouvelle requête Firestore à chaque reconstruction, avant qu'elle ait
  // eu le temps de recevoir sa première donnée -> écran bloqué en
  // "en attente" pour toujours, sans erreur visible.
  late final Stream<List<PartRequest>> _openRequestsStream =
      StoreService.openRequests();

  Future<void> _logout() async {
    await StoreService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StoreLoginScreen(config: widget.config)),
    );
  }

  Future<void> _repondre(PartRequest r) async {
    final prixController = TextEditingController();
    final stockController = TextEditingController();
    final messageController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Répondre — ${r.pieceNom}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: prixController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix (DA)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(labelText: 'Disponibilité (ex: En stock)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
        ],
      ),
    );

    if (ok != true) return;
    final prix = num.tryParse(prixController.text.trim());
    if (prix == null) return;

    await StoreService.respondToRequest(
      requestId: r.id,
      prix: prix,
      stock: stockController.text.trim(),
      message: messageController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réponse envoyée au client.')),
    );
  }

  void _voirPhoto(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StoreProfile?>(
      stream: StoreService.myProfileStream(),
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (profileSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur de chargement du profil :\n${profileSnap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }
        final profile = profileSnap.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(profile?.nom.isNotEmpty == true ? profile!.nom : 'Espace Pro'),
            actions: [
              if (profile != null && profile.actif)
                IconButton(
                  tooltip: 'Mon abonnement',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(config: widget.config, profile: profile),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                ),
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
            ],
          ),
          body: profile == null
              ? const Center(child: Text('Profil introuvable.'))
              : !profile.actif
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ton compte est en attente de validation.\n'
                          'Tu recevras les demandes une fois activé.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : !profile.accesDemandesAutorise
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock_clock,
                                      size: 32, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  profile.subscriptionStatus == SubscriptionStatus.enAttente
                                      ? 'Ton paiement est en cours de vérification.'
                                      : 'Ton essai gratuit ou ton abonnement est terminé.\n'
                                          'Choisis un forfait pour continuer à recevoir des commandes.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 20),
                                if (profile.subscriptionStatus != SubscriptionStatus.enAttente)
                                  FilledButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SubscriptionScreen(config: widget.config, profile: profile),
                                      ),
                                    ),
                                    child: const Text('Voir les forfaits'),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Row(
                                children: [
                                  Text('Commandes',
                                      style: Theme.of(context).textTheme.titleLarge),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('ID ${profile.idCourt}',
                                        style: const TextStyle(
                                            fontSize: 11, color: AppColors.primary)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: StreamBuilder<List<PartRequest>>(
                                stream: _openRequestsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(color: Colors.red),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          'Erreur de chargement des demandes :\n${snapshot.error}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.red, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }
                                  final requests = snapshot.data ?? [];
                                  if (requests.isEmpty) {
                                    return const Center(
                                        child: Text('Aucune commande pour le moment.',
                                            style: TextStyle(color: Colors.black, fontSize: 16)));
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: requests.length,
                                    itemBuilder: (context, i) {
                                      final r = requests[i];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: ListTile(
                                          onTap: () => _voirPhoto(r.photoUrl),
                                          leading: r.photoUrl.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.network(r.photoUrl,
                                                      width: 48, height: 48, fit: BoxFit.cover),
                                                )
                                              : Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryLight,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(Icons.build,
                                                      color: AppColors.primary),
                                                ),
                                          title: Text(r.pieceNom.isEmpty ? 'Pièce non nommée' : r.pieceNom),
                                          subtitle: Text(
                                            r.reference.isNotEmpty
                                                ? 'Réf: ${r.reference}'
                                                : (r.compatibilite.isNotEmpty ? r.compatibilite.join(', ') : ''),
                                            style: const TextStyle(
                                                fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          trailing: FilledButton(
                                            onPressed: () => _repondre(r),
                                            child: const Text('Répondre'),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
        );
      },
    );
  }
}

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../config/app_config.dart';
import '../../services/marketplace_models.dart';
import '../../services/store_service.dart';
import '../../widgets/screen_background.dart';
import 'store_phone_login_screen.dart';
import 'subscription_screen.dart';

class StoreDashboardScreen extends StatefulWidget {
  final AppConfig config;
  const StoreDashboardScreen({super.key, required this.config});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  final _player = AudioPlayer();
  String? _noteVocaleEnCours; // url en cours de lecture, pour l'icône

  // IMPORTANT : ces flux sont créés une seule fois ici (et non pas
  // directement dans `build()`). Un StreamBuilder qui reçoit une NOUVELLE
  // instance de Stream à chaque reconstruction repart en ConnectionState
  // .waiting et ré-abonne une toute nouvelle requête Firestore. Comme le
  // profil magasin (_profileStream) peut se réémettre (ex: écriture du
  // fcmToken juste après connexion), tout l'écran se reconstruisait et
  // relançait _openRequestsStream en boucle — c'était la cause probable
  // du dashboard qui restait vide/figé sans jamais afficher la liste, le
  // spinner ou "Aucune commande".
  late final Stream<StoreProfile?> _profileStream =
      StoreService.myProfileStream();
  late final Stream<List<PartRequest>> _openRequestsStream =
      StoreService.openRequests();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ecouterNoteVocale(String url) async {
    if (_noteVocaleEnCours == url) {
      await _player.stop();
      setState(() => _noteVocaleEnCours = null);
      return;
    }
    setState(() => _noteVocaleEnCours = url);
    await _player.play(UrlSource(url));
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _noteVocaleEnCours = null);
    });
  }

  Future<void> _logout() async {
    await StoreService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => StorePhoneLoginScreen(config: widget.config)),
    );
  }

  Future<void> _repondre(PartRequest r) async {
    final prixController = TextEditingController();
    final stockController = TextEditingController();
    final messageController = TextEditingController();

    final recorder = AudioRecorder();
    // Holder mutable pour éviter les soucis de closure avec StatefulBuilder
    final hold = _NoteHold();
    bool enregistrement = false;
    int duree = 0;
    DateTime? debut;
    bool envoiEnCours = false;
    String? cheminEnCours; // path du fichier en cours d'enregistrement

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> arreterEtCapturer() async {
              if (!enregistrement) return;
              final path = await recorder.stop();
              final file = (path != null && path.isNotEmpty) ? File(path) : null;
              // Vérifie que le fichier existe vraiment sur disque
              final okFile = file != null && await file.exists();
              setLocal(() {
                enregistrement = false;
                hold.file = okFile ? file : null;
                if (okFile && duree == 0 && debut != null) {
                  duree = DateTime.now().difference(debut!).inSeconds;
                }
              });
            }

            Future<void> basculerEnregistrement() async {
              if (enregistrement) {
                await arreterEtCapturer();
                return;
              }
              final autorise = await recorder.hasPermission();
              if (!autorise) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Autorisation microphone refusée.')),
                );
                return;
              }
              final dir = await getTemporaryDirectory();
              final path =
                  '${dir.path}/offre_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
              cheminEnCours = path;
              await recorder.start(const RecordConfig(), path: path);
              debut = DateTime.now();
              setLocal(() {
                enregistrement = true;
                duree = 0;
                hold.file = null;
              });
              while (enregistrement && ctx.mounted) {
                await Future.delayed(const Duration(seconds: 1));
                if (!enregistrement || !ctx.mounted) return;
                final ecoule = debut == null
                    ? 0
                    : DateTime.now().difference(debut!).inSeconds;
                setLocal(() => duree = ecoule);
                if (ecoule >= 30) {
                  await arreterEtCapturer();
                  return;
                }
              }
            }

            return AlertDialog(
              title: Text(
                'Répondre — ${r.pieceNom}',
                style: const TextStyle(fontSize: 17),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Note vocale EN HAUT
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hold.file != null
                            ? widget.config.primaryColor.withOpacity(0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hold.file != null
                              ? widget.config.primaryColor.withOpacity(0.4)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed:
                                envoiEnCours ? null : basculerEnregistrement,
                            icon: Icon(
                              enregistrement
                                  ? Icons.stop_circle
                                  : Icons.mic,
                              color: enregistrement
                                  ? Colors.red
                                  : widget.config.primaryColor,
                              size: 28,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              enregistrement
                                  ? 'Enregistrement… ${duree}s — appuie sur stop'
                                  : (hold.file != null
                                      ? '✓ Note vocale prête (${duree}s)'
                                      : 'Note vocale (optionnel)'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hold.file != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: enregistrement
                                    ? Colors.red
                                    : (hold.file != null
                                        ? widget.config.primaryColor
                                        : Colors.black54),
                              ),
                            ),
                          ),
                          if (hold.file != null && !enregistrement)
                            IconButton(
                              onPressed: envoiEnCours
                                  ? null
                                  : () => setLocal(() {
                                        hold.file = null;
                                        duree = 0;
                                      }),
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.black45),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: prixController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Prix (DA)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      decoration: const InputDecoration(
                          labelText: 'Disponibilité (ex: En stock)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Localisation',
                        hintText: 'Ex: El Bouni, près de la gare',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: envoiEnCours
                      ? null
                      : () async {
                          if (enregistrement) {
                            try {
                              await recorder.stop();
                            } catch (_) {}
                          }
                          if (ctx.mounted) Navigator.pop(ctx, false);
                        },
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: envoiEnCours
                      ? null
                      : () async {
                          final prix =
                              num.tryParse(prixController.text.trim());
                          if (prix == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Indique un prix valide.')),
                            );
                            return;
                          }
                          // TOUJOURS stopper et capturer avant l'envoi
                          if (enregistrement) {
                            await arreterEtCapturer();
                          }
                          // Fallback : si le stop n'a pas rempli hold.file
                          // mais qu'un chemin était connu
                          if (hold.file == null &&
                              cheminEnCours != null) {
                            final f = File(cheminEnCours!);
                            if (await f.exists()) hold.file = f;
                          }

                          setLocal(() => envoiEnCours = true);
                          try {
                            await StoreService.respondToRequest(
                              requestId: r.id,
                              prix: prix,
                              stock: stockController.text.trim(),
                              message: messageController.text.trim(),
                              noteVocale: hold.file,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setLocal(() => envoiEnCours = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        e.toString().replaceFirst(
                                            'Exception: ', ''))),
                              );
                            }
                          }
                        },
                  child: envoiEnCours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Envoyer'),
                ),
              ],
            );
          },
        );
      },
    );

    await recorder.dispose();
    if (ok != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hold.file != null
            ? 'Réponse + note vocale envoyées au client.'
            : 'Réponse envoyée au client.'),
      ),
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
      stream: _profileStream,
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // DEBUG TEMPORAIRE : avant, une erreur de lecture du profil
        // (permission-denied si l'ID du document ne correspond pas
        // exactement à l'UID connecté, etc.) était confondue avec un
        // profil simplement inexistant et affichait "Profil introuvable"
        // sans aucune indication. On distingue maintenant les deux cas.
        if (profileSnap.hasError) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: widget.config.primaryColor,
              foregroundColor: Colors.white,
              title: const Text('Espace Pro'),
              actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 36),
                    const SizedBox(height: 12),
                    const Text(
                      'Erreur en chargeant ton profil.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '${profileSnap.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final profile = profileSnap.data;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: widget.config.primaryColor,
            foregroundColor: Colors.white,
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
          body: ScreenBackground(
            category: BackgroundCategory.magasin,
            accentColor: widget.config.primaryColor,
            child: profile == null
              ? const Center(child: Text('Profil introuvable.'))
              : !profile.actif
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ton compte est en attente de validation.\n'
                          'Tu recevras les demandes une fois activé.',
                          textAlign: TextAlign.center,
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
                                Icon(Icons.lock_clock, size: 48, color: widget.config.primaryColor),
                                const SizedBox(height: 16),
                                Text(
                                  profile.subscriptionStatus == SubscriptionStatus.enAttente
                                      ? 'Ton paiement est en cours de vérification.'
                                      : 'Ton essai gratuit ou ton abonnement est terminé.\n'
                                          'Choisis un forfait pour continuer à recevoir des commandes.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                if (profile.subscriptionStatus != SubscriptionStatus.enAttente)
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: widget.config.primaryColor),
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
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('ID ${profile.idCourt}',
                                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  ),
                                ],
                              ),
                            ),
                            // StreamBuilder isolé : plus de Column+Expanded
                            // imbriqués (cause possible de hauteur 0 sur la
                            // liste malgré nbDocs > 0).
                            Expanded(
                              child: StreamBuilder<List<PartRequest>>(
                                stream: _openRequestsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.error_outline,
                                                color: Colors.red, size: 36),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Impossible de charger les commandes.',
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            SelectableText(
                                              '${snapshot.error}',
                                              style: const TextStyle(
                                                  fontSize: 12, color: Colors.black54),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final requests = snapshot.data ?? [];

                                  if (requests.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.inbox_outlined,
                                                  size: 36, color: Colors.black38),
                                              SizedBox(height: 10),
                                              Text(
                                                'Aucune commande pour le moment.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Liste des commandes
                                  return ColoredBox(
                                    color: const Color(0xF2FFFFFF),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                                      itemCount: requests.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, i) {
                                        return _carteCommande(requests[i]);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
          ),
        );
      },
    );
  }

  Widget _carteCommande(PartRequest r) {
    final sousTitre = r.reference.isNotEmpty
        ? 'Réf: ${r.reference}'
        : (r.compatibilite.isNotEmpty
            ? r.compatibilite.join(', ')
            : 'Sans référence');

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          if (r.photoUrl.isNotEmpty) _voirPhoto(r.photoUrl);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Photo ou icône
              if (r.photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    r.photoUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: widget.config.primaryColor.withOpacity(0.12),
                      child: Icon(Icons.build,
                          color: widget.config.primaryColor, size: 22),
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.config.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.build,
                      color: widget.config.primaryColor, size: 22),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.pieceNom.isEmpty ? 'Pièce non nommée' : r.pieceNom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sousTitre,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (r.aUneNoteVocale) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _ecouterNoteVocale(r.noteVocaleUrl!),
                  icon: Icon(
                    _noteVocaleEnCours == r.noteVocaleUrl
                        ? Icons.pause_circle
                        : Icons.play_circle_outline,
                    color: widget.config.primaryColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () => _repondre(r),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Répondre', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit conteneur mutable pour le fichier audio (évite les pièges
/// de closure dans StatefulBuilder).
class _NoteHold {
  File? file;
}


import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/location_service.dart';
import '../../services/marketplace_models.dart';
import '../../services/marketplace_service.dart';

class MesDemandesScreen extends StatefulWidget {
  final AppConfig config;
  const MesDemandesScreen({super.key, required this.config});

  @override
  State<MesDemandesScreen> createState() => _MesDemandesScreenState();
}

class _MesDemandesScreenState extends State<MesDemandesScreen> {
  final _player = AudioPlayer();
  String? _noteEnCours;
  /// IDs des demandes ouvertes — pour ne pas les refermer au setState (play).
  final Set<String> _ouvertes = {};

  // Position de l'acheteur, chargée une seule fois à l'ouverture de l'écran,
  // pour afficher "à X km" sous chaque réponse de magasin qui a une
  // position connue. Reste null si le GPS/permission n'est pas disponible
  // : la carte de la réponse s'affiche quand même, juste sans distance.
  LocationResult? _maPosition;

  @override
  void initState() {
    super.initState();
    _chargerMaPosition();
  }

  Future<void> _chargerMaPosition() async {
    final position = await LocationService.getCurrentPosition();
    if (mounted && position.aUnePosition) {
      setState(() => _maPosition = position);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _call(String tel) async {
    if (tel.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: tel));
  }

  Future<void> _voirSurLaCarte(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Distance en km entre l'acheteur (si connue) et le magasin, ou null.
  double? _distanceVers(PartOffer o) {
    if (_maPosition == null || !o.aUnePosition) return null;
    return LocationService.distanceKm(
      lat1: _maPosition!.latitude!,
      lng1: _maPosition!.longitude!,
      lat2: o.storeLat!,
      lng2: o.storeLng!,
    );
  }

  Future<void> _ecouterNote(String url) async {
    if (_noteEnCours == url) {
      await _player.stop();
      setState(() => _noteEnCours = null);
      return;
    }
    setState(() => _noteEnCours = url);
    await _player.play(UrlSource(url));
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _noteEnCours = null);
    });
  }

  Future<void> _marquerVendu(
      BuildContext context, PartRequest r, PartOffer o) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marquer comme vendue'),
        content: Text(
          'Confirmer que "${r.pieceNom}" a été achetée chez '
          '${o.storeNom.isEmpty ? 'ce magasin' : o.storeNom} '
          '(${o.prix} DA) ?\n\nLa demande sera clôturée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await MarketplaceService.markAsSold(requestId: r.id, offer: o);
  }

  String _statutLabel(PartRequest r) {
    switch (r.statut) {
      case 'open':
        return 'En attente de réponses';
      case 'vendu':
        return 'Vendue chez ${r.soldToStoreNom ?? ''}';
      default:
        return 'Clôturée';
    }
  }

  Color _statutColor(PartRequest r) {
    switch (r.statut) {
      case 'open':
        return Colors.orange;
      case 'vendu':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _bandeauNoteVocale(PartOffer o) {
    if (!o.aUneNoteVocale) return const SizedBox.shrink();
    final enCours = _noteEnCours == o.noteVocaleUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: widget.config.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _ecouterNote(o.noteVocaleUrl!),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  enCours ? Icons.pause_circle : Icons.play_circle_filled,
                  color: widget.config.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enCours
                        ? 'Lecture en cours…'
                        : 'Note vocale du magasin — appuyer pour écouter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.config.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.config.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Mes demandes'),
      ),
      body: StreamBuilder<List<PartRequest>>(
        stream: MarketplaceService.myRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur : ${snapshot.error}'),
              ),
            );
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Text('Aucune demande diffusée pour le moment.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final r = requests[i];
              final isOpen = _ouvertes.contains(r.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  // Clé stable + état mémorisé → ne se referme pas au play
                  key: PageStorageKey('demande_${r.id}'),
                  maintainState: true,
                  initiallyExpanded: isOpen,
                  onExpansionChanged: (open) {
                    setState(() {
                      if (open) {
                        _ouvertes.add(r.id);
                      } else {
                        _ouvertes.remove(r.id);
                      }
                    });
                  },
                  leading: r.photoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(r.photoUrl,
                              width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.build),
                  title: Text(r.pieceNom.isEmpty ? 'Pièce' : r.pieceNom),
                  subtitle: Text(
                    _statutLabel(r),
                    style: TextStyle(
                      color: _statutColor(r),
                      fontSize: 12,
                    ),
                  ),
                  children: [
                    if (!r.estOuverte && !r.estVendue)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Demande clôturée.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.black54)),
                      )
                    else
                      StreamBuilder<List<PartOffer>>(
                        stream: MarketplaceService.offersFor(r.id),
                        builder: (context, offerSnap) {
                          final offers = offerSnap.data ?? [];
                          if (offerSnap.connectionState ==
                                  ConnectionState.waiting &&
                              offers.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          if (offers.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Pas encore de réponse. Les magasins sont '
                                'notifiés, reviens un peu plus tard.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            );
                          }
                          return Column(
                            children: offers.map((o) {
                              final sousTitre = o.stock.isEmpty
                                  ? (o.message.isEmpty ? '' : o.message)
                                  : '${o.stock}${o.message.isNotEmpty ? ' — ${o.message}' : ''}';
                              final distance = _distanceVers(o);
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  // Vocal EN HAUT de l'offre
                                  _bandeauNoteVocale(o),
                                  ListTile(
                                    title: Text(
                                      o.storeNom.isEmpty
                                          ? 'Magasin'
                                          : o.storeNom,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sousTitre.isEmpty
                                              ? 'Sans précision'
                                              : sousTitre,
                                        ),
                                        if (o.aUnePosition)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.location_on,
                                                    size: 14,
                                                    color: widget
                                                        .config.primaryColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  distance != null
                                                      ? 'à $distance km de toi'
                                                      : 'Position connue',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: widget
                                                        .config.primaryColor,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    isThreeLine: o.aUnePosition,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${o.prix} DA',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        if (o.aUnePosition)
                                          IconButton(
                                            tooltip:
                                                'Voir le magasin sur la carte',
                                            icon: const Icon(Icons.map_outlined,
                                                size: 20),
                                            onPressed: () => _voirSurLaCarte(
                                                o.storeLat!, o.storeLng!),
                                          ),
                                        if (o.storeTel.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.call,
                                                size: 20),
                                            onPressed: () =>
                                                _call(o.storeTel),
                                          ),
                                        if (r.estOuverte)
                                          IconButton(
                                            tooltip: 'Marquer comme vendue',
                                            icon: const Icon(
                                                Icons.check_circle_outline,
                                                size: 20,
                                                color: Colors.green),
                                            onPressed: () => _marquerVendu(
                                                context, r, o),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

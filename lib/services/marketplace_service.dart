import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cloudinary_service.dart';
import 'marketplace_models.dart';

/// Marketplace pièces — côté demandeur (client).
///
/// Nécessite Firestore + Firebase Storage (Phase 4). Le client n'a pas de
/// compte visible (pas d'écran de connexion), mais utilise en coulisses
/// une connexion Firebase anonyme : c'est cet uid anonyme qui sert
/// d'identifiant de propriétaire (`clientId`) sur ses demandes, vérifié
/// par les règles Firestore. Avant ce correctif, le clientId était un ID
/// généré localement (donc lisible/imitable par n'importe qui, vu que
/// les demandes sont en lecture publique) : n'importe qui pouvait clôturer
/// ou marquer "vendue" la demande d'un autre client. La connexion
/// anonyme Firebase corrige ça : impossible de forger l'uid de
/// quelqu'un d'autre.
class MarketplaceService {
  static const _requestsCollection = 'part_requests';

  /// Garantit que le client a une session Firebase (anonyme) active et
  /// retourne son uid. À appeler avant toute lecture/écriture liée au
  /// client (créer une demande, lister "mes demandes", clôturer...).
  static Future<String> ensureSignedIn() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    return user!.uid;
  }

  static String? get clientId => FirebaseAuth.instance.currentUser?.uid;

  /// Diffuse une demande de pièce à tous les magasins actifs.
  /// Upload la photo (et la note vocale si fournie) puis crée le
  /// document Firestore. Un Cloud Function (voir /functions) notifie
  /// les magasins par push.
  static Future<String> broadcastRequest({
    required File photo,
    required String pieceNom,
    required String reference,
    required List<String> compatibilite,
    File? noteVocale,
  }) async {
    final uid = await ensureSignedIn();
    final id = FirebaseFirestore.instance.collection(_requestsCollection).doc().id;

    final photoUrl = await CloudinaryService.uploadImage(
      photo,
      folder: 'part_requests',
    );

    String? noteVocaleUrl;
    if (noteVocale != null) {
      // La note vocale est un ajout de confort : si son upload échoue
      // (réseau, format), on n'annule pas la demande pour autant — la
      // photo seule suffit pour que le magasin réponde.
      try {
        noteVocaleUrl = await CloudinaryService.uploadAudio(
          noteVocale,
          folder: 'part_requests_audio',
        );
      } catch (_) {
        noteVocaleUrl = null;
      }
    }

    final request = PartRequest(
      id: id,
      clientId: uid,
      pieceNom: pieceNom,
      reference: reference,
      compatibilite: compatibilite,
      photoUrl: photoUrl,
      noteVocaleUrl: noteVocaleUrl,
      statut: 'open',
      dateCreation: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection(_requestsCollection)
        .doc(id)
        .set(request.toMap());

    return id;
  }

  /// Mes demandes, les plus récentes d'abord.
  static Stream<List<PartRequest>> myRequests() async* {
    final uid = await ensureSignedIn();
    yield* FirebaseFirestore.instance
        .collection(_requestsCollection)
        .where('clientId', isEqualTo: uid)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PartRequest.fromDoc).toList());
  }

  /// Réponses des magasins pour une demande donnée, en temps réel,
  /// triées par prix croissant (les moins chères en premier).
  static Stream<List<PartOffer>> offersFor(String requestId) {
    return FirebaseFirestore.instance
        .collection(_requestsCollection)
        .doc(requestId)
        .collection('offers')
        .orderBy('prix')
        .snapshots()
        .map((s) => s.docs.map(PartOffer.fromDoc).toList());
  }

  static Future<void> closeRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection(_requestsCollection)
        .doc(requestId)
        .update({'statut': 'closed'});
  }

  /// Marque la demande comme vendue chez le magasin sélectionné : elle
  /// disparaît immédiatement des demandes ouvertes des magasins (la tâche
  /// est "terminée") et garde une trace de qui l'a vendue.
  static Future<void> markAsSold({
    required String requestId,
    required PartOffer offer,
  }) async {
    await FirebaseFirestore.instance
        .collection(_requestsCollection)
        .doc(requestId)
        .update({
      'statut': 'vendu',
      'soldToStoreId': offer.storeId,
      'soldToStoreNom': offer.storeNom,
      'dateVente': FieldValue.serverTimestamp(),
    });
  }
}


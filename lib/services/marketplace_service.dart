import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloudinary_service.dart';
import 'marketplace_models.dart';

/// Marketplace pièces — côté demandeur (client / acheteur).
///
/// Connexion par numéro de téléphone enregistré comme identifiant
/// (`clientId` = numéro normalisé +213…). Pas de SMS / WhatsApp.
/// La session persiste grâce à SharedPreferences : retour en arrière
/// ne déconnecte pas.
class MarketplaceService {
  static const _requestsCollection = 'part_requests';
  static const _phoneAsIdKey = 'buyer_phone_as_id';

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Numéro sauvegardé comme identifiant.
  static String? _phoneAsId;

  /// Connecté avec un numéro enregistré.
  static bool get isPhoneLoggedIn =>
      _phoneAsId != null && _phoneAsId!.isNotEmpty;

  /// Une session existe (numéro-as-id ou Firebase anonyme).
  static bool get hasSession =>
      (_phoneAsId != null && _phoneAsId!.isNotEmpty) || currentUser != null;

  /// Charge le numéro sauvegardé (à appeler avant de décider de la navigation).
  static Future<void> loadPhoneAsId() async {
    final prefs = await SharedPreferences.getInstance();
    _phoneAsId = prefs.getString(_phoneAsIdKey);
  }

  /// Enregistre le numéro comme identifiant et crée une session anonyme si besoin.
  static Future<String> connectWithPhoneAsId(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneAsIdKey, phoneNumber);
    _phoneAsId = phoneNumber;
    await ensureSignedIn();
    return phoneNumber;
  }

  /// Garantit une session Firebase et retourne l'identifiant des demandes
  /// (numéro prioritaire, sinon uid).
  static Future<String> ensureSignedIn() async {
    // Recharge au cas où (ex: après hot-reload).
    if (_phoneAsId == null) {
      await loadPhoneAsId();
    }
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    if (_phoneAsId != null && _phoneAsId!.isNotEmpty) {
      return _phoneAsId!;
    }
    return user!.uid;
  }

  /// Identifiant des demandes : numéro de téléphone prioritaire.
  static String? get clientId {
    if (_phoneAsId != null && _phoneAsId!.isNotEmpty) return _phoneAsId;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneAsIdKey);
    _phoneAsId = null;
    await FirebaseAuth.instance.signOut();
  }

  /// Diffuse une demande de pièce à tous les magasins actifs.
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

  /// Réponses des magasins pour une demande donnée.
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

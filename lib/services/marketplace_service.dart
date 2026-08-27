import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cloudinary_service.dart';
import 'marketplace_models.dart';

/// Marketplace pièces — côté demandeur (client / acheteur).
///
/// L'acheteur peut se connecter par téléphone/SMS (méthode principale,
/// comme le magasin) pour retrouver ses demandes sur un autre appareil.
/// Sans connexion, une session Firebase anonyme est créée en coulisses :
/// l'uid sert d'identifiant de propriétaire (`clientId`) sur ses
/// demandes. La connexion anonyme empêche de forger l'uid d'un autre
/// client.
class MarketplaceService {
  static const _requestsCollection = 'part_requests';

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Connecté avec un numéro de téléphone (pas anonyme).
  static bool get isPhoneLoggedIn {
    final user = currentUser;
    return user != null &&
        !user.isAnonymous &&
        (user.phoneNumber != null && user.phoneNumber!.isNotEmpty);
  }

  /// Garantit que le client a une session Firebase active et retourne
  /// son uid. Si déjà connecté (téléphone ou autre), on réutilise la
  /// session ; sinon connexion anonyme.
  static Future<String> ensureSignedIn() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    return user!.uid;
  }

  static String? get clientId => FirebaseAuth.instance.currentUser?.uid;

  // --- Authentification téléphone/SMS (acheteur) ---

  /// Lance l'envoi du code SMS. [phoneNumber] au format international
  /// (ex: "+213556653220").
  static Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  }) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          onAutoVerified();
        } catch (e) {
          onError('$e');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(_messageErreurTelephone(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        onCodeSent(verificationId);
      },
    );
  }

  static String _messageErreurTelephone(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Numéro invalide. Vérifie le format (ex: 0556 65 32 20).';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie plus tard.';
      case 'quota-exceeded':
        return 'Service SMS temporairement indisponible. Réessaie plus tard.';
      default:
        return e.message ?? 'Erreur d\'envoi du SMS.';
    }
  }

  /// Valide le code SMS et connecte l'acheteur (crée le compte Auth
  /// s'il n'existait pas encore). Pas de profil magasin : l'uid sert
  /// uniquement de clientId pour les demandes.
  static Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

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


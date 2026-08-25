import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Espace admin : validation des preuves de paiement manuel.
///
/// Réutilise le même compte Firebase Auth que l'espace magasin, mais un
/// compte n'est admin que s'il a le custom claim `admin: true` (posé une
/// fois via functions/setAdmin.js — jamais depuis l'app). Toute la
/// vérification des droits se fait côté serveur (Cloud Functions), donc
/// même si quelqu'un accède à cet écran sans être admin, les appels
/// échoueront proprement.
class AdminService {
  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Vérifie que l'utilisateur connecté a bien le claim admin.
  /// `force: true` rafraîchit le token — nécessaire juste après qu'un
  /// claim a été posé, car un token déjà émis ne le contient pas encore.
  static Future<bool> isCurrentUserAdmin({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(force);
    return token.claims?['admin'] == true;
  }

  static Future<List<Map<String, dynamic>>> listPendingPayments() async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('listPendingPayments');
    final result = await callable.call();
    final payments = (result.data?['payments'] as List?) ?? [];
    return payments.cast<Map<String, dynamic>>();
  }

  static Future<void> validatePayment({
    required String storeId,
    required String paymentId,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('validatePayment');
    await callable.call({'storeId': storeId, 'paymentId': paymentId});
  }

  static Future<void> rejectPayment({
    required String storeId,
    required String paymentId,
    String? raison,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('rejectPayment');
    await callable.call({
      'storeId': storeId,
      'paymentId': paymentId,
      if (raison != null) 'raison': raison,
    });
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();
}

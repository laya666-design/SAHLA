import 'package:cloud_functions/cloud_functions.dart';

/// Paiement automatique de l'abonnement magasin via Chargily Pay
/// (passerelle algérienne — cartes CIB / Edahabia). La création du
/// checkout et la confirmation du paiement se font côté Cloud Functions
/// (voir /functions/index.js) : l'app ne manipule jamais de clé secrète.
class PaymentService {
  /// Crée une session de paiement pour le forfait choisi et renvoie
  /// l'URL de paiement hébergée par Chargily à ouvrir dans le
  /// navigateur. Le webhook Chargily active l'abonnement automatiquement
  /// dès le paiement confirmé — aucune preuve à envoyer manuellement.
  static Future<String> createCheckout(String planId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('createChargilyCheckout');
    final result = await callable.call({'planId': planId});
    final url = result.data?['checkoutUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Lien de paiement indisponible.');
    }
    return url;
  }
}

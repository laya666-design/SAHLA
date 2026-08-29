import 'package:geolocator/geolocator.dart';

/// Résultat d'une tentative de géolocalisation : soit une position, soit
/// une raison d'échec lisible pour l'utilisateur (permission refusée,
/// GPS désactivé...). On ne bloque jamais un flux (inscription, envoi de
/// demande) sur l'absence de position : c'est toujours "best effort".
class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? erreur;

  const LocationResult({this.latitude, this.longitude, this.erreur});

  bool get aUnePosition => latitude != null && longitude != null;
}

/// Centralise la géolocalisation réelle (GPS) utilisée pour :
/// - enregistrer la position d'un magasin à son inscription
/// - calculer la distance entre l'acheteur et un magasin qui a répondu
class LocationService {
  /// Récupère la position actuelle de l'appareil, en gérant permissions
  /// et service GPS désactivé. Ne lance jamais d'exception : retourne un
  /// [LocationResult] avec `erreur` renseigné en cas d'échec.
  static Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceActif = await Geolocator.isLocationServiceEnabled();
      if (!serviceActif) {
        return const LocationResult(
          erreur: 'Le GPS est désactivé sur ce téléphone.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          erreur: 'Permission de localisation refusée.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          erreur: 'Localisation bloquée pour cette app dans les réglages '
              'du téléphone.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      return LocationResult(erreur: 'Position indisponible : $e');
    }
  }

  /// Distance en kilomètres entre deux points GPS (arrondie à 1 décimale).
  static double distanceKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final metres = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return (metres / 100).round() / 10;
  }
}

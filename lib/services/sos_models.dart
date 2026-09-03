import 'package:cloud_firestore/cloud_firestore.dart';

/// Statuts possibles d'une alerte SOS.
class SosStatus {
  static const ouverte = 'ouverte'; // envoyée, en attente d'une dépanneuse
  static const acceptee = 'acceptee'; // une dépanneuse a répondu
  static const annulee = 'annulee'; // annulée par l'utilisateur
}

/// Une alerte de panne envoyée par un utilisateur en panne, diffusée aux
/// dépanneuses de sa wilaya (pas de calcul de distance en km — voir
/// [[app-auto]] : rattachement par wilaya uniquement).
class SosAlert {
  final String id;
  final String clientId;
  final String clientTel;
  final String wilaya;
  final double? latitude;
  final double? longitude;
  final String statut;
  final DateTime dateCreation;
  final String? acceptedByDepanneuseId;
  final String? acceptedByDepanneuseNom;
  final String? acceptedByDepanneuseTel;
  final DateTime? dateAcceptation;

  SosAlert({
    required this.id,
    required this.clientId,
    this.clientTel = '',
    required this.wilaya,
    this.latitude,
    this.longitude,
    required this.statut,
    required this.dateCreation,
    this.acceptedByDepanneuseId,
    this.acceptedByDepanneuseNom,
    this.acceptedByDepanneuseTel,
    this.dateAcceptation,
  });

  bool get aUnePosition => latitude != null && longitude != null;
  bool get estOuverte => statut == SosStatus.ouverte;
  bool get estAcceptee => statut == SosStatus.acceptee;

  /// Lien Google Maps pointant vers la position du véhicule en panne,
  /// utilisable par la dépanneuse pour s'y rendre. Null si pas de
  /// position GPS disponible.
  String? get lienMapsPosition => aUnePosition
      ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      : null;

  factory SosAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SosAlert(
      id: doc.id,
      clientId: d['clientId']?.toString() ?? '',
      clientTel: d['clientTel']?.toString() ?? '',
      wilaya: d['wilaya']?.toString() ?? '',
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      statut: d['statut']?.toString() ?? SosStatus.ouverte,
      dateCreation:
          (d['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedByDepanneuseId: d['acceptedByDepanneuseId']?.toString(),
      acceptedByDepanneuseNom: d['acceptedByDepanneuseNom']?.toString(),
      acceptedByDepanneuseTel: d['acceptedByDepanneuseTel']?.toString(),
      dateAcceptation: (d['dateAcceptation'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientTel': clientTel,
        'wilaya': wilaya,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'statut': statut,
        'dateCreation': FieldValue.serverTimestamp(),
      };
}

/// Profil d'un compte dépanneuse (remorquage), accès caché — pas de menu
/// visible dans l'app, uniquement via un appui long sur le bouton SOS.
class DepanneuseProfile {
  final String uid;
  final String nom;
  final String tel;
  final String wilaya;
  final bool actif; // validation manuelle, comme pour les magasins
  final String? fcmToken;
  final double? latitude;
  final double? longitude;

  DepanneuseProfile({
    required this.uid,
    required this.nom,
    required this.tel,
    required this.wilaya,
    required this.actif,
    this.fcmToken,
    this.latitude,
    this.longitude,
  });

  factory DepanneuseProfile.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DepanneuseProfile(
      uid: doc.id,
      nom: d['nom']?.toString() ?? '',
      tel: d['tel']?.toString() ?? '',
      wilaya: d['wilaya']?.toString() ?? '',
      actif: d['actif'] as bool? ?? false,
      fcmToken: d['fcmToken']?.toString(),
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'tel': tel,
        'wilaya': wilaya,
        'actif': actif,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

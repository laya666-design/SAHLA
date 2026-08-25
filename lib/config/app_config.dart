import 'package:flutter/material.dart';

/// El Bouni Pièces Auto — rouge — package com.elbouni.annaba
/// (variante unique ; l'ancienne variante bleue "Annaba Edition" a été retirée)
class AppConfig {
  final String appName;
  final Color primaryColor;
  final Color primaryDark;
  final String baridimobPhone;

  const AppConfig._({
    required this.appName,
    required this.primaryColor,
    required this.primaryDark,
    required this.baridimobPhone,
  });

  static const _instance = AppConfig._(
    appName: 'El Bouni Pièces Auto',
    primaryColor: Color(0xFFDC2626), // rouge
    primaryDark: Color(0xFFA31515),
    // Numéro BaridiMob où les magasins envoient leur paiement manuel
    // d'abonnement (repli quand ils n'ont pas de carte CIB/Edahabia).
    baridimobPhone: '0556653220',
  );

  static AppConfig current() => _instance;
}

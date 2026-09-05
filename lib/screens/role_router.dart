import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../main.dart';
import '../models/user_role.dart';
import '../services/vehicule_service.dart';
import 'home_screen.dart';
import 'onboarding_profile_screen.dart';
import 'marketplace/magasin_shell_screen.dart';
import 'sos/depanneuse_shell_screen.dart';
import 'role_selection_screen.dart';

/// Centralise "étant donné le rôle choisi, quel écran ouvrir ?" — utilisé
/// au démarrage (SplashScreen) ET juste après le choix initial
/// (RoleSelectionScreen), pour ne jamais dupliquer cette logique à deux
/// endroits différents.
class RoleRouter {
  /// Résout l'écran à afficher pour le rôle actuellement stocké.
  /// Si aucun rôle n'a encore été choisi, retourne l'écran de choix.
  static Widget resolve({
    required AppConfig config,
    required ValueNotifier<bool> isAr,
  }) {
    final role = SettingsService.userRole;

    if (role == null) {
      return RoleSelectionScreen(config: config, isAr: isAr);
    }

    switch (role) {
      case UserRole.conducteur:
        return SettingsService.hasChosenVehicleProfile
            ? HomeScreen(config: config, isAr: isAr)
            : OnboardingProfileScreen(
                config: config,
                isAr: isAr,
                onChosen: (value) => SettingsService.setVehicleProfile(value),
              );

      case UserRole.magasin:
        return MagasinShellScreen(config: config, isAr: isAr.value);

      case UserRole.depanneuse:
        return DepanneuseShellScreen(config: config, isAr: isAr.value);
    }
  }

  /// Enregistre le rôle choisi puis navigue vers l'écran correspondant.
  static Future<void> selectRole(
    BuildContext context, {
    required UserRole role,
    required AppConfig config,
    required ValueNotifier<bool> isAr,
  }) async {
    await SettingsService.setUserRole(role);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => resolve(config: config, isAr: isAr),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Réinitialise le rôle choisi et relance l'app depuis zéro (retour à
  /// l'écran de choix de rôle). Un simple push vers RoleSelectionScreen
  /// ne suffit pas : HomeScreen a besoin du MÊME ValueNotifier<bool>
  /// isAr que celui du MaterialApp racine (main.dart) pour que la
  /// bascule FR/AR continue de fonctionner après un changement de
  /// profil — relancer AjalakApp au complet recrée les deux ensemble,
  /// toujours synchronisés (pas de nouveau isAr orphelin déconnecté du
  /// MaterialApp réel).
  static Future<void> changerDeProfil(BuildContext context) async {
    await SettingsService.clearUserRole();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AjalakApp()),
      (route) => false,
    );
  }
}

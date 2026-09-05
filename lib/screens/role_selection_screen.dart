import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../main.dart';
import '../services/sos_service.dart';
import '../services/store_service.dart';
import '../services/vehicule_service.dart';
import 'home_screen.dart';
import 'marketplace/store_dashboard_screen.dart';
import 'marketplace/store_phone_login_screen.dart';
import 'onboarding_profile_screen.dart';
import 'sos/depanneuse_auth_screen.dart';
import 'sos/depanneuse_dashboard_screen.dart';

/// Centralise "étant donné le rôle choisi, quel écran ouvrir ?" — utilisé
/// au démarrage (SplashScreen) ET juste après le choix initial
/// (RoleSelectionScreen), pour ne jamais dupliquer cette logique à deux
/// endroits différents.
class RoleRouter {
  /// Résout l'écran à afficher pour le rôle actuellement stocké. À
  /// appeler seulement si SettingsService.hasChosenRole est vrai (ou
  /// juste après un setUserRole).
  static Future<Widget> resolve({
    required AppConfig config,
    required ValueNotifier<bool> isAr,
  }) async {
    switch (SettingsService.userRole) {
      case 'magasin':
        await StoreService.loadPhoneAsId();
        return StoreService.isLoggedIn
            ? StoreDashboardScreen(config: config)
            : StorePhoneLoginScreen(config: config);

      case 'depanneuse':
        await SosService.loadPhoneAsId();
        return SosService.isDepanneuseLoggedIn
            ? DepanneuseDashboardScreen(config: config)
            : DepanneuseAuthScreen(config: config);

      case 'conducteur':
      default:
        return SettingsService.hasChosenVehicleProfile
            ? HomeScreen(config: config, isAr: isAr)
            : OnboardingProfileScreen(
                config: config,
                isAr: isAr,
                onChosen: (value) => SettingsService.setVehicleProfile(value),
              );
    }
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

/// Premier écran vu au tout premier lancement (avant même l'onboarding
/// véhicule) : décide si l'app s'ouvre côté conducteur, magasin ou
/// dépanneuse. Choix mémorisé localement (SettingsService.userRole),
/// modifiable ensuite via "Changer de profil" dans chaque portail.
/// Écran volontairement en français uniquement (comme les portails
/// magasin/dépanneuse déjà existants) : très court, vu une seule fois.
class RoleSelectionScreen extends StatefulWidget {
  final AppConfig config;
  final ValueNotifier<bool> isAr;

  const RoleSelectionScreen({
    super.key,
    required this.config,
    required this.isAr,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _loading = false;

  Future<void> _choisir(String role) async {
    if (_loading) return;
    setState(() => _loading = true);
    await SettingsService.setUserRole(role);
    if (!mounted) return;
    final next = await RoleRouter.resolve(
      config: widget.config,
      isAr: widget.isAr,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                widget.config.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tu es...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.directions_car,
                title: 'Conducteur',
                subtitle: 'Mes véhicules, pièces détachées, rappels, SOS.',
                color: widget.config.primaryColor,
                enabled: !_loading,
                onTap: () => _choisir('conducteur'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.storefront_outlined,
                title: 'Magasin',
                subtitle: 'Recevoir les demandes de pièces, abonnement.',
                color: Colors.black87,
                enabled: !_loading,
                onTap: () => _choisir('magasin'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.local_shipping_outlined,
                title: 'Dépanneuse',
                subtitle: 'Recevoir les alertes de panne de ma wilaya.',
                color: widget.config.sosColor,
                enabled: !_loading,
                onTap: () => _choisir('depanneuse'),
              ),
              const SizedBox(height: 24),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

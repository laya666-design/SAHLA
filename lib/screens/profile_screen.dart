import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/vehicule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_background.dart';
import 'admin/admin_login_screen.dart';

/// Onglet Profil : remplace l'ancien onglet Carte (statique, peu utile).
/// Regroupe le statut du compte, les réglages (langue, rappels) et le
/// support — tout ce dont l'utilisateur a besoin en dehors des rubriques
/// véhicules/pièces.
class ProfileScreen extends StatefulWidget {
  final AppConfig config;
  final ValueNotifier<bool> isAr;
  final VoidCallback? onVehicleProfileChanged;

  const ProfileScreen({
    super.key,
    required this.config,
    required this.isAr,
    this.onVehicleProfileChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'contact@elbouni-pieces-auto.dz',
      query:
          'subject=${Uri.encodeComponent("Support - ${widget.config.appName}")}',
    );
    await launchUrl(uri);
  }

  void _showPremiumComingSoon(
      BuildContext context, String Function(String, String) t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Bientôt disponible', 'قريباً'))),
    );
  }

  String _vehicleProfileLabel(String Function(String, String) t) {
    switch (SettingsService.vehicleProfile) {
      case 'voiture':
        return t('Voiture', 'سيارة');
      case 'moto':
        return t('Moto / Scooter', 'دراجة نارية / سكوتر');
      default:
        return t('Les deux', 'كلاهما');
    }
  }

  Future<void> _showVehicleProfilePicker(
      BuildContext context, String Function(String, String) t) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(t('Voiture', 'سيارة')),
              onTap: () => Navigator.pop(ctx, 'voiture'),
            ),
            ListTile(
              leading: const Icon(Icons.two_wheeler),
              title: Text(t('Moto / Scooter', 'دراجة نارية / سكوتر')),
              onTap: () => Navigator.pop(ctx, 'moto'),
            ),
            ListTile(
              leading: const Icon(Icons.sync_alt),
              title: Text(t('Les deux', 'كلاهما')),
              onTap: () => Navigator.pop(ctx, 'both'),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await SettingsService.setVehicleProfile(chosen);
    setState(() {});
    widget.onVehicleProfileChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isAr,
      builder: (context, isAr, _) {
        String t(String fr, String ar) => isAr ? ar : fr;
        final isPremium = SettingsService.isPremium;
        final nbVehicules = VehiculeService.getAll().length;
        final primary = widget.config.primaryColor;

        return ScreenBackground(
          // Pas de photo dédiée au profil pour l'instant : la catégorie
          // "generique" retombe proprement sur le dégradé + icône en
          // filigrane tant que assets/images/bg_generique.jpg n'existe pas.
          category: BackgroundCategory.generique,
          accentColor: primary,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t('Profil', 'الملف الشخصي'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),

                // Carte statut du compte
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: primary,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.config.appName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPremium
                                        ? primary.withOpacity(0.15)
                                        : Colors.black.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isPremium
                                        ? t('Compte Premium', 'حساب Premium')
                                        : t('Compte gratuit', 'حساب مجاني'),
                                    style: TextStyle(
                                        color: isPremium
                                            ? const Color(0xFF166534)
                                            : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nbVehicules > 1
                                  ? t('$nbVehicules véhicules utilisés',
                                      '$nbVehicules مركبات مستخدمة')
                                  : t('$nbVehicules véhicule utilisé',
                                      '$nbVehicules مركبة مستخدمة'),
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _SectionHeader(t('Réglages', 'الإعدادات')),
                const SizedBox(height: 8),

                // Langue
                _SettingsCard(
                  icon: Icons.language,
                  iconColor: primary,
                  title: t('Langue', 'اللغة'),
                  subtitle: isAr ? 'العربية' : 'Français',
                  trailing: _LanguagePill(
                    isAr: isAr,
                    accent: primary,
                    onChanged: (v) => widget.isAr.value = v,
                  ),
                ),

                // Type de véhicule (voiture / moto / les deux) : pilote
                // quels onglets sont affichés dans l'app, choisi à
                // l'onboarding et modifiable ici.
                _SettingsCard(
                  icon: Icons.directions_car,
                  iconColor: const Color(0xFFEF4444),
                  title: t('Type de véhicule', 'نوع المركبة'),
                  subtitle: _vehicleProfileLabel(t),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.black38),
                  onTap: () => _showVehicleProfilePicker(context, t),
                ),

                // Rappels SMS/Appel — reste cliquable même désactivée
                // (compte non-Premium) pour guider vers l'upgrade au lieu
                // d'un cul-de-sac silencieux.
                _SettingsCard(
                  icon: Icons.notifications_active_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: t('Rappels par SMS / Appel',
                      'تذكيرات عبر SMS / مكالمة'),
                  subtitle: isPremium
                      ? t('Bientôt disponible', 'قريباً')
                      : t('Réservé aux comptes Premium',
                          'حصري لحسابات Premium'),
                  onTap: !isPremium
                      ? () => _showPremiumComingSoon(context, t)
                      : null,
                  trailing: Switch(
                    value: SettingsService.smsRemindersEnabled,
                    activeColor: primary,
                    onChanged: isPremium
                        ? (val) async {
                            await SettingsService.setSmsRemindersEnabled(val);
                            setState(() {});
                          }
                        : null,
                  ),
                ),

                if (!isPremium)
                  _SettingsCard(
                    icon: Icons.workspace_premium,
                    iconColor: primary,
                    title: t('Passer en Premium', 'الترقية إلى Premium'),
                    subtitle: t('Véhicules illimités et rappels SMS/appel',
                        'مركبات غير محدودة وتذكيرات SMS/مكالمة'),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.black38),
                    onTap: () => _showPremiumComingSoon(context, t),
                  ),

                const SizedBox(height: 24),
                _SectionHeader(t('Support', 'الدعم')),
                const SizedBox(height: 8),

                _SettingsCard(
                  icon: Icons.mail_outline,
                  iconColor: Colors.black87,
                  title: t('Contacter le support', 'التواصل مع الدعم'),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.black38),
                  onTap: _contactSupport,
                ),
                _SettingsCard(
                  icon: Icons.info_outline,
                  iconColor: Colors.black87,
                  title: t('À propos', 'حول التطبيق'),
                  subtitle: t(
                      '${widget.config.appName} — gestion véhicules & pièces détachées',
                      '${widget.config.appName} — إدارة المركبات وقطع الغيار'),
                  // Accès admin caché : appui long ici, invisible pour
                  // les utilisateurs normaux et les magasins.
                  onLongPress: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminLoginScreen(config: widget.config),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// En-tête de section : majuscules, espacement des lettres, gris discret.
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 0.6,
        color: Colors.black54,
      ),
    );
  }
}

/// Carte de réglage : icône dans un badge coloré, titre/sous-titre, trailing
/// libre (chevron, switch, pilule...). Reprend le style des cartes du
/// Portail pièces pour une cohérence visuelle dans toute l'app.
class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pilule FR/AR pleine : le segment actif est rempli avec la couleur
/// d'accent, l'autre reste transparent sur fond gris clair.
class _LanguagePill extends StatelessWidget {
  final bool isAr;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _LanguagePill({
    required this.isAr,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillSegment('FR', !isAr, () => onChanged(false)),
          _pillSegment('AR', isAr, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pillSegment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: active ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

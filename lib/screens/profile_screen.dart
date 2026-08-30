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

        return ScreenBackground(
          // Pas de photo dédiée au profil pour l'instant : la catégorie
          // "generique" retombe proprement sur le dégradé + icône en
          // filigrane tant que assets/images/bg_generique.jpg n'existe pas.
          category: BackgroundCategory.generique,
          accentColor: widget.config.primaryColor,
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
                        backgroundColor: widget.config.primaryColor,
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
                            Text(
                              isPremium
                                  ? t('Compte Premium', 'حساب Premium')
                                  : t('Compte gratuit', 'حساب مجاني'),
                              style: TextStyle(
                                  color: isPremium
                                      ? const Color(0xFF166534)
                                      : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(t('Réglages', 'الإعدادات'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),

                // Langue
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(t('Langue', 'اللغة')),
                    subtitle: Text(isAr ? 'العربية' : 'Français'),
                    trailing: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('FR')),
                        ButtonSegment(value: true, label: Text('AR')),
                      ],
                      selected: {isAr},
                      onSelectionChanged: (s) => widget.isAr.value = s.first,
                    ),
                  ),
                ),

                // Type de véhicule (voiture / moto / les deux) : pilote
                // quels onglets sont affichés dans l'app, choisi à
                // l'onboarding et modifiable ici.
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(t('Type de véhicule', 'نوع المركبة')),
                    subtitle: Text(_vehicleProfileLabel(t)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showVehicleProfilePicker(context, t),
                  ),
                ),

                // Rappels SMS/Appel — reste cliquable même désactivée
                // (compte non-Premium) pour guider vers l'upgrade au lieu
                // d'un cul-de-sac silencieux.
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: !isPremium
                        ? () => _showPremiumComingSoon(context, t)
                        : null,
                    child: SwitchListTile(
                      secondary:
                          const Icon(Icons.notifications_active_outlined),
                      title: Text(t('Rappels par SMS / Appel',
                          'تذكيرات عبر SMS / مكالمة')),
                      subtitle: Text(
                        isPremium
                            ? t('Bientôt disponible', 'قريباً')
                            : t('Réservé aux comptes Premium',
                                'حصري لحسابات Premium'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: SettingsService.smsRemindersEnabled,
                      onChanged: isPremium
                          ? (val) async {
                              await SettingsService.setSmsRemindersEnabled(
                                  val);
                              setState(() {});
                            }
                          : null,
                    ),
                  ),
                ),

                if (!isPremium)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.workspace_premium,
                          color: widget.config.primaryColor),
                      title:
                          Text(t('Passer en Premium', 'الترقية إلى Premium')),
                      subtitle: Text(t(
                          'Véhicules illimités et rappels SMS/appel',
                          'مركبات غير محدودة وتذكيرات SMS/مكالمة')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPremiumComingSoon(context, t),
                    ),
                  ),

                const SizedBox(height: 24),
                Text(t('Support', 'الدعم'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(t('Contacter le support', 'التواصل مع الدعم')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _contactSupport,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(t('À propos', 'حول التطبيق')),
                    subtitle: Text(t(
                        '${widget.config.appName} — gestion véhicules & pièces détachées',
                        '${widget.config.appName} — إدارة المركبات وقطع الغيار')),
                    // Accès admin caché : appui long ici, invisible pour
                    // les utilisateurs normaux et les magasins.
                    onLongPress: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminLoginScreen(config: widget.config),
                      ),
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

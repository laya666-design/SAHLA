import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import '../../services/vehicule_service.dart';
import '../../theme/app_theme.dart';
import '../rappels_screen.dart';
import '../sos/tel_picker_dialog.dart';
import '../sos/wilaya_picker_dialog.dart';
import '../sos/sos_alert_sent_screen.dart';
import '../../services/sos_service.dart';
import '../role_router.dart';
import 'store_dashboard_screen.dart';
import 'store_login_screen.dart';

/// Portail Magasin avec navigation :
/// Demandes · Rappels · Profil + SOS discret.
class MagasinShellScreen extends StatefulWidget {
  final AppConfig config;
  final bool isAr;

  const MagasinShellScreen({
    super.key,
    required this.config,
    this.isAr = false,
  });

  @override
  State<MagasinShellScreen> createState() => _MagasinShellScreenState();
}

class _MagasinShellScreenState extends State<MagasinShellScreen> {
  int _index = 0;
  bool _sosEnCours = false;

  @override
  void initState() {
    super.initState();
    // Si pas connecté → login, puis retour ici.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!StoreService.isLoggedIn && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StoreLoginScreen(config: widget.config),
          ),
        );
      }
    });
  }

  Future<void> _envoyerSos() async {
    if (_sosEnCours) return;
    final isAr = widget.isAr;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'نداء استغاثة' : 'Alerte SOS'),
        content: Text(
          isAr
              ? 'إرسال نداء استغاثة إلى سائقي سطحات المساعدة في ولايتك؟'
              : 'Envoyer une alerte de panne aux dépanneuses de ta wilaya ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.config.sosColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'إرسال' : 'Envoyer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    String? wilaya = SettingsService.wilaya;
    if (wilaya == null) {
      wilaya = await showWilayaPickerDialog(
        context,
        accentColor: widget.config.sosColor,
      );
      if (wilaya == null || !mounted) return;
      await SettingsService.setWilaya(wilaya);
    }
    final wilayaOk = wilaya;

    String? tel = SettingsService.userTel;
    if (tel == null) {
      tel = await showTelPickerDialog(
        context,
        accentColor: widget.config.sosColor,
      );
      if (tel == null || !mounted) return;
      await SettingsService.setUserTel(tel);
    }
    final telOk = tel;

    setState(() => _sosEnCours = true);
    try {
      final alertId = await SosService.sendAlert(
        wilaya: wilayaOk,
        telephone: telOk,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SosAlertSentScreen(
            config: widget.config,
            alertId: alertId,
            wilaya: wilayaOk,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sosEnCours = false);
    }
  }

  Future<void> _logout() async {
    await StoreService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => StoreLoginScreen(config: widget.config),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!StoreService.isLoggedIn) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      // Demandes = dashboard magasin existant
      StoreDashboardScreen(config: widget.config),
      RappelsScreen(
        config: widget.config,
        isAr: widget.isAr,
        roleLabel: 'magasin',
      ),
      _MagasinProfilTab(
        config: widget.config,
        isAr: widget.isAr,
        onLogout: _logout,
        onSos: _envoyerSos,
        sosEnCours: _sosEnCours,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Demandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Rappels',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _MagasinProfilTab extends StatelessWidget {
  final AppConfig config;
  final bool isAr;
  final VoidCallback onLogout;
  final VoidCallback onSos;
  final bool sosEnCours;

  const _MagasinProfilTab({
    required this.config,
    required this.isAr,
    required this.onLogout,
    required this.onSos,
    required this.sosEnCours,
  });

  @override
  Widget build(BuildContext context) {
    final t = (String fr, String ar) => isAr ? ar : fr;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('Profil magasin', 'ملف المحل')),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: config.enchereColor.withValues(alpha: 0.15),
                child: Icon(Icons.storefront, color: config.enchereColor),
              ),
              title: Text(
                t('Espace Magasin', 'فضاء المحل'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                t(
                  'Gère tes demandes, ton abonnement et tes rappels.',
                  'أدر طلباتك واشتراكك وتذكيراتك.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // SOS discret
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: config.sosColor.withValues(alpha: 0.12),
                child: Icon(Icons.sos, color: config.sosColor),
              ),
              title: Text(
                t('Alerte SOS', 'تنبيه استغاثة'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                t(
                  'Si ton propre véhicule tombe en panne',
                  'إذا تعطلت مركبتك الخاصة',
                ),
              ),
              trailing: sosEnCours
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chevron_right, color: config.sosColor),
              onTap: sosEnCours ? null : onSos,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade100,
                child: const Icon(Icons.swap_horiz, color: Colors.black54),
              ),
              title: Text(
                t('Changer de profil', 'تغيير الملف الشخصي'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                t('Conducteur, magasin ou dépanneuse', 'سائق، متجر أو سطحة'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => RoleRouter.changerDeProfil(context),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: Text(t('Se déconnecter', 'تسجيل الخروج')),
            style: OutlinedButton.styleFrom(
              foregroundColor: config.sosColor,
              side: BorderSide(color: config.sosColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

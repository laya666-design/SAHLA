import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/marketplace_service.dart';
import 'marketplace/buyer_phone_login_screen.dart';
import 'marketplace/mes_demandes_screen.dart';
import 'parts_screen.dart';

/// Portail acheteur : le scan photo (PartsScreen) avec un accès direct à
/// "Mes demandes". La session (numéro comme id) persiste au retour en arrière.
class BuyerPortalScreen extends StatefulWidget {
  final AppConfig config;
  final bool isAr;
  const BuyerPortalScreen({super.key, required this.config, this.isAr = false});

  @override
  State<BuyerPortalScreen> createState() => _BuyerPortalScreenState();
}

class _BuyerPortalScreenState extends State<BuyerPortalScreen> {
  bool _ready = false;

  bool get _ar => widget.isAr;
  String _t(String fr, String ar) => _ar ? ar : fr;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await MarketplaceService.loadPhoneAsId();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: widget.config.primaryColor,
          foregroundColor: Colors.white,
          title: Text(_t('Portail acheteur', 'بوابة المشتري')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final phoneLoggedIn = MarketplaceService.isPhoneLoggedIn;
    final phone = MarketplaceService.clientId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.config.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_t('Portail acheteur', 'بوابة المشتري')),
        actions: [
          IconButton(
            tooltip: _t('Mes demandes', 'طلباتي'),
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MesDemandesScreen(config: widget.config)),
            ),
          ),
          if (phoneLoggedIn)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: phone ?? _t('Mon compte', 'حسابي'),
              onSelected: (value) async {
                if (value == 'logout') {
                  await MarketplaceService.signOut();
                  if (!context.mounted) return;
                  // Remplace pour que le retour ne garde pas l'ancien portail.
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BuyerPhoneLoginScreen(
                          config: widget.config, isAr: widget.isAr),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    phone ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Text(_t('Se déconnecter', 'تسجيل الخروج')),
                ),
              ],
            )
          else
            IconButton(
              tooltip: _t('Se connecter', 'تسجيل الدخول'),
              icon: const Icon(Icons.login),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuyerPhoneLoginScreen(
                      config: widget.config, isAr: widget.isAr),
                ),
              ),
            ),
        ],
      ),
      body: PartsScreen(config: widget.config, isAr: widget.isAr),
    );
  }
}

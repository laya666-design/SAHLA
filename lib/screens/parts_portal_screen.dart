import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/marketplace_service.dart';
import 'buyer_portal_screen.dart';
import 'marketplace/buyer_phone_login_screen.dart';

/// Entrée de l'onglet "Pièces" du conducteur.
/// Plus d'écran de choix de portail : le portail vendeur (magasin) est
/// un rôle séparé choisi dès le lancement de l'app (voir
/// role_selection_screen.dart), donc ce tab va directement au scan
/// photo (portail acheteur), une fois la session chargée.
class PartsPortalScreen extends StatefulWidget {
  final AppConfig config;
  final bool isAr;
  const PartsPortalScreen({super.key, required this.config, this.isAr = false});

  @override
  State<PartsPortalScreen> createState() => _PartsPortalScreenState();
}

class _PartsPortalScreenState extends State<PartsPortalScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await MarketplaceService.loadPhoneAsId();
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return MarketplaceService.hasSession
        ? BuyerPortalScreen(config: widget.config, isAr: widget.isAr)
        : BuyerPhoneLoginScreen(config: widget.config, isAr: widget.isAr);
  }
}

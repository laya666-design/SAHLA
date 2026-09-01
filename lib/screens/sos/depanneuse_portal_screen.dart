import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/sos_service.dart';
import 'depanneuse_auth_screen.dart';
import 'depanneuse_dashboard_screen.dart';

/// Accès caché à l'Espace Dépanneuse — atteint uniquement via un appui
/// long sur le bouton SOS (pas de menu visible). Redirige directement
/// vers le tableau de bord si une session existe déjà.
class DepanneusePortalScreen extends StatefulWidget {
  final AppConfig config;
  const DepanneusePortalScreen({super.key, required this.config});

  @override
  State<DepanneusePortalScreen> createState() =>
      _DepanneusePortalScreenState();
}

class _DepanneusePortalScreenState extends State<DepanneusePortalScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await SosService.loadPhoneAsId();
    if (!mounted) return;
    if (SosService.isDepanneuseLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DepanneuseDashboardScreen(config: widget.config),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DepanneuseAuthScreen(config: widget.config),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _loading
            ? CircularProgressIndicator(color: widget.config.sosColor)
            : const SizedBox.shrink(),
      ),
    );
  }
}

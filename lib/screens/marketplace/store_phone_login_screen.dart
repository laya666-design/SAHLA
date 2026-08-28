import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import 'store_complete_profile_screen.dart';
import 'store_dashboard_screen.dart';
import 'store_login_screen.dart';

/// Connexion magasin par numéro de téléphone (enregistré comme identifiant).
/// Pas de SMS / WhatsApp. La session persiste : retour en arrière
/// ne déconnecte pas.
class StorePhoneLoginScreen extends StatefulWidget {
  final AppConfig config;
  const StorePhoneLoginScreen({super.key, required this.config});

  @override
  State<StorePhoneLoginScreen> createState() => _StorePhoneLoginScreenState();
}

class _StorePhoneLoginScreenState extends State<StorePhoneLoginScreen> {
  final _phoneController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le bouton (texte "Se connecter") dès que l'utilisateur tape.
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _normaliserNumero(String saisie) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    var s = saisie.trim();
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(eastern[i], western[i]);
    }
    final chiffres = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (chiffres.isEmpty) return null;

    if (chiffres.startsWith('+213') && chiffres.length == 13) {
      return chiffres;
    }
    if (chiffres.startsWith('213') && chiffres.length == 12) {
      return '+$chiffres';
    }
    if (chiffres.startsWith('0') && chiffres.length == 10) {
      return '+213${chiffres.substring(1)}';
    }
    if (chiffres.length == 9 &&
        (chiffres.startsWith('5') ||
            chiffres.startsWith('6') ||
            chiffres.startsWith('7'))) {
      return '+213$chiffres';
    }
    if (chiffres.startsWith('+2130') && chiffres.length == 14) {
      return '+213${chiffres.substring(5)}';
    }
    return null;
  }

  Future<void> _connecter() async {
    final saisie = _phoneController.text;
    final numero = _normaliserNumero(saisie);
    if (numero == null) {
      final digits = saisie.replaceAll(RegExp(r'[^0-9]'), '');
      setState(() => _error =
          'Numéro invalide ($digits, ${digits.length} chiffres). '
          'Utilise le format 0556 65 32 20.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final nouveau = await StoreService.connectWithPhoneAsId(numero);
      if (!mounted) return;
      // pushReplacement : le retour ne ramène pas à l'écran de login.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => nouveau
              ? StoreCompleteProfileScreen(config: widget.config)
              : StoreDashboardScreen(config: widget.config),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.config.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Espace Pro — Magasin'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 56),
              const SizedBox(height: 8),
              const Text(
                'Entre ton numéro de téléphone pour recevoir '
                'les demandes de pièces des clients.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  hintText: '0556 65 32 20',
                  prefixIcon: Icon(Icons.phone),
                ),
                onSubmitted: (_) => _connecter(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _connecter,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: widget.config.primaryColor,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_phoneController.text.trim().isEmpty
                        ? 'Continuer avec ce numéro'
                        : 'Se connecter'),
              ),
              const SizedBox(height: 16),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('ou', style: TextStyle(color: Colors.black45)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StoreLoginScreen(config: widget.config),
                          ),
                        ),
                child: const Text('Utiliser l\'email à la place'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

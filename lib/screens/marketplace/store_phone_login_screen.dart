import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import 'store_complete_profile_screen.dart';
import 'store_dashboard_screen.dart';

/// Connexion magasin par numéro de téléphone + mot de passe (le
/// téléphone reste l'identifiant visible ; en coulisses il est converti
/// en email technique pour Firebase Auth — voir StoreService). Pas de
/// SMS à recevoir : la connexion/inscription est instantanée.
class StorePhoneLoginScreen extends StatefulWidget {
  final AppConfig config;
  const StorePhoneLoginScreen({super.key, required this.config});

  @override
  State<StorePhoneLoginScreen> createState() => _StorePhoneLoginScreenState();
}

class _StorePhoneLoginScreenState extends State<StorePhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _modeInscription = false;
  bool _motDePasseVisible = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final numero = StoreService.normaliserNumeroLocal(_phoneController.text);
    if (numero == null) {
      final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      setState(() => _error =
          'Numéro invalide ($digits, ${digits.length} chiffres). '
          'Utilise le format 0556 65 32 20.');
      return;
    }
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = 'Le mot de passe doit faire au moins 6 caractères.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_modeInscription) {
        await StoreService.signUpWithPhonePassword(
          telephone: numero,
          password: password,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoreCompleteProfileScreen(config: widget.config),
          ),
        );
      } else {
        await StoreService.signInWithPhonePassword(
          telephone: numero,
          password: password,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoreDashboardScreen(config: widget.config),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
              Text(
                _modeInscription
                    ? 'Crée ton compte magasin avec ton numéro et un mot '
                        'de passe. Tu recevras ensuite les demandes de '
                        'pièces des clients.'
                    : 'Connecte-toi avec ton numéro de téléphone et ton '
                        'mot de passe.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
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
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: !_motDePasseVisible,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_motDePasseVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _motDePasseVisible = !_motDePasseVisible),
                  ),
                ),
                onSubmitted: (_) => _valider(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _valider,
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
                    : Text(_modeInscription ? 'Créer mon compte' : 'Se connecter'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _modeInscription = !_modeInscription;
                          _error = null;
                        }),
                child: Text(_modeInscription
                    ? 'J\'ai déjà un compte — me connecter'
                    : 'Pas encore de compte — en créer un'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

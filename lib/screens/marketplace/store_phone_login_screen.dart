import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import 'store_complete_profile_screen.dart';
import 'store_dashboard_screen.dart';
import 'store_login_screen.dart';

/// Connexion magasin par téléphone/SMS — méthode principale.
/// L'email/mot de passe reste accessible via "Utiliser l'email à la
/// place" (StoreLoginScreen), en secours si l'envoi de SMS tarde ou
/// échoue sur certains opérateurs.
class StorePhoneLoginScreen extends StatefulWidget {
  final AppConfig config;
  const StorePhoneLoginScreen({super.key, required this.config});

  @override
  State<StorePhoneLoginScreen> createState() => _StorePhoneLoginScreenState();
}

class _StorePhoneLoginScreenState extends State<StorePhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _verificationId;
  bool _codeEnvoye = false;
  bool _rememberMe = true;

  /// Normalise un numéro algérien saisi localement (ex: "0556 65 32 20"
  /// ou "0556653220") vers le format international attendu par Firebase.
  String? _normaliserNumero(String saisie) {
    final chiffres = saisie.replaceAll(RegExp(r'[^0-9+]'), '');
    if (chiffres.startsWith('+213')) return chiffres;
    if (chiffres.startsWith('213')) return '+$chiffres';
    if (chiffres.startsWith('0') && chiffres.length == 10) {
      return '+213${chiffres.substring(1)}';
    }
    return null;
  }

  Future<void> _envoyerCode() async {
    final numero = _normaliserNumero(_phoneController.text);
    if (numero == null) {
      setState(() => _error =
          'Numéro invalide. Utilise le format 0556 65 32 20.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await StoreService.startPhoneVerification(
      phoneNumber: numero,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _codeEnvoye = true;
          _loading = false;
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _error = message;
          _loading = false;
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        _apresConnexion(nouveauCompte: false);
      },
    );
  }

  Future<void> _validerCode() async {
    if (_verificationId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nouveau = await StoreService.confirmPhoneCode(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
        rememberMe: _rememberMe,
      );
      _apresConnexion(nouveauCompte: nouveau);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'invalid-verification-code'
          ? 'Code incorrect. Vérifie le SMS reçu.'
          : (e.message ?? 'Code invalide.'));
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apresConnexion({required bool nouveauCompte}) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => nouveauCompte
            ? StoreCompleteProfileScreen(config: widget.config)
            : StoreDashboardScreen(config: widget.config),
      ),
    );
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
                'Reçois les demandes de pièces des clients autour de toi '
                'et réponds avec ton prix.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (!_codeEnvoye) ...[
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
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _envoyerCode,
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
                      : const Text('Recevoir le code par SMS'),
                ),
              ] else ...[
                Text(
                  'Code envoyé au ${_phoneController.text}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  enabled: !_loading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(
                    labelText: 'Code reçu par SMS',
                    counterText: '',
                  ),
                  maxLength: 6,
                ),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  title: const Text('Se souvenir de moi'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _validerCode,
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
                      : const Text('Valider'),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _codeEnvoye = false;
                            _codeController.clear();
                          }),
                  child: const Text('Modifier le numéro'),
                ),
              ],
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
              // Secours : si le SMS n'arrive pas (délai/opérateur), le
              // magasin peut toujours utiliser email/mot de passe.
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

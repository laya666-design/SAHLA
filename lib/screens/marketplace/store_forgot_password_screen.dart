import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';

/// Écran "mot de passe oublié" pour le login magasin (email/mot de passe
/// uniquement — sans objet pour les comptes connectés via Google).
class StoreForgotPasswordScreen extends StatefulWidget {
  final AppConfig config;
  final String? initialEmail;

  const StoreForgotPasswordScreen({
    super.key,
    required this.config,
    this.initialEmail,
  });

  @override
  State<StoreForgotPasswordScreen> createState() =>
      _StoreForgotPasswordScreenState();
}

class _StoreForgotPasswordScreenState
    extends State<StoreForgotPasswordScreen> {
  late final _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  bool _loading = false;
  String? _error;
  bool _sent = false;

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entre ton email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await StoreService.sendPasswordResetEmail(email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Envoi impossible.');
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
        title: const Text('Mot de passe oublié'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset, size: 56),
              const SizedBox(height: 8),
              const Text(
                "Indique l'email de ton compte magasin, on t'envoie un "
                'lien pour choisir un nouveau mot de passe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (_sent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF166534).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF166534)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Email envoyé à ${_emailController.text.trim()}. '
                          'Vérifie ta boîte de réception (et les spams).',
                          style: const TextStyle(color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour à la connexion'),
                ),
              ] else ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _sendReset,
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
                      : const Text('Envoyer le lien'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

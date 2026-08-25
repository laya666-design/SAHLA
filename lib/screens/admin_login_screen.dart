import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/admin_service.dart';
import 'admin_payments_screen.dart';

/// Écran de connexion admin — accessible uniquement via l'appui long
/// caché sur "À propos" dans l'onglet Profil (pas de bouton visible pour
/// les utilisateurs normaux ni pour les magasins).
class AdminLoginScreen extends StatefulWidget {
  final AppConfig config;
  const AdminLoginScreen({super.key, required this.config});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // force: true car le token qui vient d'être émis à la connexion
      // ne contient pas encore le claim admin s'il a été posé après.
      final isAdmin = await AdminService.isCurrentUserAdmin(force: true);
      if (!isAdmin) {
        await AdminService.signOut();
        setState(() => _error = 'Ce compte n\'a pas les droits admin.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminPaymentsScreen(config: widget.config),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Connexion impossible.');
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Espace Admin')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 56),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email admin'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

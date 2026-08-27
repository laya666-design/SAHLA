import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import 'store_dashboard_screen.dart';

/// Affiché une seule fois, juste après la toute première connexion par
/// téléphone : le compte existe déjà (créé avec `actif: false`), il ne
/// manque que le nom du magasin et l'adresse pour la validation manuelle.
class StoreCompleteProfileScreen extends StatefulWidget {
  final AppConfig config;
  const StoreCompleteProfileScreen({super.key, required this.config});

  @override
  State<StoreCompleteProfileScreen> createState() =>
      _StoreCompleteProfileScreenState();
}

class _StoreCompleteProfileScreenState
    extends State<StoreCompleteProfileScreen> {
  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _valider() async {
    if (_nomController.text.trim().isEmpty ||
        _adresseController.text.trim().isEmpty) {
      setState(() => _error = 'Le nom et l\'adresse sont nécessaires pour '
          'la validation de ton compte.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await StoreService.completerProfilApresTelephone(
        nom: _nomController.text.trim(),
        adresse: _adresseController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StoreDashboardScreen(config: widget.config),
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
        title: const Text('Ton magasin'),
        automaticallyImplyLeading: false,
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
                'Dernière étape : le nom et l\'adresse de ton magasin, '
                'pour que les clients d\'El Bouni te reconnaissent.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nomController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Nom du magasin',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adresseController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Adresse (El Bouni, Sidi Achour...)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
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
                    : const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

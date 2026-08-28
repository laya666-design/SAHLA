import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import 'store_complete_profile_screen.dart';
import 'store_dashboard_screen.dart';
import 'store_login_screen.dart';

/// Connexion magasin par numéro de téléphone, vérifié par un code SMS
/// (Firebase Phone Auth). La session persiste : retour en arrière
/// ne déconnecte pas.
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
  bool _attenteCode = false;
  String? _error;
  String? _verificationId;
  String? _numeroEnCours;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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

  Future<void> _envoyerCode() async {
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
      await StoreService.startPhoneVerification(
        phoneNumber: numero,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _numeroEnCours = numero;
            _attenteCode = true;
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
        onAutoVerified: (nouveau) {
          if (!mounted) return;
          _allerVersEspace(nouveau);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  Future<void> _verifierCode() async {
    final code = _codeController.text.trim();
    final verificationId = _verificationId;
    if (verificationId == null) return;
    if (code.isEmpty) {
      setState(() => _error = 'Entre le code reçu par SMS.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final nouveau = await StoreService.confirmPhoneCode(
        verificationId: verificationId,
        smsCode: code,
      );
      if (!mounted) return;
      _allerVersEspace(nouveau);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageErreurCode(e));
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageErreurCode(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Code incorrect. Vérifie et réessaie.';
      case 'session-expired':
        return 'Code expiré. Appuie sur "Renvoyer le code".';
      default:
        return e.message ?? 'Erreur de vérification du code.';
    }
  }

  void _allerVersEspace(bool nouveau) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => nouveau
            ? StoreCompleteProfileScreen(config: widget.config)
            : StoreDashboardScreen(config: widget.config),
      ),
    );
  }

  void _modifierNumero() {
    setState(() {
      _attenteCode = false;
      _verificationId = null;
      _codeController.clear();
      _error = null;
    });
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
            children: _attenteCode ? _etapeCode() : _etapeTelephone(),
          ),
        ),
      ),
    );
  }

  List<Widget> _etapeTelephone() {
    return [
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
        onSubmitted: (_) => _envoyerCode(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 16),
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
                    builder: (_) => StoreLoginScreen(config: widget.config),
                  ),
                ),
        child: const Text('Utiliser l\'email à la place'),
      ),
    ];
  }

  List<Widget> _etapeCode() {
    return [
      const Icon(Icons.sms_outlined, size: 56),
      const SizedBox(height: 8),
      Text(
        'Code envoyé par SMS au $_numeroEnCours.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        enabled: !_loading,
        decoration: const InputDecoration(
          labelText: 'Code reçu par SMS',
          hintText: '123456',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        onSubmitted: (_) => _verifierCode(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _loading ? null : _verifierCode,
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
            : const Text('Se connecter'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _loading ? null : _envoyerCode,
        child: const Text('Renvoyer le code'),
      ),
      TextButton(
        onPressed: _loading ? null : _modifierNumero,
        child: const Text('Modifier le numéro'),
      ),
    ];
  }
}

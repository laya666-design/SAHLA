import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/store_service.dart';
import 'store_complete_profile_screen.dart';
import 'store_dashboard_screen.dart';
import 'store_login_screen.dart';

/// Connexion magasin — style moderne (téléphone + mot de passe).
/// Le numéro est converti en email technique pour Firebase Auth.
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
  bool _googleLoading = false;
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

  Future<void> _connexionGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await StoreService.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StoreDashboardScreen(config: widget.config),
        ),
      );
    } catch (e) {
      final raw = e.toString();
      // ApiException: 10 = DEVELOPER_ERROR → SHA-1 manquant dans Firebase
      String msg;
      if (raw.contains('ApiException: 10') || raw.contains('sign_in_failed')) {
        msg = 'Connexion Google indisponible pour le moment.\n'
            'Utilise le téléphone ou l’e-mail, ou contacte le support '
            '(config SHA-1 Firebase à vérifier).';
      } else if (raw.contains('annulée') || raw.contains('canceled')) {
        msg = 'Connexion Google annulée.';
      } else {
        msg = raw.replaceFirst('Exception: ', '');
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefix, size: 20, color: Colors.black45),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.config.primaryColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.config.primaryColor;
    final busy = _loading || _googleLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Barre du haut : fermer + rien d'autre
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Logo / marque
                    Icon(Icons.storefront_rounded, size: 48, color: primary),
                    const SizedBox(height: 12),
                    Text(
                      'Espace Pro',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.87),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _modeInscription
                          ? 'Crée ton compte magasin pour recevoir les demandes'
                          : 'Bon retour ! Connecte-toi pour continuer',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Téléphone
                    const Text(
                      'Téléphone',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        label: '',
                        hint: '0556 65 32 20',
                        prefix: Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mot de passe
                    const Text(
                      'Mot de passe',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_motDePasseVisible,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _valider(),
                      decoration: _fieldDecoration(
                        label: '',
                        hint: 'Entrez votre mot de passe',
                        prefix: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _motDePasseVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.black45,
                          ),
                          onPressed: () => setState(
                              () => _motDePasseVisible = !_motDePasseVisible),
                        ),
                      ),
                    ),

                    // Mot de passe oublié (info)
                    if (!_modeInscription)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Pour réinitialiser le mot de passe d’un compte téléphone, contacte le support.',
                                      ),
                                    ),
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Bouton principal
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : _valider,
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _modeInscription
                                    ? 'Créer mon compte'
                                    : 'Connexion',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Séparateur OU
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OU',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Google
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: busy ? null : _connexionGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _googleLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primary,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Simple "G" style indicator
                                  Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEA4335),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Continuer avec Gmail',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Lien email
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoreLoginScreen(config: widget.config),
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black54,
                      ),
                      child: const Text(
                        'Se connecter avec un e-mail',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Inscription / connexion
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _modeInscription
                              ? 'Déjà un compte ? '
                              : 'Pas encore de compte ? ',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: busy
                              ? null
                              : () => setState(() {
                                    _modeInscription = !_modeInscription;
                                    _error = null;
                                  }),
                          child: Text(
                            _modeInscription ? 'Se connecter' : "S'inscrire",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

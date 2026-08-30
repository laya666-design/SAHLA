import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/marketplace_service.dart';
import '../buyer_portal_screen.dart';

/// Connexion acheteur par numéro de téléphone (enregistré comme identifiant).
/// Pas de SMS / WhatsApp. La session est persistée : retour en arrière
/// ne déconnecte pas.
/// Style aligné sur [StorePhoneLoginScreen] (Espace Pro).
class BuyerPhoneLoginScreen extends StatefulWidget {
  final AppConfig config;
  final bool isAr;
  const BuyerPhoneLoginScreen({
    super.key,
    required this.config,
    this.isAr = false,
  });

  @override
  State<BuyerPhoneLoginScreen> createState() => _BuyerPhoneLoginScreenState();
}

class _BuyerPhoneLoginScreenState extends State<BuyerPhoneLoginScreen> {
  final _phoneController = TextEditingController();

  bool _loading = false;
  String? _error;

  bool get _ar => widget.isAr;
  String _t(String fr, String ar) => _ar ? ar : fr;

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

  /// Normalise un numéro algérien vers +213…
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
      setState(() => _error = _t(
            'Numéro invalide ($digits, ${digits.length} chiffres). '
            'Utilise le format 0556 65 32 20.',
            'رقم غير صالح ($digits, ${digits.length} أرقام). '
            'استخدم الصيغة 0556 65 32 20.',
          ));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await MarketplaceService.connectWithPhoneAsId(numero);
      if (!mounted) return;
      // Remplace l'écran de login pour que le retour ne ramène pas ici.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BuyerPortalScreen(config: widget.config, isAr: widget.isAr),
        ),
      );
    } catch (e) {
      setState(() => _error = _t('Erreur : $e', 'خطأ: $e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continuerSansCompte() async {
    await MarketplaceService.ensureSignedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BuyerPortalScreen(config: widget.config, isAr: widget.isAr),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefix,
  }) {
    final primary = widget.config.primaryColor;
    return InputDecoration(
      labelText: '',
      hintText: hint,
      prefixIcon: Icon(prefix, size: 20, color: Colors.black45),
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
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.config.primaryColor;
    final busy = _loading;

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
                    Icon(Icons.person_rounded, size: 48, color: primary),
                    const SizedBox(height: 12),
                    Text(
                      _t('Portail acheteur', 'بوابة المشتري'),
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
                      _t(
                        'Entre ton numéro de téléphone pour retrouver '
                        'tes demandes sur n\'importe quel appareil.',
                        'أدخل رقم هاتفك لاسترجاع طلباتك على أي جهاز.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Téléphone
                    Text(
                      _t('Téléphone', 'الهاتف'),
                      style: const TextStyle(
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _connecter(),
                      decoration: _fieldDecoration(
                        hint: '0556 65 32 20',
                        prefix: Icons.phone_outlined,
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
                        onPressed: busy ? null : _connecter,
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
                                _phoneController.text.trim().isEmpty
                                    ? _t('Continuer avec ce numéro',
                                        'المتابعة بهذا الرقم')
                                    : _t('Se connecter', 'تسجيل الدخول'),
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
                            _t('OU', 'أو'),
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

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: busy ? null : _continuerSansCompte,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black54,
                      ),
                      child: Text(
                        _t('Continuer sans compte', 'المتابعة بدون حساب'),
                        style: const TextStyle(fontSize: 13),
                      ),
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

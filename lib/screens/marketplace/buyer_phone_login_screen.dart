import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/marketplace_service.dart';
import '../buyer_portal_screen.dart';

/// Connexion acheteur par numéro de téléphone (enregistré comme identifiant).
/// Pas de SMS / WhatsApp. La session est persistée : retour en arrière
/// ne déconnecte pas.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.config.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_t('Portail acheteur', 'بوابة المشتري')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_outline, size: 56),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Entre ton numéro de téléphone pour retrouver '
                  'tes demandes sur n\'importe quel appareil.',
                  'أدخل رقم هاتفك لاسترجاع طلباتك على أي جهاز.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: _t('Numéro de téléphone', 'رقم الهاتف'),
                  hintText: '0556 65 32 20',
                  prefixIcon: const Icon(Icons.phone),
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
                    : Text(
                        _phoneController.text.trim().isEmpty
                            ? _t('Continuer avec ce numéro',
                                'المتابعة بهذا الرقم')
                            : _t('Se connecter', 'تسجيل الدخول'),
                      ),
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
                onPressed: _loading ? null : _continuerSansCompte,
                child: Text(_t(
                  'Continuer sans compte',
                  'المتابعة بدون حساب',
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

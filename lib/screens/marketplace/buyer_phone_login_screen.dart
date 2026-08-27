import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/marketplace_service.dart';
import '../buyer_portal_screen.dart';

/// Connexion acheteur par téléphone/SMS — méthode principale.
/// Permet de retrouver ses demandes sur un autre appareil.
/// Option « Continuer sans compte » : session anonyme (demandes liées
/// uniquement à cet appareil).
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
  final _codeController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _verificationId;
  bool _codeEnvoye = false;

  bool get _ar => widget.isAr;
  String _t(String fr, String ar) => _ar ? ar : fr;

  /// Normalise un numéro algérien saisi localement vers le format
  /// international attendu par Firebase (+213…).
  /// Accepte : 0556 65 32 20, 0556653220, 556653220, +213556653220,
  /// ainsi que les chiffres arabes orientaux (٠١٢٣…).
  String? _normaliserNumero(String saisie) {
    // Chiffres arabes orientaux → arabes occidentaux
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    var s = saisie.trim();
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(eastern[i], western[i]);
    }
    // Garde uniquement chiffres et +
    final chiffres = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (chiffres.isEmpty) return null;

    // Déjà international
    if (chiffres.startsWith('+213') && chiffres.length == 13) {
      return chiffres;
    }
    if (chiffres.startsWith('213') && chiffres.length == 12) {
      return '+$chiffres';
    }
    // Local avec 0 : 0556653220 (10 chiffres)
    if (chiffres.startsWith('0') && chiffres.length == 10) {
      return '+213${chiffres.substring(1)}';
    }
    // Local sans 0 : 556653220 (9 chiffres, mobile 5/6/7)
    if (chiffres.length == 9 &&
        (chiffres.startsWith('5') ||
            chiffres.startsWith('6') ||
            chiffres.startsWith('7'))) {
      return '+213$chiffres';
    }
    // +213 suivi d'un 0 local erroné : +2130556… → corriger
    if (chiffres.startsWith('+2130') && chiffres.length == 14) {
      return '+213${chiffres.substring(5)}';
    }
    return null;
  }

  Future<void> _envoyerCode() async {
    final saisie = _phoneController.text;
    final numero = _normaliserNumero(saisie);
    if (numero == null) {
      // Message plus clair : indique ce qui a été compris
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

    await MarketplaceService.startPhoneVerification(
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
        _apresConnexion();
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
      await MarketplaceService.confirmPhoneCode(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      _apresConnexion();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'invalid-verification-code'
          ? _t(
              'Code incorrect. Vérifie le SMS reçu.',
              'رمز غير صحيح. تحقق من الرسالة.',
            )
          : (e.message ?? _t('Code invalide.', 'رمز غير صالح.')));
    } catch (e) {
      setState(() => _error = _t('Erreur : $e', 'خطأ: $e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apresConnexion() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BuyerPortalScreen(config: widget.config, isAr: widget.isAr),
      ),
    );
  }

  void _continuerSansCompte() {
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
                  'Connecte-toi avec ton téléphone pour retrouver '
                  'tes demandes sur n\'importe quel appareil.',
                  'سجّل الدخول برقم هاتفك لاسترجاع طلباتك على أي جهاز.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (!_codeEnvoye) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: _t('Numéro de téléphone', 'رقم الهاتف'),
                    hintText: '0556 65 32 20',
                    prefixIcon: const Icon(Icons.phone),
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
                      : Text(_t(
                          'Recevoir le code par SMS',
                          'استلام الرمز عبر رسالة',
                        )),
                ),
              ] else ...[
                Text(
                  _t(
                    'Code envoyé au ${_phoneController.text}',
                    'تم إرسال الرمز إلى ${_phoneController.text}',
                  ),
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
                  decoration: InputDecoration(
                    labelText: _t('Code reçu par SMS', 'الرمز المستلم'),
                    counterText: '',
                  ),
                  maxLength: 6,
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
                      : Text(_t('Valider', 'تأكيد')),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _codeEnvoye = false;
                            _codeController.clear();
                          }),
                  child: Text(_t('Modifier le numéro', 'تغيير الرقم')),
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/marketplace_service.dart';
import '../services/models.dart';
import '../theme/app_theme.dart';
import 'marketplace/mes_demandes_screen.dart';

class PartsScreen extends StatefulWidget {
  final AppConfig config;
  final bool isAr;
  const PartsScreen({super.key, required this.config, this.isAr = false});

  @override
  State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  final _picker = ImagePicker();
  final _gemini = GeminiService();

  File? _image;
  bool _loading = false;
  bool _sending = false;
  String? _error;
  CarPartInfo? _part;

  bool get _ar => widget.isAr;
  String _t(String fr, String ar) => _ar ? ar : fr;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
      _part = null;
    });

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _image = file;
      _loading = true;
    });

    try {
      final json = await _gemini.analyzeCarPart(file);
      if (json.containsKey('error')) {
        _error = _t('Erreur : ${json['error']}', 'خطأ: ${json['error']}');
      } else {
        _part = CarPartInfo.fromJson(json);
      }
    } catch (e) {
      _error = _t('Erreur d\'analyse : $e', 'خطأ في التحليل: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(String tel) async {
    if (tel.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: tel);
    await launchUrl(uri);
  }

  Future<void> _whatsapp(String tel) async {
    if (tel.isEmpty) return;
    final cleaned = tel.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/213$cleaned');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _itineraire(String nomMagasin, String adresse) async {
    final query = adresse.isNotEmpty
        ? Uri.encodeComponent(adresse)
        : Uri.encodeComponent('$nomMagasin El Bouni Annaba');
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _envoyerDemande() async {
    final img = _image;
    final part = _part;
    if (img == null || part == null) return;

    setState(() => _sending = true);
    try {
      await MarketplaceService.broadcastRequest(
        photo: img,
        pieceNom: part.nom,
        reference: part.reference,
        compatibilite: part.compatibilite,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Demande envoyée aux magasins.', 'تم إرسال الطلب إلى المتاجر.')),
          action: SnackBarAction(
            label: _t('Voir', 'عرض'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MesDemandesScreen(config: widget.config),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Erreur : $e', 'خطأ: $e'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final part = _part;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(
                'Photographie la pièce cassée pour trouver référence et prix.',
                'صوّر القطعة المكسورة لمعرفة المرجع والسعر.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _loading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_t('Caméra Pièce', 'الكاميرا')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _loading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(_t('Galerie', 'المعرض')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_image != null)
              Container(
                height: 190,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.errorText, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.errorText, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            if (part != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      part.nom.isEmpty
                          ? _t('Pièce non identifiée', 'قطعة غير محددة')
                          : part.nom,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (part.etat.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        part.etat,
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                ],
              ),
              if (part.reference.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _t('Réf: ${part.reference}', 'المرجع: ${part.reference}'),
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: AppColors.textSecondary),
                ),
              ],
              if (part.compatibilite.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(_t('Compatibilité', 'التوافق'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...part.compatibilite.map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('Prix El Bouni', 'سعر البوني'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text(
                            '${part.prixDa} DA',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    if (part.prixOrigine > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${part.prixOrigine} DA',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            _t(
                              'Économie: ${part.prixOrigine - part.prixDa} DA',
                              'توفير: ${part.prixOrigine - part.prixDa} DA',
                            ),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (part.magasins.isNotEmpty) ...[
                Text(_t('Magasins qui ont répondu', 'المتاجر التي ردت'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                ...part.magasins.map((m) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.storefront,
                                    color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(m.nom,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                              Text('${m.prix} DA',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                          if (m.adresse.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 15, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(m.adresse,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                            ),
                          if (m.tel.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      size: 15, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(m.tel,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          if (m.stock.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(m.stock,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (m.tel.isNotEmpty) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _call(m.tel),
                                    icon: const Icon(Icons.call, size: 16),
                                    label: Text(_t('Appeler', 'اتصال')),
                                    style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(40)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _whatsapp(m.tel),
                                    icon: const Icon(Icons.message, size: 16),
                                    label: const Text('WhatsApp'),
                                    style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(40)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _itineraire(m.nom, m.adresse),
                                  icon: const Icon(Icons.directions, size: 16),
                                  label: Text(_t('Itinéraire', 'الاتجاهات')),
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(40)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_empty,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t(
                            'En attente de réponse des magasins. Leur fiche '
                            'de contact (nom, adresse, téléphone) '
                            'apparaîtra ici dès qu\'un magasin répondra.',
                            'في انتظار رد المتاجر. ستظهر هنا بطاقة الاتصال '
                            '(الاسم، العنوان، الهاتف) فور رد أحد المتاجر.',
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (part.conseils.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(part.conseils,
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _sending ? null : _envoyerDemande,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_t('Envoyer la demande', 'إرسال الطلب')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

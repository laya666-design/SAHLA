import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/ocr_service.dart';
import '../services/vehicule.dart';
import '../services/vehicule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner.dart';
import 'controle_technique_screen.dart';
import 'insurance_screen.dart';

class VehiclesScreen extends StatefulWidget {
  final AppConfig config;
  final bool isAr;
  final List<String> types;
  final String titre;
  final String titreAr;
  final String sousTitre;
  final String sousTitreAr;
  final IconData iconePrincipale;
  final String labelAjout;
  final String labelAjoutAr;
  final String labelVide;
  final String labelVideAr;

  const VehiclesScreen({
    super.key,
    required this.config,
    this.isAr = false,
    this.types = const [TypeVehicule.voiture],
    this.titre = 'Mes véhicules',
    this.titreAr = 'سياراتي',
    this.sousTitre =
        'Assurance, vignette et contrôle technique, par véhicule.',
    this.sousTitreAr = 'التأمين والرخصة والفحص التقني، لكل سيارة.',
    this.iconePrincipale = Icons.directions_car,
    this.labelAjout = 'Ajouter un véhicule',
    this.labelAjoutAr = 'إضافة سيارة',
    this.labelVide = 'Aucun véhicule pour le moment',
    this.labelVideAr = 'لا توجد سيارة حتى الآن',
  });

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Vehicule> _vehicules = [];

  bool get _ar => widget.isAr;
  String get _titre => _ar ? widget.titreAr : widget.titre;
  String get _sousTitre => _ar ? widget.sousTitreAr : widget.sousTitre;
  String get _labelAjout => _ar ? widget.labelAjoutAr : widget.labelAjout;
  String get _labelVide => _ar ? widget.labelVideAr : widget.labelVide;

  String _t(String fr, String ar) => _ar ? ar : fr;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Point d'entrée public utilisé par le FloatingActionButton de
  /// HomeScreen (via GlobalKey) pour ouvrir le formulaire d'ajout.
  Future<void> openAddDialog() => _openVehicleFormDialog();

  void _refresh() {
    setState(() => _vehicules = VehiculeService.getByTypes(widget.types));
  }

  IconData _iconForType(String type) {
    switch (type) {
      case TypeVehicule.moto:
        return Icons.two_wheeler;
      case TypeVehicule.scooter:
        return Icons.moped;
      default:
        return Icons.directions_car;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case TypeVehicule.moto:
        return _t('Moto', 'دراجة نارية');
      case TypeVehicule.scooter:
        return _t('Scooter', 'دراجة سكوتر');
      default:
        return _t('Voiture', 'سيارة');
    }
  }

  /// Dialogue partagé pour l'ajout ET la modification d'un véhicule.
  /// Si [existing] est fourni, le formulaire est pré-rempli et on met à
  /// jour ce véhicule au lieu d'en créer un nouveau.
  Future<void> _openVehicleFormDialog({Vehicule? existing}) async {
    final isEdit = existing != null;

    if (!isEdit) {
      final isPremium = SettingsService.isPremium;
      final canAddFree = VehiculeService.canAddFreeForTypes(widget.types);
      if (!isPremium && !canAddFree) {
        _showPremiumSheet();
        return;
      }
    }

    final nomController = TextEditingController(text: existing?.nom ?? '');
    final marqueController =
        TextEditingController(text: existing?.marque ?? '');
    String selectedType = existing?.type ?? widget.types.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit
              ? _t('Modifier le véhicule', 'تعديل المركبة')
              : _labelAjout),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.types.length > 1) ...[
                SegmentedButton<String>(
                  segments: widget.types
                      .map((t) => ButtonSegment<String>(
                            value: t,
                            label: Text(_labelForType(t)),
                            icon: Icon(_iconForType(t)),
                          ))
                      .toList(),
                  selected: {selectedType},
                  onSelectionChanged: (s) =>
                      setDialogState(() => selectedType = s.first),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: _t('Nom', 'الاسم'),
                  hintText: widget.types.contains(TypeVehicule.voiture)
                      ? _t('ex: Peugeot 208', 'مثال: بيجو 208')
                      : _t('ex: Yamaha 125', 'مثال: ياماها 125'),
                ),
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: marqueController,
                decoration: InputDecoration(
                  labelText: _t('Marque / modèle (optionnel)',
                      'الماركة / الطراز (اختياري)'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('Annuler', 'إلغاء')),
            ),
            FilledButton(
              onPressed: nomController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(
                  isEdit ? _t('Enregistrer', 'حفظ') : _t('Ajouter', 'إضافة')),
            ),
          ],
        ),
      ),
    );

    if (ok != true || nomController.text.trim().isEmpty) return;

    if (isEdit) {
      existing.nom = nomController.text.trim();
      existing.marque = marqueController.text.trim();
      existing.type = selectedType;
      await VehiculeService.update(existing);
    } else {
      final v = Vehicule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: nomController.text.trim(),
        marque: marqueController.text.trim(),
        type: selectedType,
      );
      await VehiculeService.add(v);
    }
    _refresh();
  }

  Future<void> _confirmDelete(Vehicule v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('Supprimer ce véhicule ?', 'حذف هذه المركبة؟')),
        content: Text(
          _t(
            'Cette action est définitive. "${v.nom}" et toutes ses données '
            '(assurance, contrôle technique) seront supprimées.',
            'هذا الإجراء نهائي. سيتم حذف "${v.nom}" وجميع بياناته '
            '(التأمين، الفحص التقني).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Annuler', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Supprimer', 'حذف')),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await VehiculeService.delete(v.id);
    _refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_t('"${v.nom}" a été supprimé.', 'تم حذف "${v.nom}".')),
        ),
      );
    }
  }

  void _showPremiumSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_t('Passe en Premium', 'الترقية إلى Premium'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _t(
                  'La version gratuite permet de gérer 1 élément dans cette '
                  'rubrique. Passe en Premium pour en ajouter sans limite, '
                  'et pour activer les rappels par SMS et appel.',
                  'تسمح النسخة المجانية بإدارة عنصر واحد فقط في هذا القسم. '
                  'قم بالترقية إلى Premium لإضافة عناصر بلا حدود، وتفعيل '
                  'التذكيرات عبر الرسائل النصية والمكالمات.',
                ),
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  title: Text(
                      _t('Rappels par SMS / Appel',
                          'تذكيرات عبر SMS / مكالمة'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _t(
                      'En plus des notifications sur le téléphone. '
                      'Bientôt disponible.',
                      'بالإضافة إلى إشعارات الهاتف. قريباً.',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: SettingsService.smsRemindersEnabled,
                  onChanged: (val) async {
                    await SettingsService.setSmsRemindersEnabled(val);
                    setSheetState(() {});
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_t('Bientôt disponible', 'قريباً')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVehicle(Vehicule v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(v.nom),
              bottom: TabBar(
                indicatorColor: Colors.white,
                tabs: [
                  Tab(
                      icon: const Icon(Icons.security),
                      text: _t('Assurance', 'التأمين')),
                  Tab(
                      icon: const Icon(Icons.fact_check),
                      text: _t('Contrôle technique', 'الفحص التقني')),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                InsuranceScreen(config: widget.config, vehicule: v),
                ControleTechniqueScreen(config: widget.config, vehicule: v),
              ],
            ),
          ),
        ),
      ),
    );
    _refresh();
  }

  Widget _statusChip(DateTime? expiration, String labelVide) {
    if (expiration == null) {
      return Chip(
        label: Text(labelVide, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
      );
    }
    final status = ExpiryStatus(expirationDate: expiration);
    Color bg;
    Color fg;
    switch (status.level) {
      case StatusLevel.ok:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case StatusLevel.warning:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case StatusLevel.expired:
        bg = AppColors.errorLight;
        fg = AppColors.errorText;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isExpired
            ? _t('Expiré depuis ${status.daysRemaining.abs()}j',
                'منتهي منذ ${status.daysRemaining.abs()} يوم')
            : _t('${status.daysRemaining}j restants',
                'باقي ${status.daysRemaining} يوم'),
        style:
            TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = SettingsService.isPremium;
    final showLockedCard =
        !isPremium && _vehicules.length >= VehiculeService.freeLimit;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_titre, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(_sousTitre, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            const AdBanner(),
            const SizedBox(height: 6),
            if (_vehicules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.iconePrincipale,
                            size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(height: 14),
                      Text(_labelVide,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ..._vehicules.map((v) => Card(
                  shape: AppTheme.cardShape,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openVehicle(v),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_iconForType(v.type),
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.nom,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (widget.types.length > 1)
                                      Chip(
                                        label: Text(_labelForType(v.type),
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    _statusChip(
                                        v.assuranceExpiration,
                                        _t('Assurance non renseignée',
                                            'التأمين غير محدد')),
                                    _statusChip(
                                        v.controleTechniqueExpiration,
                                        _t('CT non renseigné',
                                            'الفحص التقني غير محدد')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _t('Modifier', 'تعديل'),
                                icon: const Icon(Icons.edit_outlined,
                                    size: 19, color: AppColors.textMuted),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _openVehicleFormDialog(existing: v),
                              ),
                              IconButton(
                                tooltip: _t('Supprimer', 'حذف'),
                                icon: const Icon(Icons.delete_outline,
                                    size: 19, color: AppColors.error),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmDelete(v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
            if (showLockedCard)
              Card(
                shape: AppTheme.cardShape,
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.background,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const Icon(Icons.lock_outline,
                      color: AppColors.textMuted),
                  title: Text(
                    _t('Passe en Premium pour en ajouter plus',
                        'قم بالترقية إلى Premium لإضافة المزيد'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _t('Véhicules illimités avec Premium',
                        'مركبات غير محدودة مع Premium'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textMuted),
                  onTap: _showPremiumSheet,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

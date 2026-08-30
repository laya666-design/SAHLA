import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/models.dart';
import '../services/vehicule.dart';
import '../services/vehicule_service.dart';

/// Carte Grise Magic : scanne la carte grise (jaune) algérienne pour en
/// extraire automatiquement le type, l'année, le châssis et la puissance,
/// puis déduire le code moteur et le carburant. Ces infos alimentent
/// ensuite le Scanner IA pièces pour une identification bien plus fiable
/// qu'une simple photo de la pièce seule.
///
/// Deux modes :
/// - Création : [vehicule] est null. Le type ([typeVehicule]) est déjà
///   choisi par l'utilisateur avant d'arriver ici. Le scan crée directement
///   la fiche véhicule (nom = marque + modèle détectés) et appelle
///   [onVehiculeCree] avec le véhicule créé.
/// - Mise à jour : [vehicule] est fourni (ex: re-scanner après changement
///   de véhicule). Le scan met à jour la fiche existante.
class CarteGriseScreen extends StatefulWidget {
  final AppConfig config;
  final Vehicule? vehicule;
  final String typeVehicule;

  /// true quand ce widget est empilé dans la fiche véhicule à 3 sections
  /// plutôt qu'affiché seul dans son propre onglet.
  final bool embedded;

  /// Appelé une fois le véhicule créé (mode création uniquement).
  final void Function(Vehicule)? onVehiculeCree;

  const CarteGriseScreen({
    super.key,
    required this.config,
    this.vehicule,
    this.typeVehicule = TypeVehicule.voiture,
    this.embedded = false,
    this.onVehiculeCree,
  });

  @override
  State<CarteGriseScreen> createState() => _CarteGriseScreenState();
}

class _CarteGriseScreenState extends State<CarteGriseScreen> {
  final _picker = ImagePicker();
  final _gemini = GeminiService();

  File? _image;
  bool _loading = false;
  String? _error;
  CarteGriseInfo? _info;

  bool get _modeCreation => widget.vehicule == null;

  @override
  void initState() {
    super.initState();
    // Si le véhicule a déjà une carte grise enregistrée, on l'affiche
    // directement sans attendre un nouveau scan.
    final v = widget.vehicule;
    if (v != null && v.carteGriseRenseignee) {
      _info = CarteGriseInfo(
        marque: v.marque,
        chassis: v.chassisNumber,
        annee: v.year,
        puissanceFiscale: v.puissanceFiscale,
        immatriculation: v.immatriculation,
        engineCode: v.engineCode,
        fuelType: v.fuelType,
      );
    }
  }

  Future<void> _appliquerScan(CarteGriseInfo info) async {
    if (_modeCreation) {
      // Mode création : construit et sauvegarde un nouveau véhicule à
      // partir du scan. Le nom affiché = "Marque Modèle" si détectés,
      // sinon un nom générique pour ne jamais bloquer l'utilisateur.
      final nomDetecte = [info.marque, info.modele]
          .where((s) => s.trim().isNotEmpty)
          .join(' ')
          .trim();
      final v = Vehicule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: nomDetecte.isNotEmpty
            ? nomDetecte
            : (widget.typeVehicule == TypeVehicule.voiture
                ? 'Ma voiture'
                : 'Ma moto'),
        marque: info.marque,
        immatriculation: info.immatriculation,
        type: widget.typeVehicule,
        chassisNumber: info.chassis,
        year: info.annee,
        puissanceFiscale: info.puissanceFiscale,
        engineCode: info.engineCode,
        fuelType: info.fuelType,
      );
      await VehiculeService.add(v);
      widget.onVehiculeCree?.call(v);
      return;
    }

    // Mode mise à jour : complète la fiche existante sans écraser les
    // valeurs déjà connues quand le nouveau scan ne les redétecte pas.
    final v = widget.vehicule!;
    if (info.marque.isNotEmpty && v.marque.isEmpty) v.marque = info.marque;
    if (info.chassis.isNotEmpty) v.chassisNumber = info.chassis;
    if (info.annee != null) v.year = info.annee;
    if (info.puissanceFiscale.isNotEmpty) {
      v.puissanceFiscale = info.puissanceFiscale;
    }
    if (info.immatriculation.isNotEmpty && v.immatriculation.isEmpty) {
      v.immatriculation = info.immatriculation;
    }
    if (info.engineCode.isNotEmpty) v.engineCode = info.engineCode;
    if (info.fuelType.isNotEmpty) v.fuelType = info.fuelType;
    await VehiculeService.update(v);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
      _info = null;
    });

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _image = file;
      _loading = true;
    });

    try {
      final json = await _gemini.analyzeCarteGrise(file);
      if (json.containsKey('error')) {
        _error = 'Erreur : ${json['error']}';
      } else {
        final info = CarteGriseInfo.fromJson(json);
        if (info.estVide) {
          _error = 'Aucune information reconnue sur cette photo. '
              'Reprends la photo bien cadrée sur la carte grise.';
        } else {
          _info = info;
          await _appliquerScan(info);
        }
      }
    } catch (e) {
      _error = 'Erreur d\'analyse : $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            _modeCreation
                ? 'Scanner la carte grise'
                : 'Carte Grise — ${widget.vehicule!.nom}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _modeCreation
                ? 'Photographie la carte grise : la fiche du véhicule sera '
                    'créée automatiquement.'
                : 'Photographie la carte grise pour identifier le moteur et '
                    'améliorer la reconnaissance des pièces compatibles.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            '⚠️ Cadre bien le TABLEAU DU BAS (marque, type, châssis, '
            'puissance) : c\'est là que se trouvent toutes les infos '
            'utiles, pas seulement le haut avec le nom du propriétaire.',
            style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _loading ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Prendre Photo'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: widget.config.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _loading ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_image!, height: 180, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFF991B1B))),
          ),
        if (_info != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.config.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.config.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: widget.config.primaryColor, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _modeCreation
                          ? 'Véhicule créé'
                          : 'Moteur identifié',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow('Marque', _info!.marque),
                _infoRow('Modèle', _info!.modele),
                _infoRow('Année', _info!.annee?.toString() ?? ''),
                _infoRow('Châssis', _info!.chassis),
                _infoRow('Puissance fiscale', _info!.puissanceFiscale),
                _infoRow('Code moteur', _info!.engineCode),
                _infoRow('Carburant', _info!.fuelType),
                if (_info!.engineCode.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Code moteur non déduit avec certitude — '
                      'vérifiable sur le carnet d\'entretien.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          if (!_modeCreation) ...[
            const SizedBox(height: 12),
            Text(
              'Ces infos seront utilisées automatiquement dans le Scanner '
              'IA pièces pour affiner l\'identification.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ],
    );

    if (widget.embedded) return content;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}

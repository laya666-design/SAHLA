class InsuranceInfo {
  final String compagnie;
  final String nom;
  final String marque;
  final String police;
  final String debut;
  final String expirationStr;

  InsuranceInfo({
    this.compagnie = '',
    this.nom = '',
    this.marque = '',
    this.police = '',
    this.debut = '',
    this.expirationStr = '',
  });

  factory InsuranceInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return InsuranceInfo();
    return InsuranceInfo(
      compagnie: json['compagnie']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      marque: json['marque']?.toString() ?? '',
      police: json['police']?.toString() ?? '',
      debut: json['debut']?.toString() ?? '',
      expirationStr: json['expiration']?.toString() ?? '',
    );
  }
}

class ControleTechniqueInfo {
  final String centre;
  final String numero;
  final String kilometrage;
  final String dateProchainControle; // format dd/MM/yyyy tel que renvoyé par Gemini

  ControleTechniqueInfo({
    this.centre = '',
    this.numero = '',
    this.kilometrage = '',
    this.dateProchainControle = '',
  });

  factory ControleTechniqueInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ControleTechniqueInfo();
    return ControleTechniqueInfo(
      centre: json['centre']?.toString() ?? '',
      numero: json['numero']?.toString() ?? '',
      kilometrage: json['kilometrage']?.toString() ?? '',
      dateProchainControle:
          json['date_prochain_controle']?.toString() ?? '',
    );
  }

  /// Parse le champ dd/MM/yyyy renvoyé par Gemini, ou null si absent/invalide.
  DateTime? get dateProchainControleParsed {
    final s = dateProchainControle.trim();
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}

/// Résultat du scan d'une carte grise algérienne (jaune), avec déduction
/// du code moteur / carburant pour alimenter la compatibilité pièces.
class CarteGriseInfo {
  final String marque;
  final String modele;
  final String type; // "type" tel qu'imprimé sur la carte grise
  final int? annee;
  final String chassis;
  final String puissanceFiscale;
  final String immatriculation;
  final String engineCode; // déduit, ex: "K9K"
  final String fuelType; // déduit, ex: "diesel"

  CarteGriseInfo({
    this.marque = '',
    this.modele = '',
    this.type = '',
    this.annee,
    this.chassis = '',
    this.puissanceFiscale = '',
    this.immatriculation = '',
    this.engineCode = '',
    this.fuelType = '',
  });

  factory CarteGriseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CarteGriseInfo();
    var marque = _cleanNull(json['marque']?.toString());
    final modele = _cleanNull(json['modele']?.toString());
    final chassis = _cleanNull(json['chassis']?.toString()).toUpperCase();
    var fuelType = _cleanNull(json['fuel_type']?.toString()).toLowerCase();
    var engineCode = _cleanNull(json['engine_code']?.toString());

    // 1) Traduire le mot arabe de la case MARQUE → latin
    marque = _arabeVersLatin(marque);

    // 2) Le code type (chassis) est plus fiable que l'IA quand il y a conflit.
    //    Ex: NCP92 = TOYOTA, jamais RENAULT/DACIA.
    final marqueDepuisChassis = _deduireMarqueDepuisChassis(chassis);
    if (marqueDepuisChassis.isNotEmpty) {
      // Si l'IA a mis une mauvaise marque, on corrige avec le prefixe chassis.
      if (marque.isEmpty ||
          (marque != marqueDepuisChassis &&
              _estCodeType(marque))) {
        marque = marqueDepuisChassis;
      } else if (marque != marqueDepuisChassis &&
          !_marquesCompatibles(marque, marqueDepuisChassis)) {
        // Conflit clair (ex: AI dit RENAULT mais chassis NCP) → trust chassis
        marque = marqueDepuisChassis;
      }
    }

    // 3) Normaliser carburant
    if (fuelType.contains('gpl')) {
      fuelType = 'gpl';
    } else if (fuelType.contains('diesel') || fuelType.contains('gasoil')) {
      fuelType = 'diesel';
    } else if (fuelType.contains('essence')) {
      fuelType = 'essence';
    }

    // 4) Si engine_code invente pour mauvaise marque, on nettoie
    if (marque == 'TOYOTA' && engineCode.toUpperCase() == 'K9K') {
      engineCode = ''; // K9K = Renault/Dacia, pas Toyota
    }

    return CarteGriseInfo(
      marque: marque,
      modele: modele,
      type: _cleanNull(json['type']?.toString()),
      annee: int.tryParse(json['annee']?.toString() ?? ''),
      chassis: chassis,
      puissanceFiscale: _cleanNull(json['puissance_fiscale']?.toString()),
      immatriculation: _cleanNull(json['immatriculation']?.toString()),
      engineCode: engineCode,
      fuelType: fuelType,
    );
  }

  static String _cleanNull(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty || t.toLowerCase() == 'null') return '';
    return t;
  }

  static bool _estCodeType(String s) =>
      RegExp(r'^[A-Z0-9]{5,}$').hasMatch(s.toUpperCase());

  static bool _marquesCompatibles(String a, String b) {
    // Renault et Dacia partagent souvent les memes plateformes
    final group = {
      'RENAULT': 'renault_group',
      'DACIA': 'renault_group',
    };
    return (group[a] ?? a) == (group[b] ?? b);
  }

  /// Traduit le mot arabe de la case MARQUE vers le latin.
  static String _arabeVersLatin(String s) {
    if (s.isEmpty) return s;
    final map = <String, String>{
      'تويوتا': 'TOYOTA',
      'رينو': 'RENAULT',
      'بيجو': 'PEUGEOT',
      'سيتروين': 'CITROEN',
      'داكيا': 'DACIA',
      'هيونداي': 'HYUNDAI',
      'كيا': 'KIA',
      'نيسان': 'NISSAN',
      'فولكس فاجن': 'VOLKSWAGEN',
      'فولكسفاجن': 'VOLKSWAGEN',
      'مرسيدس': 'MERCEDES',
      'بي ام دبليو': 'BMW',
      'سوزوكي': 'SUZUKI',
      'شيفروليه': 'CHEVROLET',
      'فيات': 'FIAT',
      'اوبل': 'OPEL',
      'سكودا': 'SKODA',
      'ميتسوبيشي': 'MITSUBISHI',
      'هوندا': 'HONDA',
      'فورد': 'FORD',
      'سيات': 'SEAT',
      'اودي': 'AUDI',
    };
    for (final e in map.entries) {
      if (s.contains(e.key)) return e.value;
    }
    if (RegExp(r'^[A-Za-z0-9 \-]+$').hasMatch(s)) return s.toUpperCase();
    return s;
  }

  /// Prefixe chassis / code type → constructeur (tres fiable en Algerie).
  static String _deduireMarqueDepuisChassis(String chassis) {
    final c = chassis.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (c.startsWith('NCP') ||
        c.startsWith('NSP') ||
        c.startsWith('NZE') ||
        c.startsWith('NZT') ||
        c.startsWith('KSP') ||
        c.startsWith('JT') ||
        c.startsWith('SB1')) return 'TOYOTA';
    if (c.startsWith('VF1') || c.startsWith('VF2')) return 'RENAULT';
    if (c.startsWith('VF3')) return 'PEUGEOT';
    if (c.startsWith('VF7') || c.startsWith('VR7')) return 'CITROEN';
    if (c.startsWith('UU1') || c.startsWith('VSU')) return 'DACIA';
    if (c.startsWith('WVW') || c.startsWith('WV1') || c.startsWith('WV2')) {
      return 'VOLKSWAGEN';
    }
    if (c.startsWith('KMH') || c.startsWith('KMF') || c.startsWith('TMA')) {
      return 'HYUNDAI';
    }
    if (c.startsWith('KNA') || c.startsWith('U5Y')) return 'KIA';
    if (c.startsWith('JN1') || c.startsWith('SJN') || c.startsWith('VSK')) {
      return 'NISSAN';
    }
    if (c.startsWith('WDB') || c.startsWith('WDD') || c.startsWith('W1K')) {
      return 'MERCEDES';
    }
    if (c.startsWith('WBA') || c.startsWith('WBS')) return 'BMW';
    if (c.startsWith('JSA') || c.startsWith('TSM') || c.startsWith('JS2')) {
      return 'SUZUKI';
    }
    if (c.startsWith('1G1') || c.startsWith('KL1') || c.startsWith('LSG')) {
      return 'CHEVROLET';
    }
    if (c.startsWith('ZFA') || c.startsWith('ZFB')) return 'FIAT';
    if (c.startsWith('W0L') || c.startsWith('W0V')) return 'OPEL';
    if (c.startsWith('TMB')) return 'SKODA';
    if (c.startsWith('WAU')) return 'AUDI';
    if (c.startsWith('JHM') || c.startsWith('JH4')) return 'HONDA';
    return '';
  }

  bool get estVide =>
      marque.isEmpty && modele.isEmpty && chassis.isEmpty && annee == null;
}

class StoreOffer {
  final String nom;
  final num prix;
  final String tel;
  final String stock;
  final String adresse;

  StoreOffer({
    required this.nom,
    required this.prix,
    this.tel = '',
    this.stock = '',
    this.adresse = '',
  });

  factory StoreOffer.fromJson(Map<String, dynamic> json) {
    return StoreOffer(
      nom: json['nom']?.toString() ?? '',
      prix: (json['prix'] is num) ? json['prix'] as num : 0,
      tel: json['tel']?.toString() ?? '',
      stock: json['stock']?.toString() ?? '',
      adresse: json['adresse']?.toString() ?? '',
    );
  }
}

class CarPartInfo {
  final String nom;
  final String reference;
  final List<String> compatibilite;
  final num prixDa;
  final num prixOrigine;
  final String disponibilite;
  final String etat;
  final String conseils;
  final List<StoreOffer> magasins;

  CarPartInfo({
    this.nom = '',
    this.reference = '',
    this.compatibilite = const [],
    this.prixDa = 0,
    this.prixOrigine = 0,
    this.disponibilite = '',
    this.etat = '',
    this.conseils = '',
    this.magasins = const [],
  });

  factory CarPartInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CarPartInfo();
    return CarPartInfo(
      nom: json['nom']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      compatibilite: (json['compatibilite'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      prixDa: (json['prix_da'] is num) ? json['prix_da'] as num : 0,
      prixOrigine:
          (json['prix_origine'] is num) ? json['prix_origine'] as num : 0,
      disponibilite: json['disponibilite']?.toString() ?? '',
      etat: json['etat']?.toString() ?? '',
      conseils: json['conseils']?.toString() ?? '',
      magasins: (json['magasins'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((e) => StoreOffer.fromJson(e))
              .toList() ??
          const [],
    );
  }
}

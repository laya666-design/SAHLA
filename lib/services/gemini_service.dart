import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Version Cloudflare Worker + Groq
/// La cle API Groq est protegee cote serveur (Worker), jamais exposee dans l app.

class GeminiService {
  static const String _workerUrl =
      'https://tight-smoke-4dfa.laya666.workers.dev';

  Future<String> _callGroq(
    String prompt,
    File file, {
    String reasoningEffort = 'none',
  }) async {
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = {
      "model": "qwen/qwen3.6-27b",
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
            }
          ]
        }
      ],
      "temperature": 0.2,
      "reasoning_effort": reasoningEffort,
      // Le mode reflexion ("default") genere du texte de raisonnement avant
      // le JSON final : il faut assez de tokens pour ne pas couper la
      // reponse avant qu elle n arrive au JSON.
      "max_completion_tokens": reasoningEffort == 'none' ? 1024 : 4096,
    };

    final response = await http.post(
      Uri.parse(_workerUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    final content = data['choices']?[0]?['message']?['content'];
    if (content == null) {
      throw Exception('Reponse vide du serveur');
    }
    return content as String;
  }

  /// Transforme une erreur technique (JSON invalide, reponse tronquee,
  /// contenant encore un bloc <think> non ferme, etc.) en message
  /// comprehensible pour l utilisateur, plutot que d afficher la
  /// FormatException brute dans l ecran.
  String _friendlyOcrError(Object e) {
    final msg = e.toString();
    if (msg.contains('<think>') || msg.contains('FormatException')) {
      return 'Analyse impossible (reponse invalide). Reessayez avec une '
          'photo plus nette et bien eclairee.';
    }
    return msg;
  }

  Map<String, dynamic> _parseJson(String raw) {
    // Retire un eventuel bloc de raisonnement <think>...</think>
    String cleaned =
        raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      json['magasins'] = [];
      return json;
    } catch (_) {
      // Filet de secours: extrait le premier bloc { ... } trouve dans le texte
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        json['magasins'] = [];
        return json;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeInsuranceCard(File file) async {
    try {
      final prompt = '''
Tu es un expert assurance auto pour l Algerie.
REGLE CRITIQUE: Ne jamais inventer de nom de magasin, adresse ou telephone.
Analyse cette image de carte jaune assurance auto algerienne.
Retourne UNIQUEMENT ce JSON (aucun texte avant/apres, pas de markdown):

{
  "compagnie": "string ou null",
  "nom_assure": "string ou null",
  "marque_vehicule": "string ou null",
  "numero_police": "string ou null",
  "date_expiration": "dd/MM/yyyy ou null",
  "jours_restants": 0,
  "magasins": []
}

REGLE: magasins doit toujours etre un tableau vide [].
''';

      final raw = await _callGroq(prompt, file);
      return _parseJson(raw);
    } catch (e) {
      return {'error': _friendlyOcrError(e), 'magasins': []};
    }
  }

  Future<Map<String, dynamic>> analyzeControleTechnique(File file) async {
    try {
      final prompt = '''
Tu es un expert controle technique automobile pour l Algerie.
REGLE CRITIQUE: Ne jamais inventer de nom de centre, adresse ou telephone.
Analyse cette image d attestation de controle technique algerien (document
bilingue arabe/francais, souvent intitule "Proces-verbal de controle
technique des vehicules" / "محضر المراقبة التقنية للسيارات").

ATTENTION: ce document contient PLUSIEURS dates differentes, il faut choisir
la bonne :
- la date d enregistrement/immatriculation du vehicule (pres du numero de
  registration, ex "12/12/2023") -> CE N EST PAS la bonne date, ignore-la.
- la date de la visite technique qui vient d etre effectuee (champ
  "تاريخ المراقبة" / "DATE" en haut du tableau) -> ce n est pas non plus la
  date a retourner.
- la date de la PROCHAINE visite periodique programmee, generalement ecrite
  plus bas sur le document, souvent apres la mention
  "طبيعة وتاريخ المراقبة اللاحقة" / "VISITE PERIODIQUE LE" / "prochaine
  visite" -> C EST CETTE DATE qu il faut mettre dans "date_prochain_controle".
Cette date de prochaine visite est presque toujours la plus eloignee dans le
futur parmi toutes les dates visibles sur le document (generalement 1 an
apres la date de la visite actuelle).

Retourne UNIQUEMENT ce JSON (aucun texte avant/apres, pas de markdown):

{
  "centre": "string ou null",
  "numero": "string ou null",
  "kilometrage": "string ou null",
  "date_prochain_controle": "dd/MM/yyyy ou null",
  "jours_restants": 0
}

REGLE: ne jamais inventer d informations non visibles sur l image. Si tu
hesites entre deux dates, prends celle qui correspond a la prochaine visite
periodique (la plus recente/future), jamais la date d enregistrement du
vehicule.
''';

      final raw = await _callGroq(prompt, file);
      final json = _parseJson(raw);
      json.remove('magasins');
      return json;
    } catch (e) {
      return {'error': _friendlyOcrError(e)};
    }
  }

  /// Analyse une photo de carte grise algérienne (jaune) : extrait les
  /// champs officiels (type, année, châssis, puissance) puis déduit le
  /// code moteur et le carburant pour alimenter la compatibilité pièces
  /// (voir Vehicule.engineCode / fuelType).
  Future<Map<String, dynamic>> analyzeCarteGrise(File file) async {
    try {
      final prompt = '''
Tu es un expert OCR de cartes grises algeriennes.
REGLE ABSOLUE: Ne jamais inventer. Si illisible → null.

=== TACHE PRINCIPALE : LIRE LE MOT ARABE DANS LA CASE "MARQUE" ===

Dans le tableau du bas de la carte grise, il y a une case avec :
- en haut : "الصنف"
- en bas : "MARQUE"

A L INTERIEUR de cette case se trouve un MOT EN ARABE (ex: تويوتا, رينو, بيجو, هيونداي, كيا, داكيا, نيسان...).

1. Lis CE MOT ARABE exactement tel qu il est ecrit dans la case.
2. Traduis-le en francais/latin majuscules :
   تويوتا → TOYOTA
   رينو → RENAULT
   بيجو → PEUGEOT
   سيتروين → CITROEN
   داكيا → DACIA
   هيونداي → HYUNDAI
   كيا → KIA
   نيسان → NISSAN
   فولكسفاجن → VOLKSWAGEN
   مرسيدس → MERCEDES
   سوزوكي → SUZUKI
   شيفروليه → CHEVROLET
   فيات → FIAT
   اوبل → OPEL
   سكودا → SKODA
   ميتسوبيشي → MITSUBISHI
   هوندا → HONDA
   فورد → FORD
3. Mets le resultat latin dans "marque".

NE PRENDS PAS le code type (NCP92..., K9K, VF1...) pour la marque.
Le code type est dans la case VOISINE "الطراز" → mets-le dans "chassis".

Autres champs a extraire :
- الطراز → chassis (code type)
- القوة / PUISSANCE → puissance_fiscale (ex: 005)
- الطاقة / ENERGIE → fuel_type (gpl / diesel / essence)
- Annee de 1ere mise en circulation → annee (aaaa)

Deduction engine_code uniquement si marque + chassis sont fiables.

Retourne UNIQUEMENT ce JSON :

{
  "marque": "string ou null",
  "modele": "string ou null",
  "type": "string ou null",
  "annee": "aaaa ou null",
  "chassis": "string ou null",
  "puissance_fiscale": "string ou null",
  "immatriculation": "string ou null",
  "engine_code": "string ou null",
  "fuel_type": "diesel, essence ou gpl ou null"
}
''';

      final raw = await _callGroq(prompt, file);
      final json = _parseJson(raw);
      json.remove('magasins');
      return json;
    } catch (e) {
      return {'error': _friendlyOcrError(e)};
    }
  }

  /// [vehicleContext] optionnel : résumé véhicule (ex: "Renault Clio 4 · K9K
  /// · diesel") issu de la carte grise scannée. Quand renseigné, Gemini
  /// identifie la piece en connaissant deja le moteur/la motorisation
  /// au lieu de deviner uniquement sur la photo — moins d ambiguite sur
  /// la reference et la compatibilite.
  Future<Map<String, dynamic>> analyzeCarPart(
    File file, {
    String vehicleContext = '',
  }) async {
    try {
      final contexteVehicule = vehicleContext.trim().isEmpty
          ? ''
          : '''
Contexte vehicule connu (issu de la carte grise scannee par l utilisateur,
fiable, ne pas ignorer) : $vehicleContext
Utilise ce contexte pour affiner la reference exacte et la compatibilite,
plutot que de deviner uniquement a partir de la photo.
''';

      final prompt = '''
Tu es un expert pieces auto pour l Algerie (Annaba).
REGLE CRITIQUE: Ne jamais inventer de nom de magasin, adresse ou telephone.
Identifie la piece auto sur la photo pour le marche Algerien.
$contexteVehicule
Retourne UNIQUEMENT ce JSON (aucun texte avant/apres, pas de markdown):

{
  "nom": "nom exact piece",
  "reference": "reference possible ou null",
  "compatibilite": ["Clio 4", "Symbol", "etc"],
  "prix_dzd_min": 0,
  "prix_dzd_max": 0,
  "conseil": "conseil montage court",
  "magasins": []
}

REGLE CRITIQUE: magasins = [] toujours vide. Ne jamais inventer de telephone.
''';

      final raw = await _callGroq(prompt, file);
      return _parseJson(raw);
    } catch (e) {
      return {'error': _friendlyOcrError(e), 'magasins': []};
    }
  }
}

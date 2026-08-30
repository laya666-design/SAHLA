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
Tu es un expert en cartes grises automobiles algeriennes.
REGLE CRITIQUE: Ne jamais inventer une information non visible sur l image.
Si un champ n est pas lisible, mets null.

Ce document est majoritairement en ARABE ; les cases francaises
(MARQUE, TYPE, GENRE...) sont parfois vides ou tres petites alors que la
valeur reelle n est ecrite qu en arabe a cote. Tu dois donc lire et
comprendre le texte arabe du document, pas seulement les libelles francais.
Cherche la valeur du champ "الطراز" (marque/modele) et "النوع" (type) en
arabe si la case francaise correspondante est vide.

IMPORTANT sur l emplacement de la marque : dans le tableau d identification
du vehicule (partie basse du document), la marque est tres souvent ecrite
en LETTRES LATINES MAJUSCULES (ex "TOYOTA", "RENAULT", "PEUGEOT", "NISSAN"...)
dans la case juste a cote/en dessous du libelle arabe "العلامة", generalement
sur la meme ligne que le "النوع" (type/genre, ex "VP / VEHICULE PARTICULIER").
Regarde precisement cette case en priorite : c est la source la plus fiable
de la marque, plus fiable que toute deduction. Zoome mentalement sur cette
zone precise avant de conclure, la photo etant souvent floue ou pale.

Le champ "chassis"/numero dans la serie du type (ex: NCP92L..., JTD...,
VF1..., JN1...) est un indice utile sur le constructeur reel, mais NE
DEDUIS PAS la marque a partir de ce prefixe seul si le texte du document
(arabe ou francais) indique clairement une autre marque, ou si aucune
marque n est explicitement lisible : dans ce dernier cas mets "marque":
null plutot que de deviner. Ne choisis jamais une marque uniquement parce
qu elle "correspond" a la puissance fiscale ou au type de carrosserie.

Une fois les champs officiels extraits, deduis le code moteur et le type de
carburant a partir de la marque/modele/type/puissance fiscale (connaissance
generale du marche automobile, pas invente au hasard) ; si la marque elle
meme est incertaine, mets aussi engine_code et fuel_type a null plutot que
d inventer une combinaison plausible.

Retourne UNIQUEMENT ce JSON (aucun texte avant/apres, pas de markdown):

{
  "marque": "string ou null",
  "modele": "string ou null",
  "type": "string ou null",
  "annee": "aaaa ou null",
  "chassis": "string ou null",
  "puissance_fiscale": "string ou null",
  "immatriculation": "string ou null",
  "engine_code": "ex K9K, deduit ou null si incertain",
  "fuel_type": "diesel, essence ou gpl, deduit ou null si incertain"
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

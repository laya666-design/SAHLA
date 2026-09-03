import 'package:flutter/material.dart';
import '../../services/store_service.dart';

/// Demande le téléphone de l'utilisateur (une seule fois, avant le
/// premier envoi d'une alerte SOS — voir SettingsService.userTel) afin
/// que la dépanneuse qui accepte puisse le rappeler. Retourne le numéro
/// normalisé (ex: "0556653220"), ou null si l'utilisateur annule.
Future<String?> showTelPickerDialog(
  BuildContext context, {
  required Color accentColor,
  String? valeurInitiale,
}) {
  final controller = TextEditingController(text: valeurInitiale ?? '');
  String? erreur;
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Ton numéro de téléphone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pour que la dépanneuse qui accepte puisse te rappeler.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '0556 65 32 20',
                  errorText: erreur,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accentColor),
              onPressed: () {
                final numero =
                    StoreService.normaliserNumeroLocal(controller.text);
                if (numero == null) {
                  setState(() => erreur =
                      'Numéro invalide. Format : 0556 65 32 20.');
                  return;
                }
                Navigator.pop(ctx, numero);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      );
    },
  );
}

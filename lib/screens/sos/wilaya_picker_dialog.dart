import 'package:flutter/material.dart';
import '../../config/wilayas.dart';

/// Demande la wilaya de l'utilisateur (une seule fois, avant le premier
/// envoi d'une alerte SOS — voir SettingsService.wilaya). Retourne null
/// si l'utilisateur annule.
Future<String?> showWilayaPickerDialog(
  BuildContext context, {
  required Color accentColor,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String? selection;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Ta wilaya'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nécessaire pour prévenir les dépanneuses de ta wilaya.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selection,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: kWilayasAlgerie
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: (v) => setState(() => selection = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accentColor),
              onPressed:
                  selection == null ? null : () => Navigator.pop(ctx, selection),
              child: const Text('Valider'),
            ),
          ],
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bannière partenaire assurance — Phase 3.
///
/// 100% statique : pas de backend, juste un texte + un lien vers l'offre
/// partenaire. N'est affichée que quand l'échéance approche ou est dépassée.
/// Pour changer d'offre/partenaire plus tard, il suffit de modifier les
/// constantes ci-dessous et de reconstruire l'app (pas besoin de serveur
/// tant qu'on reste sur une offre statique).
class PartnerBanner extends StatelessWidget {
  final int daysRemaining;
  final bool isExpired;

  const PartnerBanner({
    super.key,
    required this.daysRemaining,
    required this.isExpired,
  });

  /// Seuil d'affichage : jours restants en-dessous duquel la bannière
  /// apparaît (alignée sur le seuil "warning" déjà utilisé pour le badge).
  static const int seuilJours = 30;

  // --- Offre partenaire statique (à remplacer une fois le contrat signé) ---
  static const String _partnerName = 'Notre partenaire assurance';
  static const String _partnerUrl = 'https://example-partenaire-assurance.dz';

  Future<void> _open() async {
    final uri = Uri.parse(_partnerUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final message = isExpired
        ? 'Assurance expirée. Compare les offres et renouvelle vite.'
        : 'Expire dans $daysRemaining jour${daysRemaining > 1 ? 's' : ''} — '
            'compare les offres avant de renouveler.';

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Color(0xFFC2410C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(_partnerName,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC2410C)),
          ],
        ),
      ),
    );
  }
}

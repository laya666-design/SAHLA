import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/marketplace_service.dart';
import '../services/store_service.dart';
import '../widgets/screen_background.dart';
import 'buyer_portal_screen.dart';
import 'marketplace/buyer_phone_login_screen.dart';
import 'marketplace/store_dashboard_screen.dart';
import 'marketplace/store_phone_login_screen.dart';

/// Entrée de l'onglet "Pièces" : deux branches distinctes.
/// - Portail acheteur : connexion téléphone (recommandée) ou anonyme,
///   scan photo + suivi de "Mes demandes".
/// - Portail vendeur (Espace magasin) : réservé aux magasins, protégé par
///   un compte. Un client sans compte magasin ne peut jamais y entrer.
class PartsPortalScreen extends StatelessWidget {
  final AppConfig config;
  final bool isAr;
  const PartsPortalScreen({super.key, required this.config, this.isAr = false});

  bool get _ar => isAr;
  String _t(String fr, String ar) => _ar ? ar : fr;

  @override
  Widget build(BuildContext context) {
    return ScreenBackground(
      category: BackgroundCategory.pieces,
      accentColor: config.primaryColor,
      child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_t('Pièces détachées', 'قطع الغيار'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              _t('Choisis ton profil pour continuer.', 'اختر ملفك للمتابعة.'),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              _t('Particulier → Acheteur  •  Magasin → Vendeur',
                  'فرد → مشترٍ  •  متجر → بائع'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            // Carte Acheteur mise en avant : c'est le parcours du grand
            // public, elle doit sauter aux yeux en premier.
            _PortalCard(
              icon: Icons.camera_alt_outlined,
              title: _t('Je cherche une pièce', 'أبحث عن قطعة'),
              subtitle: _t(
                'Photographie ta pièce cassée → on trouve la référence et '
                'on envoie ta demande aux magasins.',
                'صوّر القطعة المكسورة → نجد المرجع ونرسل طلبك للمتاجر.',
              ),
              color: config.primaryColor,
              highlighted: true,
              onTap: () async {
                await MarketplaceService.loadPhoneAsId();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarketplaceService.hasSession
                        ? BuyerPortalScreen(config: config, isAr: isAr)
                        : BuyerPhoneLoginScreen(config: config, isAr: isAr),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(_t('ou', 'أو'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
            ),
            // Carte Vendeur : reste accessible et bien visible (l'inscription
            // magasin doit rester en libre-service), simplement moins mise
            // en avant visuellement que la carte Acheteur — le badge
            // "Professionnel" suffit à orienter le bon public.
            _PortalCard(
              icon: Icons.storefront_outlined,
              title: _t('Espace magasin', 'فضاء المتجر'),
              proBadge: _t('Professionnel', 'مهني'),
              subtitle: _t(
                'Reçois les demandes des clients, propose ton prix et '
                'gère ton abonnement.',
                'استقبل طلبات العملاء، اقترح سعرك وأدر اشتراكك.',
              ),
              color: Colors.black87,
              onTap: () async {
                await StoreService.loadPhoneAsId();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreService.isLoggedIn
                        ? StoreDashboardScreen(config: config)
                        : StorePhoneLoginScreen(config: config),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool highlighted;
  final String? proBadge;

  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlighted = false,
    this.proBadge,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: highlighted ? color.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? color.withOpacity(0.4) : Colors.grey.shade300,
              width: highlighted ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(highlighted ? 0.10 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre d'accent en haut : signale visuellement la carte mise
              // en avant sans avoir besoin d'un fond sombre comme la maquette.
              if (highlighted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(height: 3, decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  )),
                ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                            if (proBadge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(proBadge!,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: highlighted ? color : Colors.black38),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

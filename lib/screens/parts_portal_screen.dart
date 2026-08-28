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
            const SizedBox(height: 28),
            _PortalCard(
              icon: Icons.camera_alt_outlined,
              title: _t('Portail acheteur', 'بوابة المشتري'),
              subtitle: _t(
                'Photographie ta pièce cassée, obtiens la référence et '
                'diffuse ta demande aux magasins.',
                'صوّر القطعة المكسورة، احصل على المرجع وأرسل طلبك للمتاجر.',
              ),
              color: config.primaryColor,
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
            const SizedBox(height: 16),
            _PortalCard(
              icon: Icons.storefront_outlined,
              title: _t('Portail vendeur — Espace magasin', 'بوابة البائع'),
              subtitle: _t(
                'Réservé aux magasins : reçois les commandes des clients, '
                'réponds avec ton prix, gère ton abonnement.',
                'مخصص للمتاجر: استقبل الطلبات، أجب بالسعر، أدر اشتراكك.',
              ),
              color: Colors.black87,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreService.isLoggedIn
                      ? StoreDashboardScreen(config: config)
                      : StorePhoneLoginScreen(config: config),
                ),
              ),
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

  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
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
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

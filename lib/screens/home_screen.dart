import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/vehicule.dart';
import 'parts_portal_screen.dart';
import 'profile_screen.dart';
import 'vehicles_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  final ValueNotifier<bool> isAr;

  const HomeScreen({super.key, required this.config, required this.isAr});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Clés pour pouvoir déclencher l'ouverture du formulaire d'ajout
  // depuis le FloatingActionButton du Scaffold parent (les VehiclesScreen
  // n'ont pas leur propre Scaffold, donc pas leur propre FAB).
  final _voituresKey = GlobalKey<State<VehiclesScreen>>();
  final _motosKey = GlobalKey<State<VehiclesScreen>>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isAr,
      builder: (context, isAr, _) {
        final screens = [
          VehiclesScreen(key: _voituresKey, config: widget.config, isAr: isAr),
          VehiclesScreen(
            key: _motosKey,
            config: widget.config,
            isAr: isAr,
            types: const [TypeVehicule.moto, TypeVehicule.scooter],
            titre: 'Motos & scooters',
            titreAr: 'الدراجات النارية',
            sousTitre:
                'Assurance, vignette et contrôle technique, par deux-roues.',
            sousTitreAr: 'التأمين والرخصة والفحص التقني، لكل دراجة.',
            iconePrincipale: Icons.two_wheeler,
            labelAjout: 'Ajouter une moto / un scooter',
            labelAjoutAr: 'إضافة دراجة نارية / سكوتر',
            labelVide: 'Aucune moto ni scooter pour le moment',
            labelVideAr: 'لا توجد دراجة حتى الآن',
          ),
          PartsPortalScreen(config: widget.config, isAr: isAr),
          ProfileScreen(config: widget.config, isAr: widget.isAr),
        ];

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.config.appName),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _LangToggle(
                    isAr: isAr,
                    onTap: () => widget.isAr.value = !isAr,
                  ),
                ),
              ],
            ),
            body: IndexedStack(index: _index, children: screens),
            floatingActionButton: (_index == 0 || _index == 1)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      final key = _index == 0 ? _voituresKey : _motosKey;
                      (key.currentState as dynamic)?.openAddDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: Text(_index == 0
                        ? (isAr ? 'إضافة سيارة' : 'Ajouter')
                        : (isAr ? 'إضافة دراجة' : 'Ajouter')),
                  )
                : null,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.directions_car),
                  label: isAr ? 'سياراتي' : 'Véhicules',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.two_wheeler),
                  label: isAr ? 'دراجاتي' : 'Motos',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.build),
                  label: isAr ? 'القطع' : 'Pièces',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: isAr ? 'حسابي' : 'Profil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Interrupteur FR/AR en forme de pilule dans l'AppBar — remplace le
/// simple texte cliquable par un composant avec un vrai état actif/inactif.
class _LangToggle extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;
  const _LangToggle({required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _label('FR', !isAr),
            Text('  /  ',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            _label('AR', isAr),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, bool active) {
    return Text(
      text,
      style: TextStyle(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }
}

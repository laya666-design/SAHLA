import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/vehicule.dart';
import '../services/vehicule_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isAr,
      builder: (context, isAr, _) {
        // Profil choisi à l'onboarding (voiture / moto / les deux) :
        // pilote quels onglets sont affichés. 'both' par défaut si
        // jamais absent (ne devrait pas arriver, l'onboarding est
        // obligatoire avant d'atteindre cet écran).
        final profile = SettingsService.vehicleProfile ?? 'both';
        final showVoiture = profile == 'voiture' || profile == 'both';
        final showMoto = profile == 'moto' || profile == 'both';

        final screens = <Widget>[
          if (showVoiture) VehiclesScreen(config: widget.config, isAr: isAr),
          if (showMoto)
            VehiclesScreen(
              config: widget.config,
              isAr: isAr,
              types: const [TypeVehicule.moto, TypeVehicule.scooter],
              titre: 'Motos & scooters',
              titreAr: 'الدراجات النارية',
              sousTitre: 'Assurance et contrôle technique, par deux-roues.',
              sousTitreAr: 'التأمين والفحص التقني، لكل دراجة.',
              iconePrincipale: Icons.two_wheeler,
              labelAjout: 'Ajouter une moto / un scooter',
              labelAjoutAr: 'إضافة دراجة نارية / سكوتر',
              labelVide: 'Aucune moto ni scooter pour le moment',
              labelVideAr: 'لا توجد دراجة حتى الآن',
            ),
          PartsPortalScreen(config: widget.config, isAr: isAr),
          ProfileScreen(
            config: widget.config,
            isAr: widget.isAr,
            onVehicleProfileChanged: () => setState(() {}),
          ),
        ];

        final destinations = <NavigationDestination>[
          if (showVoiture)
            NavigationDestination(
              icon: const Icon(Icons.directions_car),
              label: isAr ? 'سياراتي' : 'Véhicules',
            ),
          if (showMoto)
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
        ];

        // Filet de sécurité si le nombre d'onglets change (ex: profil
        // modifié depuis l'onglet Profil) pendant qu'un onglet au-delà
        // de la nouvelle liste était sélectionné.
        final safeIndex = _index >= screens.length ? 0 : _index;

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: widget.config.primaryColor,
              foregroundColor: Colors.black,
              toolbarHeight: 96,
              titleSpacing: 0,
              flexibleSpace: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/logo_header.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stack) => Container(
                        color: widget.config.primaryColor,
                        alignment: Alignment.center,
                        child: Text(widget.config.appName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: isAr ? null : 12,
                      left: isAr ? 12 : null,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => widget.isAr.value = !isAr,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Text(
                              isAr ? 'FR' : 'AR',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: IndexedStack(index: safeIndex, children: screens),
            bottomNavigationBar: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../widgets/screen_background.dart';

/// Premier écran vu par l'utilisateur : demande s'il conduit une voiture,
/// une moto/scooter, ou les deux, avant de donner accès au reste de
/// l'app. Le choix pilote quels onglets sont affichés dans HomeScreen
/// (voir SettingsService.vehicleProfile) et peut être changé plus tard
/// depuis l'onglet Profil.
class OnboardingProfileScreen extends StatefulWidget {
  final AppConfig config;
  final ValueNotifier<bool> isAr;
  final ValueChanged<String> onChosen;

  const OnboardingProfileScreen({
    super.key,
    required this.config,
    required this.isAr,
    required this.onChosen,
  });

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isAr,
      builder: (context, isAr, _) {
        String t(String fr, String ar) => isAr ? ar : fr;

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: ScreenBackground(
              category: BackgroundCategory.generique,
              accentColor: widget.config.primaryColor,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: TextButton(
                          onPressed: () => widget.isAr.value = !isAr,
                          child: Text(
                            isAr ? 'FR' : 'AR',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        t('Qu\'est-ce que tu conduis ?', 'ماذا تقود؟'),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'Ça nous permet de n\'afficher que ce qui te '
                          'concerne. Tu pourras changer ça plus tard dans '
                          'Profil.',
                          'هذا يسمح لنا بعرض ما يهمك فقط. يمكنك تغيير هذا '
                          'لاحقاً من الملف الشخصي.',
                        ),
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 32),
                      _ProfileOption(
                        icon: Icons.directions_car,
                        label: t('Voiture', 'سيارة'),
                        selected: _selected == 'voiture',
                        accentColor: widget.config.primaryColor,
                        onTap: () => setState(() => _selected = 'voiture'),
                      ),
                      const SizedBox(height: 12),
                      _ProfileOption(
                        icon: Icons.two_wheeler,
                        label: t('Moto / Scooter', 'دراجة نارية / سكوتر'),
                        selected: _selected == 'moto',
                        accentColor: widget.config.primaryColor,
                        onTap: () => setState(() => _selected = 'moto'),
                      ),
                      const SizedBox(height: 12),
                      _ProfileOption(
                        icon: Icons.sync_alt,
                        label: t('Les deux', 'كلاهما'),
                        selected: _selected == 'both',
                        accentColor: widget.config.primaryColor,
                        onTap: () => setState(() => _selected = 'both'),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.config.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _selected == null
                              ? null
                              : () => widget.onChosen(_selected!),
                          child: Text(
                            t('Continuer', 'متابعة'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accentColor.withValues(alpha: 0.14) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accentColor : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? accentColor : Colors.black54),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

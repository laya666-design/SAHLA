import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/app_config.dart';
import 'home_screen.dart';
import 'onboarding_profile_screen.dart';
import '../services/vehicule_service.dart';

/// Splash plein écran avec la roue qui tourne (VROUM).
/// Joue la vidéo une fois, puis passe automatiquement à l'app normale.
class SplashScreen extends StatefulWidget {
  final AppConfig config;
  final ValueNotifier<bool> isAr;

  const SplashScreen({
    super.key,
    required this.config,
    required this.isAr,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/video/splash_wheel.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.setLooping(false);
        _controller.setVolume(0); // silencieux
        _controller.play();

        // Dès que la vidéo se termine → on passe à l'app
        _controller.addListener(_onVideoUpdate);
      }).catchError((e) {
        // Si la vidéo échoue, on passe directement à l'app
        _goToApp();
      });

    // Sécurité : on ne reste jamais bloqué plus de 8 secondes
    // (la vidéo VROUM fait ~6 s)
    Future.delayed(const Duration(seconds: 8), _goToApp);
  }

  void _onVideoUpdate() {
    if (_controller.value.position >= _controller.value.duration &&
        !_navigated) {
      _goToApp();
    }
  }

  void _goToApp() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final profileChosen = SettingsService.hasChosenVehicleProfile;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => profileChosen
            ? HomeScreen(config: widget.config, isAr: widget.isAr)
            : OnboardingProfileScreen(
                config: widget.config,
                isAr: widget.isAr,
                onChosen: (value) async {
                  await SettingsService.setVehicleProfile(value);
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            HomeScreen(config: widget.config, isAr: widget.isAr),
                      ),
                    );
                  }
                },
              ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _initialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Color(0xFF00C853)),
            ),
    );
  }
}


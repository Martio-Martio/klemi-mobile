import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'Configuration/app_theme.dart';
import 'Pages/Auth/connexion_page.dart';
import 'Pages/app_shell.dart';
import 'Providers/app_state.dart';

/// Écran de démarrage : charge la session locale puis ouvre l'app native
/// (plus d'ouverture du site web).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    final etat = context.read<AppState>();
    await Future.wait([
      etat.charger(),
      Future.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted) return;
    final Widget suivant = etat.connecte ? const AppShell() : const ConnexionPage();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => suivant,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.beige,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logos/logo_klemi.png', width: 160, height: 160)
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            const Text(
              'Klemi',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.navy,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 6),
            const Text(
              'Apprends dans ta langue',
              style: TextStyle(fontSize: 14, color: AppTheme.texteSecondaire),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

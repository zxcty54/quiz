// Splash screen — the "MT" screen the app opens with.
//
// Ye wahi screen hai jo Android ke launch screen
// (android/app/src/main/res → brand midnight + MT logo) ke baad aati hai:
// same background, same logo, isliye native launch screen se hand-over
// seamless lagta hai. Logo ~1 second dikhta hai aur phir app khul jata hai.
//
// Logo asset: assets/data/icon/launch_logo.png  (ye folder pubspec.yaml me
// pehle se declared hai — `- assets/data/icon/` — isliye pubspec me kuch
// badalne ki zaroorat nahi.)
//
// Timing badalni ho to neeche `_hold` dekho (abhi 900ms).
import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  /// Splash ke baad kaunsi screen khulegi. Default HomeScreen hai; pehli baar
  /// wale user ke liye main.dart isme OnboardingWelcomeScreen pass karta hai.
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    this.nextScreen = const HomeScreen(),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Android launch screen ka colour (values/colors.xml -> launch_background).
  static const Color _bg = Color(0xFF070B14);

  /// MT screen kitni der dikhe.
  static const Duration _hold = Duration(milliseconds: 900);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> entrance =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: <Widget>[
          // Halka brand glow pichhe, taaki screen flat na lage — warna sab kuch
          // wahi rehta hai jo launch screen par tha.
          Positioned.fill(
            child: FadeTransition(
              opacity: entrance,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.04),
                    radius: 0.8,
                    colors: <Color>[Color(0x332563EB), Color(0x00070B14)],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: entrance,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(entrance),
                  child: Image.asset(
                    'assets/data/icon/launch_logo.png',
                    width: 320,
                    fit: BoxFit.scaleDown,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

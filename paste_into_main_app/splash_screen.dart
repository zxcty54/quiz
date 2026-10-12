// Splash screen — the "MT" screen, ready to drop into the main app
// (package:mocktester).
//
// HOW TO USE:
//   1. Replace lib/screens/splash_screen.dart with this file.
//   2. Put the MT logo at assets/data/icon/launch_logo.png in your project
//      (the PNG is downloadable from paste_into_main_app/launch_logo.png).
//      If your pubspec.yaml does not already list `- assets/data/icon/`,
//      add it under flutter: assets: — or change the path in Image.asset
//      below to wherever you keep it.
//   3. In main.dart make the splash the first screen:
//
//        home: isOnboarded
//            ? const SplashScreen()
//            : const SplashScreen(nextScreen: OnboardingWelcomeScreen()),
//
// (OnboardingWelcomeScreen already defaults to HomeScreen, so nothing else
// changes.) home_screen.dart is not touched by this screen.
//
// The screen itself is exactly what the Android launch screen shows -
// android/app/src/main/res paints the same white surface + MT logo - so the
// hand-over is seamless: the logo appears to stay put and then the app opens.
// The wait is the `_hold` constant below (900ms).
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
  static const Color _bg = Color(0xFFFFFFFF);

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

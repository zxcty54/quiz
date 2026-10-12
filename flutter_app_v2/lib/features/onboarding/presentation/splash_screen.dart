// v1 source: flutter_app/lib/screens/splash_screen.dart
//
// Same behaviour (2.5s, then HomeShellScreen) with the v2 brand treatment:
// aurora field, a mark that scales in, an animated progress bar instead of a
// bare spinner, and a footer line so the wait feels intentional.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/theme/app_gradients.dart';
import 'package:mocktester_v2/core/theme/app_tokens.dart';
import 'package:mocktester_v2/core/widgets/aurora_background.dart';
import 'package:mocktester_v2/core/widgets/brand_mark.dart';
import 'package:mocktester_v2/features/shell/presentation/home_shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  Timer? _timer;
  Timer? _auroraTimer;

  /// The aurora fades in only after the native launch screen is gone, so the
  /// hand-over (launch logo on brand midnight -> Flutter splash) reads as one
  /// continuous screen instead of a flash.
  bool _showAurora = false;

  @override
  void initState() {
    super.initState();

    _auroraTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _showAurora = true);
    });

    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auroraTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> entrance =
        CurvedAnimation(parent: _controller, curve: AppMotion.emphasised);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: <Widget>[
          // Solid brand colour first (identical to the Android launch screen),
          // then the aurora fades in underneath the content.
          AnimatedOpacity(
            opacity: _showAurora ? 1 : 0,
            duration: AppMotion.slow,
            curve: AppMotion.entrance,
            child: const Positioned.fill(
              child: AuroraBackground(intensity: 1.25),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: <Widget>[
              const Spacer(flex: 3),
              FadeTransition(
                opacity: entrance,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.86, end: 1).animate(entrance),
                  child: const BrandMark(size: 92, icon: Icons.insights_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: entrance,
                child: const Text(
                  'MockTester',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (Rect bounds) =>
                    AppGradients.study.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'Practice. Analyze. Succeed.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: 168,
                child: ClipRRect(
                  borderRadius: AppRadii.pillAll,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? _) {
                      return LinearProgressIndicator(
                        value: _controller.value,
                        minHeight: 4,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF38BDF8),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'BPSC • BSSC • Bihar Police • All Bihar Exams',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'onboarding_welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  Timer? _timer;
  Timer? _auroraTimer;
  bool _showAurora = false;

  @override
  void initState() {
    super.initState();

    // 400ms baad background aurora glow smoothly fade in hoga
    _auroraTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showAurora = true);
    });

    // 2.5 seconds ke baad check karega user onboarded hai ya naya
    _timer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final bool isOnboarded = prefs.getBool('is_onboarded') ?? false;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => isOnboarded
              ? const HomeScreen()
              : OnboardingWelcomeScreen(nextScreen: const HomeScreen()),
        ),
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
    final Animation<double> entrance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: <Widget>[
          // 🌌 1. Ambient Aurora Background
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showAurora ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              child: const _SelfContainedAurora(),
            ),
          ),

          // 💎 2. Brand Identity & Content
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  const Spacer(flex: 3),

                  // Brand Mark Tile with Glass Shine
                  FadeTransition(
                    opacity: entrance,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.84, end: 1.0).animate(entrance),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.40),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Translucent Glass Overlay
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.22),
                                      Colors.white.withOpacity(0.04),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.insights_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Name
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

                  // Gradient Tagline
                  ShaderMask(
                    shaderCallback: (Rect bounds) => const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'Practice. Analyze. Succeed.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Sleek Linear Progress Bar (Circular Spinner ki jagah)
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
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

                  const SizedBox(height: 16),

                  // Bihar Exam Focus Label
                  Text(
                    'BPSC • BSSC • Bihar Police • All Bihar Exams',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🌌 Self-Contained Aurora Background Animation
class _SelfContainedAurora extends StatefulWidget {
  const _SelfContainedAurora();

  @override
  State<_SelfContainedAurora> createState() => _SelfContainedAuroraState();
}

class _SelfContainedAuroraState extends State<_SelfContainedAurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _auroraCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _auroraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _auroraCtrl,
        builder: (context, _) => CustomPaint(
          painter: _AuroraPainter(progress: _auroraCtrl.value),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  _AuroraPainter({required this.progress});

  static const List<List<double>> _ribbons = [
    [0.20, 0.25, 0.60, 0.0],
    [0.85, 0.20, 0.50, 0.35],
    [0.60, 0.75, 0.65, 0.70],
  ];

  static const List<Color> _colors = [
    Color(0xFF1D4ED8),
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;

    for (int i = 0; i < _ribbons.length; i++) {
      final r = _ribbons[i];
      final phase = (progress + r[3]) * 2 * math.pi;
      final dx = math.sin(phase) * size.width * 0.08;
      final dy = math.cos(phase * 0.8) * size.height * 0.06;
      final center = Offset(size.width * r[0] + dx, size.height * r[1] + dy);
      final radius = size.shortestSide * r[2];

      paint.shader = RadialGradient(
        colors: [
          _colors[i].withOpacity(0.35),
          _colors[i].withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }

    // Subtle dark vignette for clear contrast
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF070B14).withOpacity(0.60),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

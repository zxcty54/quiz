// Splash screen - MockTester v2 design, ready to drop into the main app
// (package:mocktester).
//
// HOW TO USE: replace lib/screens/splash_screen.dart with this file, then in
// main.dart make the splash the first screen:
//
//   home: isOnboarded
//       ? const SplashScreen()                       // returning user
//       : const SplashScreen(nextScreen: OnboardingWelcomeScreen()),
//
// (OnboardingWelcomeScreen already defaults to HomeScreen, so nothing else
// changes.) home_screen.dart does NOT have to be touched for this screen.
//
// Same behaviour as before - wait, then open the next screen - with the v2
// brand treatment: aurora field, a mark that scales in, an animated progress
// bar instead of a bare spinner, and a footer line so the wait feels
// intentional. The wait is the `_timer` line below; lower it if you want it
// shorter (e.g. Duration(milliseconds: 1200)).
//
// Everything it needs is inside this file (tokens, background, logo mark); no
// new package is required.
import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  /// Where the splash hands over after its timer. Defaults to the home screen,
  /// so `home: const SplashScreen()` is all main.dart needs; pass
  /// `SplashScreen(nextScreen: OnboardingWelcomeScreen())` to show it to a
  /// first-time user as well.
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => widget.nextScreen),
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
        CurvedAnimation(parent: _controller, curve: _M.emphasised);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: _Aurora(
        intensity: 1.25,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Spacer(flex: 3),
              FadeTransition(
                opacity: entrance,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.86, end: 1).animate(entrance),
                  child: const _Mark(size: 92, icon: Icons.insights_rounded),
                ),
              ),
              const SizedBox(height: _S.xl),
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
                    _G.study.createShader(bounds),
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
                  borderRadius: _R.pillAll,
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
              const SizedBox(height: _S.md),
              Text(
                'BPSC • BSSC • Bihar Police • All Bihar Exams',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: _S.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Inlined pieces of the v2 design system (copied from core/theme/* and
// core/widgets/* so this file works on its own).
// =============================================================================

/// 4-point spacing scale.
class _S {
  _S._();
  static const double md = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radii scale.
class _R {
  _R._();
  static BorderRadius get pillAll => BorderRadius.circular(999);
}

/// Motion tokens.
class _M {
  _M._();
  static const Curve emphasised = Curves.easeOutQuart;
}

/// Coloured glow used behind the brand mark.
class _E {
  _E._();
  static List<BoxShadow> glow(Color color, {double opacity = 0.34}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Gradients used by this screen.
class _G {
  _G._();

  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandIndigo = Color(0xFF4F46E5);

  /// Primary brand sweep.
  static const LinearGradient brand = LinearGradient(
    colors: <Color>[brandBlue, brandIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cyan - blue: the "study" gradient (tagline + accents).
  static const LinearGradient study = LinearGradient(
    colors: <Color>[Color(0xFF0EA5E9), brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark hero gradient behind the aurora field.
  static const LinearGradient midnight = LinearGradient(
    colors: <Color>[_onboardingBg, Color(0xFF101A33)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Aurora ribbon colours used by the animated background painter.
  static const List<Color> aurora = <Color>[
    Color(0xFF1D4ED8),
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
  ];

  /// A translucent white glass overlay (used on top of gradient surfaces).
  static final LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Colors.white.withOpacity(0.22),
      Colors.white.withOpacity(0.04),
    ],
  );
}

const Color _onboardingBg = Color(0xFF070B14);

/// Animated aurora background: three brand-coloured ribbons drift on
/// independent sine phases, masked by a soft vignette so text stays readable.
class _Aurora extends StatefulWidget {
  const _Aurora({this.child, this.intensity = 1.0});

  final Widget? child;

  /// 0 -> flat, 1 -> default glow, values above 1 are for the splash.
  final double intensity;

  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _G.midnight),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) => CustomPaint(
                  painter: _AuroraPainter(
                    progress: _controller.value,
                    intensity: widget.intensity,
                  ),
                ),
              ),
            ),
          ),
          if (widget.child != null) Positioned.fill(child: widget.child!),
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.progress, required this.intensity});

  /// 0..1 ticking value; every ribbon derives its own phase from it.
  final double progress;
  final double intensity;

  /// Ribbon definitions: normalised position, radius factor and phase offset.
  static const List<List<double>> _ribbons = <List<double>>[
    <double>[0.18, 0.22, 0.62, 0.0], // x, y, radius factor, phase
    <double>[0.86, 0.14, 0.48, 0.33],
    <double>[0.62, 0.78, 0.70, 0.66],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..blendMode = BlendMode.plus;

    for (int i = 0; i < _ribbons.length; i++) {
      final List<double> r = _ribbons[i];
      final double phase = (progress + r[3]) * 2 * math.pi;
      final double dx = math.sin(phase) * size.width * 0.07;
      final double dy = math.cos(phase * 0.8) * size.height * 0.05;
      final Offset center =
          Offset(size.width * r[0] + dx, size.height * r[1] + dy);
      final double radius = size.shortestSide * r[2];

      final Color color = _G.aurora[i % _G.aurora.length];
      paint.shader = RadialGradient(
        colors: <Color>[
          color.withOpacity(0.34 * intensity),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }

    // Vignette: keeps the corners close to the base colour so any text placed
    // over the field keeps its contrast.
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.transparent,
          _onboardingBg.withOpacity(0.55),
        ],
        stops: const <double>[0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Faint grain lines: gives the flat gradient some texture.
    final Paint grid = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 1;
    const double step = 46;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}

/// The MockTester logo mark: a gradient tile with the chart glyph.
class _Mark extends StatelessWidget {
  const _Mark({
    this.size = 56,
    this.icon = Icons.insights_rounded,
    this.radius,
    this.showGlow = true,
    this.gradient = _G.brand,
  });

  final double size;
  final IconData icon;
  final double? radius;
  final bool showGlow;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final double r = radius ?? size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(r),
        boxShadow: showGlow ? _E.glow(const Color(0xFF2563EB)) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Glass highlight so the tile does not read as flat paint.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _G.glass,
                borderRadius: BorderRadius.circular(r),
              ),
            ),
          ),
          Icon(icon, color: Colors.white, size: size * 0.48),
        ],
      ),
    );
  }
}

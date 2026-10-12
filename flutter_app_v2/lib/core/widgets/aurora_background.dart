import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/constants/app_colors.dart';
import 'package:mocktester_v2/core/theme/app_gradients.dart';

/// Animated aurora background used by the onboarding and splash screens.
///
/// v1 had a `_BackgroundPainter` with a handful of static circles plus a
/// `floatController`. This one keeps the same idea but:
///  * three brand-coloured ribbons drift on independent sine phases,
///  * the whole field is masked by a soft vignette so text stays readable,
///  * the painter is `shouldRepaint`-aware and only rebuilds on the ticker.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    this.child,
    this.intensity = 1.0,
    this.blur = 90,
    this.animate = true,
  });

  final Widget? child;

  /// 0 → flat, 1 → default glow, values above 1 are mostly for the splash.
  final double intensity;

  /// Blur radius of the ribbons. Large values are cheap: they are shaders.
  final double blur;

  /// Set to false to freeze the field (used by golden-ish tests).
  final bool animate;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.midnight),
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
                    blur: widget.blur,
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
  _AuroraPainter({
    required this.progress,
    required this.intensity,
    required this.blur,
  });

  /// 0..1 ticking value; every ribbon derives its own phase from it.
  final double progress;
  final double intensity;
  final double blur;

  /// Ribbon definitions: normalised position, size and phase offset.
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
      final Offset center = Offset(size.width * r[0] + dx, size.height * r[1] + dy);
      final double radius = size.shortestSide * r[2];

      final Color color = AppGradients.aurora[i % AppGradients.aurora.length];
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
          AppColors.onboardingBg.withOpacity(0.55),
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
      oldDelegate.progress != progress ||
      oldDelegate.intensity != intensity ||
      oldDelegate.blur != blur;
}

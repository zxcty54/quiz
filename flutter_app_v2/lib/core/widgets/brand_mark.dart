import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/theme/app_gradients.dart';
import 'package:mocktester_v2/core/theme/app_tokens.dart';

/// The MockTester logo mark: a gradient tile with the chart glyph.
///
/// v1 drew this with a `Container` + `Icon` in three different places (splash,
/// onboarding, drawer) with three different radii. One widget now, so the mark
/// is identical everywhere and can be animated or scaled from one parameter.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 56,
    this.icon = Icons.insights_rounded,
    this.radius,
    this.showGlow = true,
    this.gradient = AppGradients.brand,
  });

  final double size;
  final IconData icon;
  final double? radius;
  final bool showGlow;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius ?? size * 0.30),
        boxShadow: showGlow ? AppElevation.glow(const Color(0xFF2563EB)) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Glass highlight so the tile does not read as flat paint.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.glass,
                borderRadius: BorderRadius.circular(radius ?? size * 0.30),
              ),
            ),
          ),
          Icon(icon, color: Colors.white, size: size * 0.48),
        ],
      ),
    );
  }
}

/// "MOCKTESTER" wordmark with the optional glowing dot.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.fontSize = 12,
    this.color = Colors.white,
    this.letterSpacing = 2.6,
    this.showDot = true,
    this.dotColor = const Color(0xFF38BDF8),
  });

  final double fontSize;
  final Color color;
  final double letterSpacing;
  final bool showDot;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showDot) ...<Widget>[
          Container(
            width: fontSize * 0.55,
            height: fontSize * 0.55,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: dotColor.withOpacity(0.85),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          SizedBox(width: fontSize * 0.65),
        ],
        Text(
          'MOCKTESTER',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
          ),
        ),
      ],
    );
  }
}

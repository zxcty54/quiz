import 'package:flutter/material.dart';

/// Pre-drawn cartoon avatar — photo upload nahi hai.
/// [seed] (aam taur par student ka naam) se har user ka ek fixed avatar banta
/// hai: same seed = hamesha wahi avatar, app me har jagah ek jaisa.
/// Community feed wala hi painter hai, taaki pure app ke avatar ek style ke hon.
class CartoonAvatar extends StatelessWidget {
  final String seed;
  final double size;
  final bool verified;

  const CartoonAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return ClipOval(
      child: CustomPaint(
        size: Size(size, size),
        painter: CartoonAvatarPainter(seedHash: hash, verified: verified),
      ),
    );
  }
}

class CartoonAvatarPainter extends CustomPainter {
  final int seedHash;
  final bool verified;

  const CartoonAvatarPainter({required this.seedHash, required this.verified});

  static const List<Color> _backgrounds = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF4F46E5),
    Color(0xFF9333EA),
  ];

  static const List<Color> _skinTones = [
    Color(0xFFFFD7B0),
    Color(0xFFF2B98A),
    Color(0xFFD98E5F),
    Color(0xFFB96F3E),
    Color(0xFF8D4F2A),
  ];

  static const List<Color> _hairColors = [
    Color(0xFF1F2937),
    Color(0xFF3B2314),
    Color(0xFF5B3427),
    Color(0xFF111827),
    Color(0xFF6B3A1F),
  ];

  static const List<Color> _shirtColors = [
    Color(0xFF0EA5E9),
    Color(0xFF22C55E),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
  ];

  void _circle(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.48;
      final angle = -1.5708 + i * 0.6283;
      final point = Offset(
        center.dx + r * (i == 0 ? 0 : _cos(angle)),
        center.dy + r * (i == 0 ? -1 : _sin(angle)),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  double _sin(double x) {
    // Tiny helper so the avatar stays dependency-free at this size.
    x = x % 6.28318530718;
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  double _cos(double x) => _sin(x + 1.57079632679);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final hash = seedHash.abs();

    final bgA = verified ? const Color(0xFF2563EB) : _backgrounds[hash % _backgrounds.length];
    final bgB = verified ? const Color(0xFF06B6D4) : _backgrounds[(hash + 3) % _backgrounds.length];
    final skin = _skinTones[(hash ~/ 11) % _skinTones.length];
    final hair = _hairColors[(hash ~/ 17) % _hairColors.length];
    final shirt = _shirtColors[(hash ~/ 23) % _shirtColors.length];
    final hairStyle = hash % 5;
    final accessory = (hash ~/ 7) % 4;

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [bgA, bgB],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Soft background bubbles — har avatar ka pattern thoda alag.
    _circle(canvas, Offset(w * (0.16 + (hash % 3) * 0.05), h * 0.18), w * 0.13, Colors.white.withValues(alpha: 0.13));
    _circle(canvas, Offset(w * 0.86, h * (0.24 + (hash % 2) * 0.08)), w * 0.09, Colors.white.withValues(alpha: 0.12));
    _circle(canvas, Offset(w * 0.78, h * 0.82), w * 0.16, Colors.white.withValues(alpha: 0.08));

    final cx = w * 0.50;
    final headCenter = Offset(cx, h * 0.43);
    final headR = w * 0.255;

    // Body / shirt.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 1.03), width: w * 0.74, height: h * 0.52),
      Paint()..color = shirt,
    );
    // Collar.
    final collar = Path()
      ..moveTo(cx - w * 0.075, h * 0.79)
      ..lineTo(cx, h * 0.88)
      ..lineTo(cx + w * 0.075, h * 0.79)
      ..lineTo(cx + w * 0.045, h * 0.755)
      ..lineTo(cx - w * 0.045, h * 0.755)
      ..close();
    canvas.drawPath(collar, Paint()..color = Colors.white.withValues(alpha: 0.92));

    // Neck + ears + face.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, h * 0.665), width: w * 0.15, height: h * 0.17),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = skin.withValues(alpha: 0.92),
    );
    _circle(canvas, Offset(cx - headR * 0.98, headCenter.dy + h * 0.015), w * 0.055, skin);
    _circle(canvas, Offset(cx + headR * 0.98, headCenter.dy + h * 0.015), w * 0.055, skin);
    _circle(canvas, headCenter, headR, skin);

    // Hair / creator cap.
    if (verified) {
      final cap = Path()
        ..moveTo(cx - w * 0.34, h * 0.285)
        ..lineTo(cx, h * 0.155)
        ..lineTo(cx + w * 0.34, h * 0.285)
        ..lineTo(cx, h * 0.385)
        ..close();
      canvas.drawPath(cap, Paint()..color = const Color(0xFF172554));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, h * 0.315), width: w * 0.34, height: h * 0.085),
          Radius.circular(w * 0.035),
        ),
        Paint()..color = const Color(0xFF1E3A8A),
      );
      final tassel = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx + w * 0.315, h * 0.275), Offset(cx + w * 0.315, h * 0.43), tassel);
      _circle(canvas, Offset(cx + w * 0.315, h * 0.455), w * 0.045, const Color(0xFFF59E0B));
    } else if (hairStyle == 0) {
      final path = Path()
        ..moveTo(cx - headR, headCenter.dy - headR * 0.08)
        ..arcTo(Rect.fromCircle(center: headCenter, radius: headR), 3.14159, 3.14159, false)
        ..close();
      canvas.drawPath(path, Paint()..color = hair);
    } else if (hairStyle == 1) {
      for (var i = 0; i < 5; i++) {
        _circle(
          canvas,
          Offset(cx - headR * 0.72 + i * headR * 0.36, headCenter.dy - headR * 0.78),
          headR * 0.34,
          hair,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, headCenter.dy - headR * 0.62), width: headR * 1.55, height: headR * 0.42),
          Radius.circular(headR * 0.18),
        ),
        Paint()..color = hair,
      );
    } else if (hairStyle == 2) {
      canvas.save();
      canvas.translate(cx - w * 0.02, headCenter.dy - headR * 0.72);
      canvas.rotate(-0.32);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: headR * 1.75, height: headR * 0.72),
        Paint()..color = hair,
      );
      canvas.restore();
    } else if (hairStyle == 3) {
      _circle(canvas, Offset(cx, headCenter.dy - headR * 1.03), headR * 0.34, hair);
      final path = Path()
        ..moveTo(cx - headR, headCenter.dy - headR * 0.05)
        ..arcTo(Rect.fromCircle(center: headCenter, radius: headR), 3.14159, 3.14159, false)
        ..close();
      canvas.drawPath(path, Paint()..color = hair);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - headR * 1.02, headCenter.dy - headR * 0.42, headR * 0.24, headR * 1.28),
          Radius.circular(headR * 0.12),
        ),
        Paint()..color = hair,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + headR * 0.78, headCenter.dy - headR * 0.42, headR * 0.24, headR * 1.28),
          Radius.circular(headR * 0.12),
        ),
        Paint()..color = hair,
      );
      final path = Path()
        ..moveTo(cx - headR, headCenter.dy - headR * 0.08)
        ..arcTo(Rect.fromCircle(center: headCenter, radius: headR), 3.14159, 3.14159, false)
        ..close();
      canvas.drawPath(path, Paint()..color = hair);
    }

    // Face.
    final eyePaint = Paint()..color = const Color(0xFF1F2937);
    _circle(canvas, Offset(cx - headR * 0.36, headCenter.dy + headR * 0.10), w * 0.032, eyePaint.color);
    _circle(canvas, Offset(cx + headR * 0.36, headCenter.dy + headR * 0.10), w * 0.032, eyePaint.color);
    _circle(canvas, Offset(cx - headR * 0.62, headCenter.dy + headR * 0.40), w * 0.045, const Color(0xFFF472B6).withValues(alpha: 0.38));
    _circle(canvas, Offset(cx + headR * 0.62, headCenter.dy + headR * 0.40), w * 0.045, const Color(0xFFF472B6).withValues(alpha: 0.38));
    final smilePaint = Paint()
      ..color = const Color(0xFF7C2D12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, headCenter.dy + headR * 0.33), width: headR * 0.78, height: headR * 0.52),
      0.45,
      2.25,
      false,
      smilePaint,
    );

    // Accessories.
    if (accessory == 0) {
      final glassPaint = Paint()
        ..color = const Color(0xFF111827).withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.032;
      canvas.drawCircle(Offset(cx - headR * 0.37, headCenter.dy + headR * 0.10), headR * 0.25, glassPaint);
      canvas.drawCircle(Offset(cx + headR * 0.37, headCenter.dy + headR * 0.10), headR * 0.25, glassPaint);
      canvas.drawLine(
        Offset(cx - headR * 0.12, headCenter.dy + headR * 0.10),
        Offset(cx + headR * 0.12, headCenter.dy + headR * 0.10),
        glassPaint,
      );
    } else if (accessory == 1 && !verified) {
      final bandPaint = Paint()
        ..color = const Color(0xFF111827)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headR * 1.08),
        3.35,
        2.65,
        false,
        bandPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - headR * 1.02, headCenter.dy + headR * 0.18), width: w * 0.075, height: h * 0.16),
          Radius.circular(w * 0.03),
        ),
        Paint()..color = const Color(0xFF111827),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + headR * 1.02, headCenter.dy + headR * 0.18), width: w * 0.075, height: h * 0.16),
          Radius.circular(w * 0.03),
        ),
        Paint()..color = const Color(0xFF111827),
      );
    } else if (accessory == 2) {
      _drawStar(canvas, Offset(cx + w * 0.245, h * 0.78), w * 0.072, const Color(0xFFFBBF24));
    } else {
      _drawStar(canvas, Offset(cx - w * 0.285, h * 0.19), w * 0.045, Colors.white.withValues(alpha: 0.85));
      _drawStar(canvas, Offset(cx + w * 0.295, h * 0.13), w * 0.032, Colors.white.withValues(alpha: 0.65));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CartoonAvatarPainter oldDelegate) {
    return oldDelegate.seedHash != seedHash || oldDelegate.verified != verified;
  }
}

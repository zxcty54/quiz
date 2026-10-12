// v1 source: flutter_app/lib/widgets/trust_hero_banner.dart
// 🌈 TrustHeroBannerWidget (Aurora Glass with Bento Stats & Motivation)
import 'package:flutter/material.dart';

class TrustHeroBannerWidget extends StatelessWidget {
  final bool isDarkMode;

  const TrustHeroBannerWidget({
    super.key,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Top Aurora Gradient Line
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFFF97316)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Pills Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: Color(0xFF38BDF8)),
                            SizedBox(width: 5),
                            Text(
                              'STUDENT-FIRST INITIATIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: const Text(
                          'BPSC • BSSC • SSC • Railway',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mehnga Subscription Kyun?',
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Padhai Pe Sabka Haq Hai! 🎓',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frosted Bento Stats
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    // Each stat is Expanded: without it the three columns keep
                    // their intrinsic width and the Row overflows on narrow
                    // phones (and in any scaled font).
                    child: const Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            value: '₹0',
                            label: 'Always Free',
                            valueColor: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: _HeroStat(
                            value: '3,000+',
                            label: 'TCS PYQs',
                            valueColor: Color(0xFFFBBF24),
                          ),
                        ),
                        Expanded(
                          child: _HeroStat(
                            value: '100%',
                            label: 'CBT Pattern',
                            valueColor: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Motivational Quote Block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"Paise ki kami ab sapno ke aage nahi aayegi. Mehnat aapki, har ek resource hamara."',
                            style: TextStyle(
                              color: Color(0xFFFEF08A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One column of the frosted bento strip: a big number and a small label,
/// both allowed to shrink so the row can never overflow.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

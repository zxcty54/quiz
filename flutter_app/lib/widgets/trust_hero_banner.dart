import 'package:flutter/material.dart';

class TrustHeroBannerWidget extends StatelessWidget {
  final bool isDarkMode;
  const TrustHeroBannerWidget({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF131B2F), const Color(0xFF0B1120)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0453CD).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 🌈 Top Glowing Gradient Accent Strip
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3.5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF356EE7), Color(0xFFFF4D00)],
                  ),
                ),
              ),
            ),

            // 📄 Main Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF356EE7).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF356EE7).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 13, color: Color(0xFF74F5FF)),
                            SizedBox(width: 5),
                            Text(
                              'STUDENT-FIRST INITIATIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BPSC • BSSC • SSC',
                          style: TextStyle(
                            color: Color(0xFFC4C6CE),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Main Heading
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Mehnga Subscription Kyun?\n',
                          style: TextStyle(
                            color: Color(0xFFDCE2F3),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                        TextSpan(
                          text: 'Padhai Pe Sabka Haq Hai! 🎓',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Value Proposition Pill Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF22C55E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '100% Free & Latest CBT Pattern Exam Mocks',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
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

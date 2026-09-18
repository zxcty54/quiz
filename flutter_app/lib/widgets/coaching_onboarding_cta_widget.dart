import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/creator_auth_screen.dart';
import '../screens/creator_dashboard_screen.dart';

class CoachingOnboardingCtaWidget extends StatelessWidget {
  final bool isDarkMode;

  const CoachingOnboardingCtaWidget({super.key, required this.isDarkMode});

  Future<void> _handleDirectOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHandle = prefs.getString('logged_in_creator_handle');

    if (!context.mounted) return;

    if (savedHandle != null && savedHandle.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatorDashboardScreen(
            creatorHandle: savedHandle,
            isDarkMode: isDarkMode,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatorAuthScreen(isDarkMode: isDarkMode),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode;

    return Container(
      width: double.infinity, // 👈 Pura space lega
      margin: EdgeInsets.zero, // 👈 Horizontal margin 0 kiya taaki 1v1 Challenge card jitna wide ho sake
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF1F5F9),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFCBD5E1).withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFF1E293B).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background Watermark Icon
            Positioned(
              right: -15,
              bottom: -20,
              child: Icon(
                Icons.school_rounded,
                size: 130,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFF2563EB).withValues(alpha: 0.04),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Pill Badge & Emoji Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Text(
                          'INSTITUTE & TEACHERS',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🏫', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Heading & Subtitle
                  Text(
                    'Apna Coaching Digital Banayein',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Private batch tests lijiye, mocks host karein aur rank list generate kijiye.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feature Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniFeatureBadge(
                          icon: Icons.quiz_outlined,
                          title: 'Mock Maker',
                          sub: 'Custom Tests',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMiniFeatureBadge(
                          icon: Icons.insights_rounded,
                          title: 'Analytics',
                          sub: 'Live Results',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Launch Digital Classroom CTA Button
                  InkWell(
                    onTap: () => _handleDirectOnboarding(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_business_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Launch Digital Classroom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ],
                      ),
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

  Widget _buildMiniFeatureBadge({
    required IconData icon,
    required String title,
    required String sub,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

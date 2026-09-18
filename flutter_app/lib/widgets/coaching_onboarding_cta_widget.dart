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

    // 1. Agar teacher pehle se logged in hai -> Direct Studio Dashboard
    if (savedHandle != null && savedHandle.isNotEmpty && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatorDashboardScreen(
            creatorHandle: savedHandle,
            isDarkMode: isDarkMode,
          ),
        ),
      );
      return;
    }

    // 2. Naya coaching hai -> Direct CreatorAuthScreen open karega (Telegram approval flow)
    if (context.mounted) {
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
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🏫', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you a teacher or coaching institute?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create your free digital classroom.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Feature Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem('Create Mock Tests', isDarkMode),
                    const SizedBox(height: 6),
                    _buildFeatureItem('Private Batch Tests', isDarkMode),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem('Publish Notes', isDarkMode),
                    const SizedBox(height: 6),
                    _buildFeatureItem('Student Performance Analytics', isDarkMode),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // CTA Action Button -> Opens CreatorAuthScreen
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _handleDirectOnboarding(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Coaching →',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

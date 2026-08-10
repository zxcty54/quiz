import 'package:flutter/material.dart';

class LaunchRoadmapCardWidget extends StatelessWidget {
  final Map<String, dynamic> appConfig;
  final bool isDarkMode;

  const LaunchRoadmapCardWidget({
    super.key,
    required this.appConfig,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final List roadmapList = appConfig['launch_roadmap'] ?? [
      {"text": "🔥 Coming Tomorrow: BSSC Inter Level Top 100 Qs", "color": "0xFFFF4757"},
      {"text": "✅ Just Added: Current Affairs Bulletin 2026", "color": "0xFF059669"},
      {"text": "📌 Next Week: BPSC Mains Answer Writing Practice", "color": "0xFF2563EB"}
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rocket_launch_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Text(
                'Launch Roadmap & Live Updates',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...roadmapList.map((item) {
            final String text = item['text'] ?? '';
            Color textColor = const Color(0xFF2563EB);
            try {
              if (item['color'] != null) textColor = Color(int.parse(item['color']));
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF0F172A).withOpacity(0.5)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: textColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

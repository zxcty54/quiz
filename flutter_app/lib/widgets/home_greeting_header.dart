import 'package:flutter/material.dart';

import '../services/user_stats_service.dart';

/// Home ke sabse upar ka personalized header.
///
/// MockTester ke signature Royal Blue theme ke saath match kiya gaya.
class HomeGreetingHeader extends StatefulWidget {
  final bool isDarkMode;
  final int reloadToken;

  const HomeGreetingHeader({
    super.key,
    required this.isDarkMode,
    this.reloadToken = 0,
  });

  @override
  State<HomeGreetingHeader> createState() => _HomeGreetingHeaderState();
}

class _HomeGreetingHeaderState extends State<HomeGreetingHeader> {
  static const int _dailyGoal = 30;

  late Future<_HeaderData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void didUpdateWidget(HomeGreetingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      setState(() => _dataFuture = _load());
    }
  }

  Future<_HeaderData> _load() async {
    final stats = await UserStatsService.getStats();
    Map<String, dynamic> subjects = {};
    try {
      subjects = await UserStatsService.getSubjectAnalytics();
    } catch (_) {}

    String? weakSubject;
    int? weakAccuracy;
    subjects.forEach((name, value) {
      if (value is Map) {
        final total = (value['total'] as num?)?.toInt() ?? 0;
        final acc = (value['accuracy'] as num?)?.toInt();
        if (total >= 5 && acc != null) {
          if (weakAccuracy == null || acc < weakAccuracy!) {
            weakAccuracy = acc;
            weakSubject = name;
          }
        }
      }
    });

    final weekly = (stats['weekly_progress'] as List?) ?? const [];
    final todayQuestions = weekly.isNotEmpty
        ? (weekly.last as num?)?.toInt() ?? 0
        : 0;

    return _HeaderData(
      name: (stats['student_name'] ?? 'Aspirant').toString(),
      streak: (stats['streak'] as num?)?.toInt() ?? 0,
      totalQuestions: (stats['questions'] as num?)?.toInt() ?? 0,
      accuracy: (stats['accuracy'] as num?)?.toInt() ?? 0,
      mocks: (stats['mocks'] as num?)?.toInt() ?? 0,
      todayQuestions: todayQuestions,
      weakSubject: weakSubject,
      weakAccuracy: weakAccuracy,
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData get _greetingIcon {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_sunny_rounded;
    if (h < 17) return Icons.light_mode_rounded;
    return Icons.nights_stay_rounded;
  }

  String get _todayLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // 💙 SIGNATURE ROYAL BLUE GRADIENT
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)]
              : const [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.12 : 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(isDark ? 0.35 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              right: -30,
              top: -35,
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 48,
              top: 18,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 8),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 10,
              child: Icon(
                Icons.school_rounded,
                size: 82,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: FutureBuilder<_HeaderData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  final d = snapshot.data ??
                      const _HeaderData(
                        name: 'Aspirant',
                        streak: 0,
                        totalQuestions: 0,
                        accuracy: 0,
                        mocks: 0,
                        todayQuestions: 0,
                      );

                  final initials = d.name.trim().isEmpty
                      ? 'A'
                      : d.name
                          .trim()
                          .split(RegExp(r'\s+'))
                          .take(2)
                          .map((w) => w[0])
                          .join()
                          .toUpperCase();

                  final goalProgress =
                      (d.todayQuestions / _dailyGoal).clamp(0.0, 1.0).toDouble();
                  final isNewUser = d.totalQuestions == 0;
                  final goalDone = d.todayQuestions >= _dailyGoal;
                  final motivation = isNewUser
                      ? 'Aaj pehla kadam lo — ek chhota mock, phir dekho progress.'
                      : goalDone
                          ? 'Aaj ka goal pura! Ek extra revision aur selection pakka.'
                          : d.weakSubject != null
                              ? 'Aaj ${d.weakSubject} par focus — kamzor topic hi rank banayega.'
                              : 'Thoda sa roz, bada result pakka. Aaj ki practice shuru karo.';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: User Avatar, Greeting & Streak
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_greetingIcon, size: 13, color: const Color(0xFFFDE68A)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$_greeting  •  $_todayLabel',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.25,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Namaste, ${d.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                    shadows: [
                                      Shadow(color: Color(0x35000000), blurRadius: 6, offset: Offset(0, 2)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (d.streak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, size: 15, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${d.streak} din',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Middle: Mission & Progress Circular Indicator
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                                  ),
                                  child: Text(
                                    isNewUser ? 'START TODAY' : goalDone ? 'GOAL COMPLETE' : "TODAY'S MISSION",
                                    style: const TextStyle(
                                      color: Color(0xFFFDE68A),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  motivation,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${d.todayQuestions}/$_dailyGoal sawal aaj',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.80),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: CircularProgressIndicator(
                                    value: goalProgress,
                                    strokeWidth: 5.5,
                                    backgroundColor: Colors.white.withOpacity(0.20),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(goalProgress * 100).round()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'GOAL',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bottom: Stats Metric Badges
                      Row(
                        children: [
                          _stat(Icons.help_outline_rounded, '${d.totalQuestions}', 'Questions', const Color(0xFF60A5FA)),
                          const SizedBox(width: 8),
                          _stat(
                            Icons.track_changes_rounded,
                            isNewUser ? '—' : '${d.accuracy}%',
                            'Accuracy',
                            const Color(0xFF34D399),
                          ),
                          const SizedBox(width: 8),
                          _stat(Icons.quiz_outlined, '${d.mocks}', 'Mocks', const Color(0xFFFBBF24)),
                        ],
                      ),

                      // Weak Subject Focus
                      if (d.weakSubject != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFFFCA5A5)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Focus: ${d.weakSubject} (${d.weakAccuracy}% accuracy) — aaj ispar practice karo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: accent),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderData {
  final String name;
  final int streak;
  final int totalQuestions;
  final int accuracy;
  final int mocks;
  final int todayQuestions;
  final String? weakSubject;
  final int? weakAccuracy;

  const _HeaderData({
    required this.name,
    required this.streak,
    required this.totalQuestions,
    required this.accuracy,
    required this.mocks,
    required this.todayQuestions,
    this.weakSubject,
    this.weakAccuracy,
  });
}

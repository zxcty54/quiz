import 'package:flutter/material.dart';

import '../services/user_stats_service.dart';

/// Home ke sabse upar ka personalized header.
///
/// Naam ke saath greeting, aaj ka goal, streak aur kamzor subject dikhata hai.
/// आंकड़े UserStatsService (local stats) se aate hain. Naye user ke liye
/// jhooti "100% accuracy" nahi dikhti — wahan pehla kadam dikhta hai.
class HomeGreetingHeader extends StatefulWidget {
  final bool isDarkMode;

  /// Parent jab is number ko badhaye (jaise pull-to-refresh par),
  /// greeting apne aankde dobara load karti hai — app restart ki
  /// zaroorat nahi padti.
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
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final title = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
              : d.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
          final goalProgress =
              (d.todayQuestions / _dailyGoal).clamp(0.0, 1.0).toDouble();
          final isNewUser = d.totalQuestions == 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: const Color(0xFF2563EB),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting, ${d.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: title,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(_greetingIcon, size: 13, color: muted),
                            const SizedBox(width: 4),
                            Text(
                              _todayLabel,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (d.streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            '${d.streak} din',
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Aaj ka goal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNewUser ? 'Aaj ka pehla kadam' : 'Aaj ka goal',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${d.todayQuestions}/$_dailyGoal sawal',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goalProgress,
                  minHeight: 7,
                  backgroundColor:
                      isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 14),

              // Chhote aankde
              Row(
                children: [
                  _stat(context, Icons.help_outline_rounded, '${d.totalQuestions}', 'Questions', isDark),
                  const SizedBox(width: 8),
                  _stat(
                    context,
                    Icons.track_changes_rounded,
                    isNewUser ? '—' : '${d.accuracy}%',
                    'Accuracy',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _stat(context, Icons.quiz_outlined, '${d.mocks}', 'Mocks', isDark),
                ],
              ),

              if (d.weakSubject != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 15, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kamzor topic: ${d.weakSubject} (${d.weakAccuracy}% accuracy) — aaj isi par practice karo',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
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

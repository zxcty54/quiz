import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/services/stats/user_stats_service.dart';
import 'package:mocktester_v2/core/theme/app_gradients.dart';
import 'package:mocktester_v2/core/theme/app_tokens.dart';
import 'package:mocktester_v2/core/widgets/brand_mark.dart';

/// The first thing a student sees on Home.
///
/// v1's home tab opened straight into the ticker + trust banner, so the app
/// never acknowledged the user it just onboarded and never showed the numbers
/// that make practice feel like progress. This header greets them by name,
/// shows the (already recorded) streak / questions / accuracy, and puts two
/// real actions - Learn Hub and the daily challenge - one tap away.
///
/// It only reads data that already existed in `UserStatsService`; nothing new
/// is recorded here.
class HomeGreetingHeader extends StatefulWidget {
  const HomeGreetingHeader({
    super.key,
    required this.isDarkMode,
    required this.onTapLearn,
    required this.onStartChallenge,
    this.challengeLoading = false,
    this.reloadToken = 0,
  });

  final bool isDarkMode;

  /// Bump this from the parent (pull-to-refresh) to re-read the stats.
  final int reloadToken;
  final VoidCallback onTapLearn;
  final VoidCallback onStartChallenge;
  final bool challengeLoading;

  @override
  State<HomeGreetingHeader> createState() => _HomeGreetingHeaderState();
}

class _HomeGreetingHeaderState extends State<HomeGreetingHeader> {
  /// Resolved once per screen instead of per rebuild: `getStats()` also rolls
  /// the study-streak forward, and that must not run on every frame.
  late Future<Map<String, dynamic>> _stats = UserStatsService.getStats();

  @override
  void didUpdateWidget(HomeGreetingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      setState(() {
        _statsValue = null;
        _stats = UserStatsService.getStats();
      });
    }
  }

  static const List<String> _weekdays = <String>[
    'Ravivar', 'Somvar', 'Mangalvar', 'Budhvar', 'Guruvar', 'Shukravar', 'Shanivar',
  ];

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String get _todayLabel {
    final DateTime now = DateTime.now();
    return '${_weekdays[now.weekday % 7]}, ${now.day} ${_months[now.month - 1]}';
  }

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Set when a refresh resolves before the new future does.
  Map<String, dynamic>? _statsValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.brandDeep,
        borderRadius: AppRadii.lgAll,
        boxShadow: AppElevation.glow(
          const Color(0xFF2563EB),
          opacity: widget.isDarkMode ? 0.30 : 0.20,
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Decorative glow so the card does not look like a flat rectangle.
          Positioned(
            right: -34,
            top: -34,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FutureBuilder<Map<String, dynamic>>(
                future: _stats,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<Map<String, dynamic>> snapshot,
                ) {
                  final Map<String, dynamic> stats =
                      _statsValue ?? snapshot.data ?? const <String, dynamic>{};
                  final String name =
                      (stats['student_name'] as String?)?.trim().isNotEmpty == true
                          ? (stats['student_name'] as String).trim()
                          : 'Aspirant';
                  final int streak = (stats['streak'] as int?) ?? 1;
                  final int questions = (stats['questions'] as int?) ?? 0;
                  final int accuracy = (stats['accuracy'] as int?) ?? 100;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ---- identity row ----
                      Row(
                        children: <Widget>[
                          const BrandMark(
                            size: 44,
                            showGlow: false,
                            gradient: AppGradients.study,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '$_greeting, $name',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _todayLabel,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StreakPill(streak: streak),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ---- live numbers ----
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _StatTile(
                              icon: Icons.check_circle_outline_rounded,
                              value: '$questions',
                              label: 'Questions',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.percent_rounded,
                              value: '$accuracy%',
                              label: 'Accuracy',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.assignment_turned_in_outlined,
                              value: '${(stats['mocks'] as int?) ?? 0}',
                              label: 'Mocks',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ---- actions ----
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _HeaderAction(
                              label: 'Learn Hub',
                              icon: Icons.school_rounded,
                              solid: true,
                              onTap: widget.onTapLearn,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeaderAction(
                              label: widget.challengeLoading ? 'Loading…' : 'Daily Challenge',
                              icon: Icons.bolt_rounded,
                              solid: false,
                              loading: widget.challengeLoading,
                              onTap: widget.challengeLoading ? null : widget.onStartChallenge,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFFDE68A), size: 15),
          const SizedBox(width: 5),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: AppRadii.smAll,
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Colors.white.withOpacity(0.85), size: 15),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.solid,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final bool solid;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: solid ? Colors.white : Colors.white.withOpacity(0.14),
      borderRadius: AppRadii.smAll,
      child: InkWell(
        borderRadius: AppRadii.smAll,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 17,
                  color: solid ? const Color(0xFF1D4ED8) : Colors.white,
                ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: solid ? const Color(0xFF1D4ED8) : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

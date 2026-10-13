import 'package:flutter/material.dart';

// Aapke service ka sahi relative path:
import '../services/user_stats_service.dart';

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
  final int reloadToken;
  final VoidCallback onTapLearn;
  final VoidCallback onStartChallenge;
  final bool challengeLoading;

  @override
  State<HomeGreetingHeader> createState() => _HomeGreetingHeaderState();
}

class _HomeGreetingHeaderState extends State<HomeGreetingHeader> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = UserStatsService.getStats();
  }

  @override
  void didUpdateWidget(HomeGreetingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      setState(() {
        _statsFuture = UserStatsService.getStats();
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

  // ⏰ Option 2: Time ke hisaab se dynamic greeting icon
  IconData get _greetingIcon {
    final int hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;       // ☀️ Subah
    if (hour < 17) return Icons.light_mode_rounded;     // 🌤️ Dopahar
    return Icons.nights_stay_rounded;                   // 🌙 Shaam / Raat
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // 📐 Edge alignment ke liye horizontal margin hataya gaya hai
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1E3D), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(widget.isDarkMode ? 0.28 : 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.10),
              ),
            ),
          ),

          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
              final Map<String, dynamic> stats = snapshot.data ?? const <String, dynamic>{};
              
              final String name = (stats['student_name'] as String?)?.trim().isNotEmpty == true
                  ? (stats['student_name'] as String).trim()
                  : 'Aspirant';
              final int streak = (stats['streak'] as int?) ?? 1;
              final int questions = (stats['questions'] as int?) ?? 0;
              final int accuracy = (stats['accuracy'] as int?) ?? 100;
              final int mocks = (stats['mocks'] as int?) ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 1️⃣ Identity Row (Dynamic Day/Night Icon + Greeting + Streak Pill)
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _greetingIcon, // 👈 Dynamic Time-Based Icon
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '$_greeting, $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF1F5F9),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _todayLabel,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
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
                  const SizedBox(height: 16),

                  // 2️⃣ Live Performance Numbers
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _StatTile(
                          icon: Icons.check_circle_outline_rounded,
                          value: '$questions',
                          label: 'Questions',
                          accentColor: const Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.track_changes_rounded,
                          value: '$accuracy%',
                          label: 'Accuracy',
                          accentColor: const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.quiz_outlined,
                          value: '$mocks',
                          label: 'Mocks',
                          accentColor: const Color(0xFFA78BFA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3️⃣ Action Buttons
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
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEA580C).withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Color(0xFFFDBA74),
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
    required this.accentColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accentColor, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 10.5,
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
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: solid
                ? const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: solid ? null : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: solid
                ? null
                : Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
            boxShadow: solid
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 17,
                  color: solid ? Colors.white : const Color(0xFF38BDF8),
                ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
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

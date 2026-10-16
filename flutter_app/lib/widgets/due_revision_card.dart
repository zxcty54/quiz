import 'package:flutter/material.dart';

import '../screens/wrong_questions_screen.dart';
import '../services/user_stats_service.dart';

/// Home par Greeting ke theek neeche "Aaj ke Revision Due" wala bada card
/// (Wrong Vault – Level 2).
///
/// Due sawal ho tabhi dikhta hai; na ho to bilkul jagah nahi leta.
/// Tap ya button se Wrong Vault khulta hai, wapas aane par count taja ho jata hai.
class DueRevisionCard extends StatefulWidget {
  final bool isDarkMode;

  const DueRevisionCard({super.key, required this.isDarkMode});

  @override
  State<DueRevisionCard> createState() => DueRevisionCardState();
}

class DueRevisionCardState extends State<DueRevisionCard> {
  Map<String, int> _stats = const {'due': 0, 'mock': 0, 'revision': 0, 'repeat': 0};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadCounts();
  }

  // Home ke pull-to-refresh se bhi yehi bulaya jata hai
  Future<void> loadCounts() async {
    final stats = await UserStatsService.getDueWrongStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loaded = true;
      });
    }
  }

  Future<void> _openVault() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WrongQuestionsScreen(isDarkMode: widget.isDarkMode),
      ),
    );
    loadCounts(); // vault se wapas aane par count taja
  }

  @override
  Widget build(BuildContext context) {
    final due = _stats['due'] ?? 0;

    // Due na ho to card hi nahi — Home par khali jagah bhi nahi bachegi
    if (!_loaded || due == 0) return const SizedBox.shrink();

    final isDark = widget.isDarkMode;
    const rose = Color(0xFFE11D48);
    final mock = _stats['mock'] ?? 0;
    final revision = _stats['revision'] ?? 0;
    final repeat = _stats['repeat'] ?? 0;

    return Padding(
      // Card dikhe tabhi neeche ki jagah — gayab ho to gap bhi gayab
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTap: _openVault,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFFECDD3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: rose.withValues(alpha: isDark ? 0.10 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: rose.withValues(alpha: isDark ? 0.22 : 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 22,
                      color: rose,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                            children: [
                              const TextSpan(text: 'Aaj ke '),
                              TextSpan(
                                text: '$due Revision Due',
                                style: const TextStyle(color: rose),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ye sawal sahi samay par wapas aaye hain — ab fix karoge to pakke yaad rahenge.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _dueChip('🎯 $mock Mock ke', rose, isDark, filled: true),
                  _dueChip('⚡ $revision Revision ke', rose, isDark, filled: true),
                  if (repeat > 0) _dueChip('🔁 $repeat do baar galat', rose, isDark, filled: false),
                ],
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _openVault,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Revision Shuru Karo',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dueChip(String label, Color rose, bool isDark, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? rose.withValues(alpha: isDark ? 0.18 : 0.08)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: filled
              ? rose.withValues(alpha: isDark ? 0.40 : 0.25)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: filled
              ? (isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C))
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../screens/wrong_questions_screen.dart';
import '../services/user_stats_service.dart';

/// Home par "Aaj ke Due Sawal" wala chhota card (Wrong Vault – Level 2).
///
/// Due sawal ho tabhi dikhta hai; na ho to bilkul jagah nahi leta.
/// Tap karne par Wrong Vault khulta hai, wapas aane par count taja ho jata hai.
class DueRevisionCard extends StatefulWidget {
  final bool isDarkMode;

  const DueRevisionCard({super.key, required this.isDarkMode});

  @override
  State<DueRevisionCard> createState() => DueRevisionCardState();
}

class DueRevisionCardState extends State<DueRevisionCard> {
  int _dueCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadCounts();
  }

  // Home ke pull-to-refresh se bhi yehi bulaya jata hai
  Future<void> loadCounts() async {
    final count = await UserStatsService.getDueWrongCount();
    if (mounted) {
      setState(() {
        _dueCount = count;
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
    // Due na ho to card hi nahi — Home par khali jagah bhi nahi bachegi
    if (!_loaded || _dueCount == 0) return const SizedBox.shrink();

    final isDark = widget.isDarkMode;
    const rose = Color(0xFFE11D48);

    return Padding(
      // Card dikhe tabhi neeche ki jagah — gayab ho to gap bhi gayab
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTap: _openVault,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: rose.withValues(alpha: isDark ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 21,
                  color: rose,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aaj ke Revision Due',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_dueCount galat sawal intezaar kar rahe hain — abhi fix karo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: rose,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shuru Karo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

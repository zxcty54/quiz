import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_stats_service.dart';

class AspirantChecklistCard extends StatefulWidget {
  final bool isDarkMode;
  const AspirantChecklistCard({super.key, required this.isDarkMode});

  @override
  State<AspirantChecklistCard> createState() => _AspirantChecklistCardState();
}

class _AspirantChecklistCardState extends State<AspirantChecklistCard> with WidgetsBindingObserver {
  bool _savedCaDone = false;        // 1. Bookmark Current Affair
  bool _savedRevQsDone = false;     // 2. Bookmark Revision Question
  bool _attemptedCbtDone = false;   // 3. Attempt CBT Mock 1 Time
  bool _wrongVaultDone = false;     // 4. Analyze Trap in Wrong Question Vault
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadChecklistStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadChecklistStatus();
    }
  }

  Future<void> loadChecklistStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ Current Affairs Bookmarks Check
    bool caDone = false;
    final String? caJson = prefs.getString('saved_daily_bulletins');
    if (caJson != null && caJson.isNotEmpty) {
      try {
        final List list = jsonDecode(caJson);
        caDone = list.isNotEmpty;
      } catch (_) {}
    }

    // 2️⃣ Revision Question Bookmarks Check via UserStatsService
    final stats = await UserStatsService.getStats();
    final int savedBookmarksCount = (stats['bookmarks'] as int? ?? 0);
    final bool bookmarkDone = savedBookmarksCount > 0;

    // 3️⃣ CBT Mock Attempt Check via UserStatsService
    final int mocksAttempted = (stats['mocks'] as int? ?? 0);
    final bool cbtDone = mocksAttempted > 0;

    // 4️⃣ Wrong Question Trap Analysis Check
    // (Checks if user analyzed errors with tags OR opened Wrong Vault)
    bool wrongAnalyzed = prefs.getBool('wrong_vault_analyzed') ?? false;
    if (!wrongAnalyzed) {
      final wrongList = await UserStatsService.getWrongQuestions();
      wrongAnalyzed = wrongList.any((q) => (q['errorTag']?.toString().isNotEmpty ?? false));
    }

    final bool dismissed = prefs.getBool('hide_onboarding_checklist') ?? false;

    if (mounted) {
      setState(() {
        _savedCaDone = caDone;
        _savedRevQsDone = bookmarkDone;
        _attemptedCbtDone = cbtDone;
        _wrongVaultDone = wrongAnalyzed;
        _isDismissed = dismissed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    int completedCount = 0;
    if (_savedCaDone) completedCount++;
    if (_savedRevQsDone) completedCount++;
    if (_attemptedCbtDone) completedCount++;
    if (_wrongVaultDone) completedCount++;

    // 🚀 4/4 Complete hote hi auto-dismiss & permanently save
    if (completedCount == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hide_onboarding_checklist', true);
        if (mounted && !_isDismissed) {
          setState(() => _isDismissed = true);
        }
      });
      return const SizedBox.shrink();
    }

    final double progressPercent = completedCount / 4.0;
    final int displayPercent = (progressPercent * 100).toInt();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 Header Badge & Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text('🎯 ', style: TextStyle(fontSize: 11)),
                      Text(
                        'ASPIRANT ROADMAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completedCount/4 Completed ($displayPercent%)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Aspirant Mastery Checklist 🚀',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete all 4 key features to unlock full exam readiness.',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercent,
                minHeight: 8,
                backgroundColor: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 16),

            // Roadmap Steps
            _buildRoadmapTile(
              stepNum: '1',
              title: 'Bookmark 1 Current Affairs Bulletin',
              desc: 'Save important daily news for quick revision',
              isDone: _savedCaDone,
            ),
            _buildRoadmapTile(
              stepNum: '2',
              title: 'Bookmark 1 Revision Question',
              desc: 'Star any question while practicing chapters',
              isDone: _savedRevQsDone,
            ),
            _buildRoadmapTile(
              stepNum: '3',
              title: 'Attempt 1 CBT Mock Test',
              desc: 'Experience full timer-based exam simulation',
              isDone: _attemptedCbtDone,
            ),
            _buildRoadmapTile(
              stepNum: '4',
              title: 'Analyze Traps in Wrong Question Vault',
              desc: 'Review mistakes & tags to eliminate negative marking',
              isDone: _wrongVaultDone,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapTile({
    required String stepNum,
    required String title,
    required String desc,
    required bool isDone,
    bool isLast = false,
  }) {
    final Color doneColor = const Color(0xFF16A34A);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? doneColor
                      : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : Text(
                        stepNum,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDone
                        ? doneColor.withOpacity(0.5)
                        : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? (widget.isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600)
                          : (widget.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDarkMode ? const Color(0xFF64748B) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

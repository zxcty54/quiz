import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AspirantChecklistCard extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onOpenRevision;
  final VoidCallback? onOpenSectional;

  const AspirantChecklistCard({
    super.key,
    required this.isDarkMode,
    this.onOpenRevision,
    this.onOpenSectional,
  });

  @override
  State<AspirantChecklistCard> createState() => _AspirantChecklistCardState();
}

class _AspirantChecklistCardState extends State<AspirantChecklistCard> {
  bool _profileDone = true;
  bool _firstQuizDone = false;
  bool _firstMockDone = false;
  bool _savedNotesDone = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadChecklistStatus();
  }

  Future<void> _loadChecklistStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileDone = prefs.getBool('has_entered_name') ?? true;
      _firstQuizDone = (prefs.getInt('user_solved_qs') ?? 0) > 0;
      _firstMockDone = (prefs.getInt('user_attempted_mocks') ?? 0) > 0;
      _savedNotesDone = (prefs.getInt('user_saved_bookmarks') ?? 0) > 0;
      _isDismissed = prefs.getBool('hide_onboarding_checklist') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    int completedCount = 0;
    if (_profileDone) completedCount++;
    if (_firstQuizDone) completedCount++;
    if (_firstMockDone) completedCount++;
    if (_savedNotesDone) completedCount++;

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
          color: widget.isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
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
            // 🎯 TOP HEADER: Badge & Completion Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: completedCount == 4
                        ? const Color(0xFF16A34A).withOpacity(0.15)
                        : const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completedCount/4 Completed ($displayPercent%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: completedCount == 4
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 📢 TITLE
            Text(
              'Your Prep Launchpad 🚀',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete all steps to unlock full accuracy analytics & streak rewards.',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),

            // ⚡ PROGRESS BAR
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercent,
                minHeight: 8,
                backgroundColor: widget.isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedCount == 4
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🗺️ STEP LIST TILES
            _buildRoadmapTile(
              stepNum: '1',
              title: 'Personalized Profile Setup',
              desc: 'Name, target exam & study preferences',
              isDone: _profileDone,
            ),
            _buildRoadmapTile(
              stepNum: '2',
              title: 'First Revision Practice',
              desc: 'Attempt 10 high-yield chapter questions',
              isDone: _firstQuizDone,
            ),
            _buildRoadmapTile(
              stepNum: '3',
              title: 'Sectional CBT Mock Test',
              desc: 'Solve timed test with negative marking',
              isDone: _firstMockDone,
            ),
            _buildRoadmapTile(
              stepNum: '4',
              title: 'Bookmark & Mistake Vault',
              desc: 'Save tricky questions for rapid recall',
              isDone: _savedNotesDone,
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
    final Color activeColor = const Color(0xFF2563EB);
    final Color doneColor = const Color(0xFF16A34A);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step circle with vertical connector line
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
                  boxShadow: isDone
                      ? [
                          BoxShadow(
                            color: doneColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
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

          // Content
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

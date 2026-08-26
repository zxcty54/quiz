import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AspirantChecklistCard extends StatefulWidget {
  final bool isDarkMode;
  const AspirantChecklistCard({super.key, required this.isDarkMode});

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

    int completedTasks = 0;
    if (_profileDone) completedTasks++;
    if (_firstQuizDone) completedTasks++;
    if (_firstMockDone) completedTasks++;
    if (_savedNotesDone) completedTasks++;

    double progress = completedTasks / 4.0;
    final cardColor = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Card(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🚀', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        'Aspirant Starter Guide',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '$completedTasks/4 Done',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      if (completedTasks == 4) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('hide_onboarding_checklist', true);
                            setState(() => _isDismissed = true);
                          },
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(height: 10),
              _buildItem('1. Setup Profile Details', _profileDone, textColor),
              _buildItem('2. Attempt your first Quiz', _firstQuizDone, textColor),
              _buildItem('3. Start a Sectional CBT Mock', _firstMockDone, textColor),
              _buildItem('4. Bookmark important Questions', _savedNotesDone, textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String title, bool isDone, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? const Color(0xFF16A34A) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDone ? Colors.grey : textColor,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_stats_service.dart';
import 'saved_questions_screen.dart';
import 'wrong_questions_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isHindi;
  final bool isDarkMode;
  final ValueChanged<bool> onHindiChanged;
  final ValueChanged<bool> onDarkModeChanged;

  const ProfileScreen({
    super.key,
    required this.isHindi,
    required this.isDarkMode,
    required this.onHindiChanged,
    required this.onDarkModeChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: UserStatsService.getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'questions': 0,
          'mocks': 0,
          'bookmarks': 0,
          'streak': 1,
          'accuracy': 100,
          'last_chapter_name': 'No chapter started',
          'last_chapter_path': '',
          'weekly_progress': [0, 0, 0, 0, 0, 0, 0]
        };

        final List<int> weeklyCounts = List<int>.from(stats['weekly_progress'] ?? [0, 0, 0, 0, 0, 0, 0]);
        int maxCount = weeklyCounts.reduce((a, b) => a > b ? a : b);
        if (maxCount == 0) maxCount = 1; // Prevent division by zero

        final int solvedQs = stats['questions'] as int? ?? 0;
        final int attemptedMocks = stats['mocks'] as int? ?? 0;
        final int userStreak = stats['streak'] as int? ?? 1;
        final int savedBookmarksCount = stats['bookmarks'] as int? ?? 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 👤 1. USER HEADER CARD
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Color(0xFF2563EB),
                      child: Text('🎓', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back 👋',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                          const Text(
                            'Aspirant Aspirant',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                                child: Text('🔥 $userStreak Day Streak', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  '🏅 Level ${_calculateLevel(solvedQs)}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 📊 2. LEARNING DASHBOARD (LIVE STATS)
            const Text('📊 Learning Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildProfileStatTile('Questions Solved', '$solvedQs', '📝', const Color(0xFF2563EB)),
                _buildProfileStatTile('Mocks Attempted', '$attemptedMocks', '🎯', const Color(0xFFD97706)),
                _buildProfileStatTile('Overall Accuracy', '${stats['accuracy']}%', '⚡', const Color(0xFF16A34A)),
                _buildProfileStatTile('Study Time', 'Daily Active', '⏱️', const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 20),

            // 📈 3. RECENT PROGRESS (LIVE DYNAMIC BAR CHART)
            const Text('📈 Recent Progress (Last 7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    double heightFactor = weeklyCounts[index] / maxCount;
                    if (heightFactor < 0.1 && weeklyCounts[index] > 0) heightFactor = 0.15;
                    
                    DateTime dayDate = DateTime.now().subtract(Duration(days: 6 - index));
                    String dayLabel = _weekDays[dayDate.weekday - 1];

                    return _buildBar(dayLabel, heightFactor, weeklyCounts[index] > 0 ? const Color(0xFF2563EB) : Colors.grey.shade300);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📂 4. QUICK ACCESS REVISION ZONE (FULLY FUNCTIONAL NAVIGATIONS)
            const Text('📂 Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Text('⭐', style: TextStyle(fontSize: 20)),
                    title: const Text('Saved / Bookmarked Questions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('$savedBookmarksCount Saved Items', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SavedQuestionsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Text('❌', style: TextStyle(fontSize: 20)),
                    title: const Text('Wrong Questions Vault', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Revise Mistakes', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const WrongQuestionsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Text('📖', style: TextStyle(fontSize: 20)),
                    title: const Text('Continue Last Chapter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('${stats['last_chapter_name']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB), size: 24),
                    onTap: () {
                      if (stats['last_chapter_name'] != 'No chapter started') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Resuming ${stats['last_chapter_name']}...')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🏆 5. DYNAMIC ACHIEVEMENTS BADGES
            const Text('🏆 Achievements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildDynamicBadge(
                    emoji: '🔥',
                    title: '$userStreak Day Streak',
                    isUnlocked: userStreak >= 3,
                    activeColor: Colors.amber,
                  ),
                  _buildDynamicBadge(
                    emoji: '🏅',
                    title: '100 Qs Club',
                    isUnlocked: solvedQs >= 100,
                    activeColor: Colors.blue,
                  ),
                  _buildDynamicBadge(
                    emoji: '⚡',
                    title: 'First Mock',
                    isUnlocked: attemptedMocks >= 1,
                    activeColor: Colors.purple,
                  ),
                  _buildDynamicBadge(
                    emoji: '📚',
                    title: 'Master Scholar',
                    isUnlocked: solvedQs >= 500,
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ⚙️ 6. APP SETTINGS & TOGGLES
            const Text('⚙️ Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Bilingual Mode (Hindi / Eng)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: widget.isHindi,
                    onChanged: widget.onHindiChanged,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Dark Mode (Night Theme)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: widget.isDarkMode,
                    onChanged: widget.onDarkModeChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🤝 STUDENT SUPPORT CARD
            _buildStudentSupportCard(context),
          ],
        );
      },
    );
  }

  // 💡 HELPER LOGIC FOR USER LEVEL
  String _calculateLevel(int totalQs) {
    if (totalQs < 50) return '1 (Beginner)';
    if (totalQs < 200) return '2 (Learner)';
    if (totalQs < 500) return '3 (Explorer)';
    if (totalQs < 1000) return '4 (Scholar)';
    return '5 (Master)';
  }

  // WIDGET HELPERS
  Widget _buildProfileStatTile(String label, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: 60 * (heightFactor == 0 ? 0.05 : heightFactor),
          width: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDynamicBadge({
    required String emoji,
    required String title,
    required bool isUnlocked,
    required Color activeColor,
  }) {
    final Color bgColor = isUnlocked ? activeColor.withOpacity(0.12) : Colors.grey.shade100;
    final Color borderColor = isUnlocked ? activeColor : Colors.grey.shade300;
    final Color textColor = isUnlocked ? activeColor : Colors.grey.shade500;

    return Container(
      width: 95,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isUnlocked ? 1.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(
                  fontSize: 22,
                  color: isUnlocked ? null : Colors.grey.shade400,
                ),
              ),
              if (!isUnlocked)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text('🔒', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSupportCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFF4757), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤝 Student Initiative (100% Free)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFF4757))),
            const SizedBox(height: 4),
            const Text('Help keep us free for rural students by contributing ₹10.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'niftyfifty@upi'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ UPI ID (niftyfifty@upi) copied!')));
                },
                icon: const Text('❤️'),
                label: const Text('Support Us (₹10 Contribute)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

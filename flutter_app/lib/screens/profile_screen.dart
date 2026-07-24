import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_stats_service.dart';

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
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: UserStatsService.getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'questions': 2450,
          'mocks': 34,
          'bookmarks': 12,
          'streak': 7
        };

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
                                child: Text('🔥 ${stats['streak']} Day Streak', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(12)),
                                child: const Text('🏅 Level 4 (Explorer)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
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

            // 📊 2. LEARNING DASHBOARD
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
                _buildProfileStatTile('Questions Solved', '${stats['questions']}', '📝', const Color(0xFF2563EB)),
                _buildProfileStatTile('Mocks Attempted', '${stats['mocks']}', '🎯', const Color(0xFFD97706)),
                _buildProfileStatTile('Overall Accuracy', '78%', '⚡', const Color(0xFF16A34A)),
                _buildProfileStatTile('Study Time', '42 Hrs', '⏱️', const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 20),

            // 📈 3. RECENT PROGRESS (WEEKLY BAR GRAPH)
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
                  children: [
                    _buildBar('Mon', 0.5, const Color(0xFF2563EB)),
                    _buildBar('Tue', 0.8, const Color(0xFF2563EB)),
                    _buildBar('Wed', 0.3, const Color(0xFF2563EB)),
                    _buildBar('Thu', 0.9, const Color(0xFF2563EB)),
                    _buildBar('Fri', 0.6, const Color(0xFF2563EB)),
                    _buildBar('Sat', 0.7, const Color(0xFF10B981)),
                    _buildBar('Sun', 0.4, Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📂 4. QUICK ACCESS REVISION ZONE
            const Text('📂 Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Text('⭐', style: TextStyle(fontSize: 20)),
                    title: const Text('Saved / Bookmarked Questions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Text('❌', style: TextStyle(fontSize: 20)),
                    title: const Text('Wrong Questions Vault', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Text('📖', style: TextStyle(fontSize: 20)),
                    title: const Text('Continue Last Chapter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Cell Biology (Set 01)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB), size: 24),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🏆 5. ACHIEVEMENTS BADGES
            const Text('🏆 Achievements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 85,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildBadgeItem('🔥', '7 Day Streak', Colors.amber),
                  _buildBadgeItem('🏅', '100 Qs Club', Colors.blue),
                  _buildBadgeItem('📚', 'Bio Explorer', Colors.green),
                  _buildBadgeItem('⚡', 'First Mock Done', Colors.purple),
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
          height: 60 * heightFactor,
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

  Widget _buildBadgeItem(String emoji, String title, Color color) {
    return Container(
      width: 95,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
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

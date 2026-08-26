import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/user_stats_service.dart';
import 'saved_questions_screen.dart';
import 'wrong_questions_screen.dart';
import 'saved_current_affairs_screen.dart';
import '../widgets/donation_widget.dart';
import '../widgets/app_global_feedback_dialog.dart';

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
  int _savedCaCount = 0;
  String _userName = 'Aspirant';
  String _userEmail = '';
  String _userMobile = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    // 👤 Load Name, Email, Mobile from SharedPreferences
    final String savedName = prefs.getString('user_name') ?? 'Aspirant';
    final String savedEmail = prefs.getString('user_email') ?? '';
    final String savedMobile = prefs.getString('user_mobile') ?? '';

    // 📌 Load Saved Current Affairs Count
    int caCount = 0;
    final String? savedJson = prefs.getString('saved_daily_bulletins');
    if (savedJson != null) {
      try {
        final List parsed = jsonDecode(savedJson);
        caCount = parsed.length;
      } catch (e) {
        debugPrint("Error loading saved news count in Profile: $e");
      }
    }

    if (mounted) {
      setState(() {
        _userName = savedName;
        _userEmail = savedEmail;
        _userMobile = savedMobile;
        _savedCaCount = caCount;
      });
    }
  }

  void _showEditProfileDialog(bool isDark) {
    final nameCtrl = TextEditingController(text: _userName == 'Aspirant' ? '' : _userName);
    final emailCtrl = TextEditingController(text: _userEmail);
    final mobileCtrl = TextEditingController(text: _userMobile);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Profile Details',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Rahul Kumar',
                    prefixIcon: Icon(Icons.person, color: Color(0xFF2563EB)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Naam enter karna zaroori hai' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'e.g. student@gmail.com',
                    prefixIcon: Icon(Icons.email, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number (Optional)',
                    hintText: 'e.g. 9876543210',
                    prefixIcon: Icon(Icons.phone_android, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', nameCtrl.text.trim());
                await prefs.setString('user_email', emailCtrl.text.trim());
                await prefs.setString('user_mobile', mobileCtrl.text.trim());

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadProfileData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Profile details updated!'),
                      backgroundColor: Color(0xFF16A34A),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    final Color headerTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

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
        if (maxCount == 0) maxCount = 1;

        final int solvedQs = stats['questions'] as int? ?? 0;
        final int attemptedMocks = stats['mocks'] as int? ?? 0;
        final int userStreak = stats['streak'] as int? ?? 1;
        final int savedBookmarksCount = stats['bookmarks'] as int? ?? 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 👤 1. DYNAMIC USER HEADER CARD (WITH NAME, EMAIL, MOBILE & EDIT)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFF2563EB),
                          child: Text('🎓', style: TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aspirant Profile 👋',
                                style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _userName,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headerTextColor),
                              ),
                              if (_userEmail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined, size: 12, color: subTextColor),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _userEmail,
                                        style: TextStyle(fontSize: 11.5, color: subTextColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_userMobile.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.phone_android_outlined, size: 12, color: subTextColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      _userMobile,
                                      style: TextStyle(fontSize: 11.5, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '🔥 $userStreak Day Streak',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '🏅 Level ${_calculateLevel(solvedQs)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                          tooltip: 'Edit Profile',
                          onPressed: () => _showEditProfileDialog(isDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 📊 2. LEARNING DASHBOARD
            Text('📊 Learning Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: headerTextColor)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildProfileStatTile('Questions Solved', '$solvedQs', '📝', const Color(0xFF2563EB), isDark),
                _buildProfileStatTile('Mocks Attempted', '$attemptedMocks', '🎯', const Color(0xFFD97706), isDark),
                _buildProfileStatTile('Overall Accuracy', '${stats['accuracy']}%', '⚡', const Color(0xFF16A34A), isDark),
                _buildProfileStatTile('Study Time', 'Daily Active', '⏱️', const Color(0xFF7C3AED), isDark),
              ],
            ),
            const SizedBox(height: 20),

            // 📈 3. RECENT PROGRESS (7 DAYS)
            Text('📈 Recent Progress (Last 7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: headerTextColor)),
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

                    return _buildBar(
                      dayLabel,
                      heightFactor,
                      weeklyCounts[index] > 0 ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      subTextColor,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📂 4. QUICK ACCESS
            Text('📂 Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: headerTextColor)),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Text('⭐', style: TextStyle(fontSize: 20)),
                    title: Text('Saved / Bookmarked Questions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headerTextColor)),
                    subtitle: Text('$savedBookmarksCount Saved Items', style: TextStyle(fontSize: 11, color: subTextColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subTextColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SavedQuestionsScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ListTile(
                    leading: const Text('❌', style: TextStyle(fontSize: 20)),
                    title: Text('Wrong Questions Vault', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headerTextColor)),
                    subtitle: Text('Revise Mistakes', style: TextStyle(fontSize: 11, color: subTextColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subTextColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const WrongQuestionsScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ListTile(
                    leading: const Text('📌', style: TextStyle(fontSize: 20)),
                    title: Text('Saved Current Affairs Vault', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headerTextColor)),
                    subtitle: Text('$_savedCaCount Saved Bulletins', style: TextStyle(fontSize: 11, color: subTextColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subTextColor),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SavedCurrentAffairsScreen()),
                      );
                      _loadProfileData();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🏆 5. ACHIEVEMENTS
            Text('🏆 Achievements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: headerTextColor)),
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
                    isDark: isDark,
                  ),
                  _buildDynamicBadge(
                    emoji: '🏅',
                    title: '100 Qs Club',
                    isUnlocked: solvedQs >= 100,
                    activeColor: Colors.blue,
                    isDark: isDark,
                  ),
                  _buildDynamicBadge(
                    emoji: '⚡',
                    title: 'First Mock',
                    isUnlocked: attemptedMocks >= 1,
                    activeColor: Colors.purple,
                    isDark: isDark,
                  ),
                  _buildDynamicBadge(
                    emoji: '📚',
                    title: 'Master Scholar',
                    isUnlocked: solvedQs >= 500,
                    activeColor: Colors.green,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ⚙️ 6. APP PREFERENCES
            Text('⚙️ Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: headerTextColor)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Bilingual Mode (Hindi / Eng)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: headerTextColor)),
                    value: widget.isHindi,
                    onChanged: widget.onHindiChanged,
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  SwitchListTile(
                    title: Text('Dark Mode (Night Theme)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: headerTextColor)),
                    value: widget.isDarkMode,
                    onChanged: (val) async {
                      widget.onDarkModeChanged(val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('is_dark_mode', val);

                      globalThemeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🤝 COMMUNITY DONATION WIDGET
            DonationWidget(isDarkMode: isDark),
            const SizedBox(height: 14),

            // 🌟 7. ATTENTION-GRABBING FEEDBACK BANNER
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFFF59E0B),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AppGlobalFeedbackDialog(isDarkMode: isDark),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text('💬', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Share Idea / Feedback',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      'DEV TEAM',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Request features or report issue to developers',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFFB45309),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Review',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  String _calculateLevel(int totalQs) {
    if (totalQs < 50) return '1 (Beginner)';
    if (totalQs < 200) return '2 (Learner)';
    if (totalQs < 500) return '3 (Explorer)';
    if (totalQs < 1000) return '4 (Scholar)';
    return '5 (Master)';
  }

  Widget _buildProfileStatTile(String label, String value, String emoji, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.2)),
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor, Color color, Color textColor) {
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
        Text(day, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDynamicBadge({
    required String emoji,
    required String title,
    required bool isUnlocked,
    required Color activeColor,
    required bool isDark,
  }) {
    final Color bgColor = isUnlocked
        ? activeColor.withOpacity(isDark ? 0.2 : 0.12)
        : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100);
    final Color borderColor = isUnlocked
        ? activeColor
        : (isDark ? const Color(0xFF334155) : Colors.grey.shade300);
    final Color textColor = isUnlocked
        ? (isDark ? activeColor.withOpacity(0.9) : activeColor)
        : (isDark ? const Color(0xFF64748B) : Colors.grey.shade500);

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
}

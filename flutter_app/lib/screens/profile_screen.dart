import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/user_stats_service.dart';
import 'saved_questions_screen.dart';
import 'wrong_questions_screen.dart';
import 'saved_current_affairs_screen.dart';
import '../widgets/donation_widget.dart';
import '../widgets/app_global_feedback_dialog.dart';
import '../widgets/mastery_evolution_card.dart';
import '../widgets/coaching_onboarding_cta_widget.dart';
import '../widgets/cartoon_avatar.dart';

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
  int _masteryReloadToken = 0;
  int _savedCaCount = 0;
  String _userName = 'Aspirant';
  String _userEmail = '';
  String _userMobile = '';
  String _userDistrict = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    final String savedName = prefs.getString('custom_aspirant_name')?.trim() ??
        prefs.getString('user_name')?.trim() ??
        'Aspirant';

    final String savedMobile = prefs.getString('user_mobile')?.trim() ?? '';
    final String savedEmail = prefs.getString('user_email')?.trim() ?? '';
    final String savedDistrict = prefs.getString('user_district')?.trim() ?? '';

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
        _userDistrict = savedDistrict;
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
                final String updatedName = nameCtrl.text.trim();
                final String updatedEmail = emailCtrl.text.trim();
                final String updatedMobile = mobileCtrl.text.trim();

                String? currentUserId = prefs.getString('user_id');
                if (currentUserId == null || currentUserId.isEmpty) {
                  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
                  final rnd = math.Random();
                  final randomCode = List.generate(16, (i) => chars[rnd.nextInt(chars.length)]).join();
                  currentUserId = 'usr_$randomCode';
                  await prefs.setString('user_id', currentUserId);
                }

                await prefs.setString('custom_aspirant_name', updatedName);
                await prefs.setString('user_name', updatedName);
                await prefs.setString('user_email', updatedEmail);
                await prefs.setString('user_mobile', updatedMobile);
                await prefs.setString('student_contact_id', updatedMobile.isNotEmpty ? updatedMobile : 'N/A');

                try {
                  final String userDistrict = prefs.getString('user_district') ?? 'Patna';
                  await Supabase.instance.client.from('app_users').upsert({
                    'user_id': currentUserId,
                    'full_name': updatedName,
                    'district': userDistrict,
                    'mobile_number': updatedMobile.isNotEmpty ? updatedMobile : 'N/A',
                    'email': updatedEmail.isNotEmpty ? updatedEmail : 'N/A',
                    'updated_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'user_id');
                } catch (e) {
                  debugPrint('Supabase profile update sync error: $e');
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadProfileData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile details updated!'),
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
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);

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
        final int weekTotal = weeklyCounts.fold<int>(0, (a, b) => a + b);
        final int unlockedCount = [userStreak >= 3, solvedQs >= 100, attemptedMocks >= 1, solvedQs >= 500].where((e) => e).length;

        return RefreshIndicator(
          color: const Color(0xFF2563EB),
          onRefresh: () async {
            await _loadProfileData();
            if (mounted) setState(() => _masteryReloadToken++);
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== Profile Hero (Home welcome wali royal-blue theme) =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0A1120), const Color(0xFF172554), const Color(0xFF1E40AF)]
                        : [const Color(0xFF172554), const Color(0xFF1E40AF), const Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Naam ke akshar ki jagah cartoon avatar — har student ka
                        // apna (naam se banta hai, isliye hamesha ek hi dikhega)
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: CartoonAvatar(seed: _userName, size: 53),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _userDistrict.isNotEmpty ? '🎯 Exam Aspirant • 📍 $_userDistrict' : '🎯 Exam Aspirant',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85)),
                              ),
                              if (_userEmail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _userEmail,
                                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (_userMobile.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _userMobile,
                                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _showEditProfileDialog(isDark),
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Colors.white.withOpacity(0.35)),
                            ),
                            child: const Text('✏️ Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            '🔥 $userStreak Day Streak',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF451A03)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withOpacity(0.20)),
                          ),
                          child: Text(
                            '🏅 Level ${_calculateLevel(solvedQs)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.13)),
                      ),
                      child: Row(
                        children: [
                          _heroStat('$solvedQs', 'QUESTIONS'),
                          _heroStat('$attemptedMocks', 'MOCKS'),
                          _heroStat('${(stats['accuracy'] as num?)?.toInt() ?? 0}%', 'ACCURACY'),
                          _heroStat('$savedBookmarksCount', 'SAVED'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===== AI Analysis =====
              _sectionHead('🧠 AI Analysis', '● LIVE', headerTextColor, tagColor: const Color(0xFF059669)),
              MasteryEvolutionCard(isDarkMode: isDark, reloadToken: _masteryReloadToken),

              // ===== Last 7 Days =====
              _sectionHead('📊 Last 7 Days', 'IS HAFTE: $weekTotal QUESTIONS', headerTextColor),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: cardBorder),
                ),
                child: SizedBox(
                  height: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final int count = weeklyCounts[index];
                      double heightFactor = count / maxCount;
                      if (heightFactor < 0.1 && count > 0) heightFactor = 0.15;

                      final DateTime dayDate = DateTime.now().subtract(Duration(days: 6 - index));
                      final bool isToday = index == 6;

                      return _buildBar(
                        isToday ? 'Aaj' : _weekDays[dayDate.weekday - 1],
                        count,
                        heightFactor,
                        count == 0
                            ? (isDark ? const Color(0xFF334155) : Colors.grey.shade300)
                            : (isToday ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)),
                        subTextColor,
                        isToday: isToday,
                      );
                    }),
                  ),
                ),
              ),

              // ===== Quick Access =====
              _sectionHead('⚡ Quick Access', '', headerTextColor),
              Row(
                children: [
                  Expanded(
                    child: _quickTile(
                      icon: '📕',
                      title: 'Wrong Vault',
                      sub: 'Galtiyan revise karo',
                      bg: const Color(0xFFFFF1F2),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const WrongQuestionsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _quickTile(
                      icon: '🔖',
                      title: 'Saved Qs',
                      sub: '$savedBookmarksCount saved items',
                      bg: const Color(0xFFFEF3C7),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const SavedQuestionsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _quickTile(
                      icon: '📰',
                      title: 'CA Vault',
                      sub: '$_savedCaCount saved bulletins',
                      bg: const Color(0xFFEFF6FF),
                      isDark: isDark,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const SavedCurrentAffairsScreen()),
                        );
                        _loadProfileData();
                      },
                    ),
                  ),
                ],
              ),

              // ===== Achievements =====
              _sectionHead('🏆 Achievements', '$unlockedCount / 4 UNLOCKED', headerTextColor),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildDynamicBadge(
                      icon: Icons.local_fire_department_rounded,
                      title: '$userStreak Day Streak',
                      isUnlocked: userStreak >= 3,
                      activeColor: Colors.amber,
                      isDark: isDark,
                    ),
                    _buildDynamicBadge(
                      icon: Icons.military_tech_rounded,
                      title: '100 Qs Club',
                      isUnlocked: solvedQs >= 100,
                      activeColor: Colors.blue,
                      isDark: isDark,
                    ),
                    _buildDynamicBadge(
                      icon: Icons.offline_bolt_rounded,
                      title: 'First Mock',
                      isUnlocked: attemptedMocks >= 1,
                      activeColor: Colors.purple,
                      isDark: isDark,
                    ),
                    _buildDynamicBadge(
                      icon: Icons.menu_book_rounded,
                      title: 'Master Scholar',
                      isUnlocked: solvedQs >= 500,
                      activeColor: Colors.green,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // ===== Settings (Bilingual switch hata diya — woh dead tha) =====
              _sectionHead('⚙️ Settings', '', headerTextColor),
              Card(
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: BorderSide(color: cardBorder)),
                child: SwitchListTile(
                  title: Text('Dark Mode (Night Theme)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: headerTextColor)),
                  value: widget.isDarkMode,
                  onChanged: (val) async {
                    widget.onDarkModeChanged(val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('is_dark_mode', val);

                    globalThemeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ),

              // ===== Coaching Owners =====
              _sectionHead('🏫 Coaching Owners Ke Liye', '', headerTextColor),
              CoachingOnboardingCtaWidget(isDarkMode: isDark),
              const SizedBox(height: 16),
              DonationWidget(isDarkMode: isDark),
              const SizedBox(height: 14),
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
                          child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 22),
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
              Center(
                child: Text(
                  'MockTester • Practice karo, select ho 🎯',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: subTextColor),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  String _avatarInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _sectionHead(String title, String tag, Color textColor, {Color tagColor = const Color(0xFF2563EB)}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2)),
          if (tag.isNotEmpty)
            Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tagColor, letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.white.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }

  Widget _quickTile({
    required String icon,
    required String title,
    required String sub,
    required Color bg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7)),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: isDark ? bg.withOpacity(0.22) : bg, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: subColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateLevel(int totalQs) {
    if (totalQs < 50) return '1 (Beginner)';
    if (totalQs < 200) return '2 (Learner)';
    if (totalQs < 500) return '3 (Explorer)';
    if (totalQs < 1000) return '4 (Scholar)';
    return '5 (Master)';
  }

  Widget _buildProfileStatTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
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

  Widget _buildBar(String day, int count, double heightFactor, Color color, Color textColor, {bool isToday = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isToday ? const Color(0xFF2563EB) : textColor),
        ),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: 6 + (heightFactor.clamp(0.0, 1.0) * 46),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          day,
          style: TextStyle(
            fontSize: 9.5,
            color: isToday ? const Color(0xFF2563EB) : textColor,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicBadge({
    required IconData icon,
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
              Icon(
                icon,
                size: 24,
                color: isUnlocked ? activeColor : (isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
              ),
              if (!isUnlocked)
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
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

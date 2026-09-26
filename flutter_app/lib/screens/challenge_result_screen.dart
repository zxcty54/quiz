import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeResultScreen extends StatefulWidget {
  final String challengerName;
  final int challengerScore;
  final int myScore;
  final int totalTimeTaken;
  final String challengeCode;
  final bool isDarkMode;
  final VoidCallback? onFinished;

  const ChallengeResultScreen({
    super.key,
    required this.challengerName,
    required this.challengerScore,
    required this.myScore,
    required this.totalTimeTaken,
    required this.challengeCode,
    required this.isDarkMode,
    this.onFinished,
  });

  @override
  State<ChallengeResultScreen> createState() => _ChallengeResultScreenState();
}

class _ChallengeResultScreenState extends State<ChallengeResultScreen> {
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _submitScoreToSupabase();
  }

  // 🏆 Leaderboard Submission Logic (Strict 1 User = 1 Row with Upsert)
  Future<void> _submitScoreToSupabase() async {
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final client = Supabase.instance.client;

      // 1. Permanent Device-backed User ID
      final String? localUserId = prefs.getString('user_id')?.trim();
      if (localUserId == null || localUserId.isEmpty) {
        debugPrint("❌ User ID SharedPreferences me nahi mila!");
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // 2. Standardized User Name
      String userName = prefs.getString('user_name')?.trim() ??
          prefs.getString('custom_aspirant_name')?.trim() ??
          '';

      // Fallback: Agar local name missing ho toh app_users table se 'full_name' uthayein
      if ((userName.isEmpty || userName == 'Aspirant')) {
        try {
          final userRow = await client
              .from('app_users')
              .select('full_name')
              .eq('user_id', localUserId)
              .maybeSingle();

          if (userRow != null && userRow['full_name'] != null) {
            final String dbName = userRow['full_name'].toString().trim();
            if (dbName.isNotEmpty) {
              userName = dbName;
              await prefs.setString('user_name', userName);
              await prefs.setString('custom_aspirant_name', userName);
            }
          }
        } catch (e) {
          debugPrint("app_users se naam fetch karne me error: $e");
        }
      }

      if (userName.isEmpty) userName = 'Aspirant';

      final String district = prefs.getString('user_district')?.trim() ?? 'Patna';

      // 3. Purana score check karein taaki kam score hone par overwrite na ho
      final existing = await client
          .from('daily_challenge_submissions')
          .select('id, score, time_taken_seconds')
          .eq('user_id', localUserId)
          .eq('district', district)
          .maybeSingle();

      bool shouldSave = true;

      if (existing != null) {
        final int oldScore = (existing['score'] ?? 0) as int;
        final int oldTime = (existing['time_taken_seconds'] ?? 9999) as int;

        // Sirf behtar score ya same score par kam time hone par update hoga
        shouldSave = widget.myScore > oldScore ||
            (widget.myScore == oldScore && widget.totalTimeTaken < oldTime);
      }

      // 4. Upsert Operation (Single Row Guarantee)
      if (shouldSave) {
        await client.from('daily_challenge_submissions').upsert(
          {
            'user_id': localUserId,
            'user_name': userName,
            'district': district,
            'score': widget.myScore,
            'time_taken_seconds': widget.totalTimeTaken,
          },
          onConflict: 'user_id,district',
        );
        debugPrint("✅ 1 User = 1 Row Upsert Success: $localUserId | Score: ${widget.myScore}");
      } else {
        debugPrint("ℹ️ Purana record behtar tha, database overwrite nahi kiya.");
      }

      // 5. Local Cache Update
      await prefs.setString('last_sub_user', userName);
      await prefs.setString('last_sub_district', district);
      await prefs.setInt('last_sub_score', widget.myScore);
      await prefs.setInt('last_sub_time', widget.totalTimeTaken);

      if (mounted) {
        setState(() {
          _isSubmitted = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Supabase Submit Error: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // 📲 WhatsApp Challenge Share
  Future<void> _shareOnWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();

    final String myName = prefs.getString('user_name')?.trim() ??
        prefs.getString('custom_aspirant_name')?.trim() ??
        'Dost';

    final String appLink =
        'https://mocktester.app/challenge?code=${widget.challengeCode}&by=$myName&score=${widget.myScore}';

    final String message = '''
⚔️ *MOCKTESTER 1v1 RAPID GK CHALLENGE* ⚔️

Maine 10 sawaalo ka challenge complete kiya hai:
🎯 *Score:* ${widget.myScore}/10
⏱ *Total Time:* ${widget.totalTimeTaken}s

Dum hai toh mujhe hara ke dikhao! Same questions par live test do:
👉 $appLink

App open karo aur seedhe rank ke liye compete karo! 🏆
''';

    await Share.share(message);
  }

  void _exitScreen() {
    widget.onFinished?.call();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bool isDuel = widget.challengerScore > 0;
    final bool won = widget.myScore > widget.challengerScore;
    final bool tie = widget.myScore == widget.challengerScore;

    final scaffoldBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor =
        isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
    final subTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitScreen();
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          title: Text(
            'Challenge Summary',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.close_rounded, color: subTextColor),
              onPressed: _exitScreen,
            )
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),

                // Metric Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isDuel
                            ? (won
                                ? '🎉 Match Jeet Gaye!'
                                : (tie ? '🤝 Match Tie!' : '💔 Match Haar Gaye!'))
                            : 'Test Completed!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDuel && won
                              ? const Color(0xFF16A34A)
                              : textColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (isDuel) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _avatarColumn(widget.challengerName,
                                widget.challengerScore, false, isDark),
                            Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: subTextColor,
                              ),
                            ),
                            _avatarColumn('You', widget.myScore, true, isDark),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '${widget.myScore} / 10',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Time Taken: ${widget.totalTimeTaken}s',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Divider(color: borderColor),
                      const SizedBox(height: 10),

                      // Live Supabase Sync Status Strip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSubmitted
                                ? Icons.check_circle_rounded
                                : (_isSubmitting
                                    ? Icons.sync_rounded
                                    : Icons.cloud_off_rounded),
                            size: 16,
                            color: _isSubmitted
                                ? const Color(0xFF16A34A)
                                : subTextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSubmitted
                                ? 'District Leaderboard par save ho gaya!'
                                : (_isSubmitting
                                    ? 'Syncing rank...'
                                    : 'Offline mode'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: subTextColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // WhatsApp Share Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _shareOnWhatsApp,
                    icon: const Icon(Icons.share_rounded,
                        size: 18, color: Colors.white),
                    label: const Text(
                      'Dost ko WhatsApp par Challenge karein',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Back to Home Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _exitScreen,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Home Screen par Wapas Jayein',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarColumn(String name, int score, bool isMe, bool isDark) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor:
              isMe ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        Text(
          '$score / 10',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isMe ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }
}

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
  String _debugLog = "Connecting to database...";

  @override
  void initState() {
    super.initState();
    _submitScoreToSupabase();
  }

  void _addLog(String msg) {
    debugPrint(msg);
    if (mounted) {
      setState(() {
        _debugLog = "$_debugLog\n$msg";
      });
    }
  }

  // 🏆 Leaderboard Submission Logic (Diagnostic Screen Debugging Included)
  Future<void> _submitScoreToSupabase() async {
    setState(() {
      _isSubmitting = true;
      _debugLog = "▶ Init Submission...";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final client = Supabase.instance.client;

      // 1. User ID check
      final String? localUserId = prefs.getString('user_id')?.trim();
      _addLog("User ID: ${localUserId ?? 'NULL'}");

      if (localUserId == null || localUserId.isEmpty) {
        _addLog("❌ FATAL: user_id is missing in SharedPreferences!");
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // 2. Name & District check
      String userName = prefs.getString('user_name')?.trim() ??
          prefs.getString('custom_aspirant_name')?.trim() ??
          '';

      if (userName.isEmpty || userName == 'Aspirant') {
        try {
          final userRow = await client
              .from('app_users')
              .select('full_name')
              .eq('user_id', localUserId)
              .maybeSingle();

          if (userRow != null && userRow['full_name'] != null) {
            userName = userRow['full_name'].toString().trim();
            await prefs.setString('user_name', userName);
          }
        } catch (e) {
          _addLog("app_users name fetch failed: $e");
        }
      }

      if (userName.isEmpty) userName = 'Aspirant';
      final String district = prefs.getString('user_district')?.trim() ?? 'Patna';

      _addLog("Name: $userName | District: $district");
      _addLog("Submitted Score: ${widget.myScore}/10 (${widget.totalTimeTaken}s)");

      // 3. Check Existing Record in daily_challenge_submissions
      _addLog("Checking existing row in DB...");
      final existingRes = await client
          .from('daily_challenge_submissions')
          .select('id, score, time_taken_seconds')
          .eq('user_id', localUserId)
          .eq('district', district)
          .limit(1);

      if (existingRes.isNotEmpty) {
        final row = existingRes.first;
        final int oldScore = (row['score'] ?? 0) as int;
        final int oldTime = (row['time_taken_seconds'] ?? 9999) as int;
        final rowId = row['id'];

        _addLog("Row Found (ID: $rowId). Old: $oldScore/10 (${oldTime}s)");

        bool isBetter = widget.myScore > oldScore ||
            (widget.myScore == oldScore && widget.totalTimeTaken < oldTime);

        if (isBetter) {
          _addLog("Updating row via ID: $rowId...");
          final updateRes = await client
              .from('daily_challenge_submissions')
              .update({
                'score': widget.myScore,
                'time_taken_seconds': widget.totalTimeTaken,
                'user_name': userName,
              })
              .eq('id', rowId)
              .select();

          _addLog("✅ UPDATE SUCCESS: $updateRes");
        } else {
          _addLog("ℹ️ Old score was equal or better. Skipping DB overwrite.");
        }
      } else {
        // Fallback search by username if ID match not found
        final nameRes = await client
            .from('daily_challenge_submissions')
            .select('id, score, time_taken_seconds')
            .ilike('user_name', userName)
            .eq('district', district)
            .limit(1);

        if (nameRes.isNotEmpty) {
          final row = nameRes.first;
          final rowId = row['id'];
          _addLog("Found row by Name match (ID: $rowId). Updating with user_id...");

          await client.from('daily_challenge_submissions').update({
            'user_id': localUserId,
            'score': widget.myScore,
            'time_taken_seconds': widget.totalTimeTaken,
            'user_name': userName,
          }).eq('id', rowId);

          _addLog("✅ SYNC & UPDATE SUCCESS by name!");
        } else {
          _addLog("No row found. Inserting fresh record...");
          final insertRes = await client
              .from('daily_challenge_submissions')
              .insert({
                'user_id': localUserId,
                'user_name': userName,
                'district': district,
                'score': widget.myScore,
                'time_taken_seconds': widget.totalTimeTaken,
              })
              .select();

          _addLog("✅ INSERT SUCCESS: $insertRes");
        }
      }

      // 4. Update local cache
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
    } catch (e, st) {
      _addLog("❌ ERROR: $e");
      debugPrint("Stack: $st");
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
        if (!didPop) _exitScreen();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Metric Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Test Completed!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${widget.myScore} / 10',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time Taken: ${widget.totalTimeTaken}s',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: borderColor),
                      const SizedBox(height: 8),
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
                                ? 'Database Updated!'
                                : (_isSubmitting
                                    ? 'Syncing to Supabase...'
                                    : 'Offline / Failed'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 🛠️ SCREEN LIVE DEBUG LOG BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSubmitted ? Colors.greenAccent : Colors.amberAccent,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: 16,
                            color: _isSubmitted ? Colors.greenAccent : Colors.amberAccent,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "LIVE SUPABASE DEBUG LOG",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _debugLog,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.greenAccent,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // WhatsApp Share Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _shareOnWhatsApp,
                    icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Dost ko WhatsApp par Challenge karein',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
}

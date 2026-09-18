import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChallengeResultScreen extends StatefulWidget {
  final String challengerName;
  final int challengerScore;
  final int myScore;
  final int totalTimeTaken;
  final String challengeCode;
  final bool isDarkMode;

  const ChallengeResultScreen({
    super.key,
    required this.challengerName,
    required this.challengerScore,
    required this.myScore,
    required this.totalTimeTaken,
    required this.challengeCode,
    required this.isDarkMode,
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

  // Supabase Leaderboard me score sync karna
  Future<void> _submitScoreToSupabase() async {
    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userName = user?.userMetadata?['full_name'] ?? 
                       user?.userMetadata?['name'] ?? 
                       'Aspirant';
      final district = user?.userMetadata?['district'] ?? 'Patna';

      await Supabase.instance.client.from('daily_challenge_submissions').insert({
        'user_id': user?.id,
        'user_name': userName,
        'district': district,
        'score': widget.myScore,
        'time_taken_seconds': widget.totalTimeTaken,
        'challenge_date': DateTime.now().toIso8601String().substring(0, 10),
      });

      if (mounted) {
        setState(() {
          _isSubmitted = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // WhatsApp par 1v1 challenge link bhejna
  void _shareOnWhatsApp() {
    final user = Supabase.instance.client.auth.currentUser;
    final myName = user?.userMetadata?['full_name'] ?? 
                   user?.userMetadata?['name'] ?? 
                   'Mera Dost';

    final String appLink =
        'https://mocktester.app/challenge?code=${widget.challengeCode}&by=$myName&score=${widget.myScore}';

    final String message = '''
⚔️ *MOCKTESTER 1v1 BIHAR GK CHALLENGE* ⚔️

Maine 10 sawaalo ka challenge complete kiya hai:
🎯 *Score:* ${widget.myScore}/10
⏱ *Time:* ${widget.totalTimeTaken} Seconds

Dum hai toh mujhe hara ke dikhao! Same question set par live test do:
👉 $appLink

App download karo ya link khol kar seedhe match shuru karo! 🏆
''';

    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDuel = widget.challengerScore > 0;
    final bool won = widget.myScore > widget.challengerScore;
    final bool tie = widget.myScore == widget.challengerScore;

    final bgColor = widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Match Summary', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),

                // Score card container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isDuel
                            ? (won ? '🎉 Jeet Gaye!' : (tie ? '🤝 Match Tie!' : '💔 Haar Gaye!'))
                            : '🎯 Challenge Complete!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDuel && won ? const Color(0xFF10B981) : textColor,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (isDuel) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _avatarColumn(widget.challengerName, widget.challengerScore, false),
                            const Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey,
                              ),
                            ),
                            _avatarColumn('You', widget.myScore, true),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '${widget.myScore} / 10',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total Time: ${widget.totalTimeTaken}s',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Divider(color: widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSubmitted ? Icons.check_circle_rounded : Icons.sync_rounded,
                            size: 16,
                            color: _isSubmitted ? const Color(0xFF10B981) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSubmitted
                                ? 'District Leaderboard par save ho gaya!'
                                : (_isSubmitting ? 'Rank sync ho raha hai...' : 'Offline mode'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // WhatsApp Share Action Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _shareOnWhatsApp,
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: const Text(
                      'Dost ko WhatsApp par Challenge karein',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Home Navigation Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: Text(
                      'Home Screen par Wapas Jayein',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor.withOpacity(0.7),
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

  Widget _avatarColumn(String name, int score, bool isMe) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: isMe ? const Color(0xFF4F46E5) : const Color(0xFFF59E0B),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        Text(
          '$score / 10',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isMe ? const Color(0xFF4F46E5) : const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

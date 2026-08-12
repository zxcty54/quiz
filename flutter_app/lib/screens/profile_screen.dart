import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_stats_service.dart';
import 'saved_questions_screen.dart';
import 'wrong_questions_screen.dart';
import 'saved_current_affairs_screen.dart'; // 👈 NEW VAULT SCREEN IMPORT

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

  @override
  void initState() {
    super.initState();
    _loadSavedNewsCount();
  }

  // 💾 FETCH SAVED CA COUNT FROM LOCAL STORAGE
  Future<void> _loadSavedNewsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('saved_daily_bulletins');
    if (savedJson != null) {
      try {
        final List parsed = jsonDecode(savedJson);
        if (mounted) {
          setState(() {
            _savedCaCount = parsed.length;
          });
        }
      } catch (e) {
        debugPrint("Error loading saved news count in Profile: $e");
      }
    } else {
      if (mounted) {
        setState(() {
          _savedCaCount = 0;
        });
      }
    }
  }

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
        if (maxCount == 0) maxCount = 1;

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

                  // 📌 SAVED CURRENT AFFAIRS VAULT (OPENS SCREEN DIRECTLY)
                  ListTile(
                    leading: const Text('📌', style: TextStyle(fontSize: 20)),
                    title: const Text('Saved Current Affairs Vault', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('$_savedCaCount Saved Bulletins', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SavedCurrentAffairsScreen()),
                      );
                      _loadSavedNewsCount(); // Back aane par count update ho jayega
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

            // 🤝 COMMUNITY DONATION WIDGET
            DonationWidget(isDarkMode: widget.isDarkMode),
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
}

// ---------------------------------------------------------------------------
// 🤝 COMMUNITY DONATION WIDGET (AUTO UPI & QR CODE INTERACTIVE FLOW)
// ---------------------------------------------------------------------------
class DonationWidget extends StatefulWidget {
  final bool isDarkMode;
  const DonationWidget({super.key, required this.isDarkMode});

  @override
  State<DonationWidget> createState() => _DonationWidgetState();
}

class _DonationWidgetState extends State<DonationWidget> {
  // 📌 APNI UPI ID YAHAN PASTE KAREIN
  static const String upiId = "YOUR_UPI_ID_HERE@upi";
  static const String payeeName = "MockTester Student Fund";

  int _selectedAmount = 30; // Default ₹30
  bool _isCustom = false;
  final TextEditingController _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  // 🚀 UPI PAYMENT TRIGGER
  Future<void> _processUpiPayment() async {
    final int amount = _isCustom
        ? (int.tryParse(_customAmountController.text) ?? 10)
        : _selectedAmount;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount!')),
      );
      return;
    }

    final String upiUri =
        "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent('MockTester Community Fund')}";

    final Uri uri = Uri.parse(upiUri);

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showQrCodeDialog(amount);
      }
    } catch (_) {
      _showQrCodeDialog(amount);
    }
  }

  // 🖼️ QR CODE DIALOG FOR ALTERNATIVE PAYMENT
  void _showQrCodeDialog(int amount) {
    final String upiUri =
        "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent('MockTester Community Fund')}";
    final String qrApiUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiUri)}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(
              'Scan & Pay ₹$amount 📲',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'GPay, PhonePe, Paytm ya BHIM se scan karein',
              style: TextStyle(
                fontSize: 11.5,
                color: widget.isDarkMode ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Image.network(
                qrApiUrl,
                width: 180,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.grey),
                    Text('QR Code unavailable', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'UPI: $upiId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: upiId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UPI ID copied to clipboard!')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Copy',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentAmount = _isCustom
        ? (int.tryParse(_customAmountController.text) ?? 0)
        : _selectedAmount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1917) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF443631) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(widget.isDarkMode ? 0.1 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFFF97316)),
                SizedBox(width: 6),
                Text(
                  'COMMUNITY FUNDED PLATFORM',
                  style: TextStyle(
                    color: Color(0xFFFB923C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🎯 TITLE & DESC
          Text(
            'Help Us Keep MockTester 100% Free ❤️',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: widget.isDarkMode ? const Color(0xFFFAFAF9) : const Color(0xFF78350F),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hum education par ₹499/yr paywalls nahi lagate. Apna contribution choose karein aur Bihar ke rural aspirants ke liye high-quality tests free rakhne mein madad karein.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: widget.isDarkMode ? const Color(0xFFD6D3D1) : const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 16),

          // 📊 METER CARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF141110) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isDarkMode ? const Color(0xFF3B2D29) : const Color(0xFFFDE68A),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Server Fund Goal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      '₹420 / ₹1,500',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    value: 0.42,
                    minHeight: 7,
                    backgroundColor: Color(0xFF26201E),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
                  ),
                ),
                const SizedBox(height: 6),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('42% Funded This Month', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('58% Remaining', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 💰 PRESET CHIPS
          Text(
            'Select Contribution Amount:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? const Color(0xFFD6D3D1) : const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildAmountChip(30, '₹30'),
              const SizedBox(width: 6),
              _buildAmountChip(50, '₹50'),
              const SizedBox(width: 6),
              _buildAmountChip(100, '₹100'),
              const SizedBox(width: 6),
              _buildCustomChip(),
            ],
          ),

          if (_isCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Enter Custom Amount in ₹',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF97316)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),

          // 💳 DONATE BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processUpiPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                elevation: 3,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volunteer_activism_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Donate ₹$currentAmount via UPI',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(int amount, String label) {
    final bool isSelected = !_isCustom && _selectedAmount == amount;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAmount = amount;
            _isCustom = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF97316)
                : (widget.isDarkMode ? const Color(0xFF26201E) : const Color(0xFFFEF3C7)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF97316) : const Color(0xFFFDE68A),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white : const Color(0xFF92400E)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomChip() {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _isCustom = true;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isCustom
                ? const Color(0xFFF97316)
                : (widget.isDarkMode ? const Color(0xFF26201E) : const Color(0xFFFEF3C7)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isCustom ? const Color(0xFFF97316) : const Color(0xFFFDE68A),
            ),
          ),
          child: Text(
            'Custom',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: _isCustom ? Colors.white : (widget.isDarkMode ? Colors.white : const Color(0xFF92400E)),
            ),
          ),
        ),
      ),
    );
  }
}

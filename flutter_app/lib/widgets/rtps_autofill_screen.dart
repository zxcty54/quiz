import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'exam_photo_resizer_screen.dart';
import 'rtps_universal_setup_screen.dart';

class RtpsAutofillScreen extends StatefulWidget {
  final bool isDark;
  const RtpsAutofillScreen({super.key, required this.isDark});

  @override
  State<RtpsAutofillScreen> createState() => _RtpsAutofillScreenState();
}

class _RtpsAutofillScreenState extends State<RtpsAutofillScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  // 🔗 Direct Official Bihar RTPS Gateway
  static final Uri _rtpsUrl = Uri.parse('https://serviceonline.bihar.gov.in/');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rtps_universal_profile');
    if (raw != null && raw.isNotEmpty) {
      try {
        setState(() {
          _profile = jsonDecode(raw) as Map<String, dynamic>;
        });
      } catch (e) {
        debugPrint("Error parsing profile: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  // ⚡ Official In-App Chrome Custom Tab Launcher (No ERR_CONNECTION_RESET, No Banners)
  Future<void> _launchInAppChrome() async {
    try {
      final launched = await launchUrl(
        _rtpsUrl,
        mode: LaunchMode.inAppBrowserView, // Phone ke asli Chrome engine par app ke andar khulega
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );

      if (!launched) {
        // Fallback to standard external browser if custom tabs not supported
        await launchUrl(_rtpsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portal open karne me samasya: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $label copy ho gaya: $value'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFB45309))),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RTPS FastFill Assistant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text('Bihar ServicePlus Official Portal', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFFB45309)),
            tooltip: 'Profile Edit Karein',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RtpsUniversalSetupScreen(isDark: isDark)),
              );
              if (updated == true) _loadProfile();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🚀 Primary Launch Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Official Chrome Engine',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bina kisi connection reset ya app promotion ke official Bihar portal turant open karein.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _launchInAppChrome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF15803D),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                  label: const Text(
                    'RTPS Portal Kholein ⚡',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tools Action Bar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExamPhotoResizerScreen(isDark: isDark)),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFB45309)),
                    foregroundColor: const Color(0xFFB45309),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.photo_size_select_large_rounded, size: 18),
                  label: const Text('Photo Resize (< 50KB)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RtpsUniversalSetupScreen(isDark: isDark)),
                    );
                    if (updated == true) _loadProfile();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: isDark ? Colors.white38 : Colors.grey.shade400),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fast Copy Deck
          const Text(
            'Quick 1-Tap Copy Deck (Form bhedte waqt kaam aayega):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),

          if (_profile == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('Master Profile abhi set nahi hai.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RtpsUniversalSetupScreen(isDark: isDark)),
                      );
                      if (updated == true) _loadProfile();
                    },
                    child: const Text('Abhi Setup Karein ➔', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            _buildCopyDeck(cardBg),
        ],
      ),
    );
  }

  Widget _buildCopyDeck(Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _buildCopyTile('Naam (English)', _profile!['name_en'] ?? ''),
          _buildCopyTile('नाम (Hindi)', _profile!['name_hi'] ?? ''),
          _buildCopyTile("Pita Ka Naam (English)", _profile!['father_en'] ?? ''),
          _buildCopyTile("पिता का नाम (Hindi)", _profile!['father_hi'] ?? ''),
          _buildCopyTile("Mata Ka Naam (English)", _profile!['mother_en'] ?? ''),
          _buildCopyTile("माता का नाम (Hindi)", _profile!['mother_hi'] ?? ''),
          _buildCopyTile('Mobile No', _profile!['mobile'] ?? ''),
          _buildCopyTile('Zila (District)', _profile!['district'] ?? ''),
          _buildCopyTile('Anumandal (Sub-Division)', _profile!['sub_division'] ?? ''),
          _buildCopyTile('Prakhand (Block)', _profile!['block'] ?? ''),
          _buildCopyTile('Gaon / Mohalla', _profile!['village'] ?? ''),
          _buildCopyTile('Dakghar (Post Office)', _profile!['post_office'] ?? ''),
          _buildCopyTile('Pin Code', _profile!['pin_code'] ?? ''),
          _buildCopyTile('Caste (Jati)', _profile!['caste_name'] ?? ''),
          _buildCopyTile('Kul Varshik Aay (Income)', _profile!['income_total'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildCopyTile(String title, String val) {
    if (val.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _copyToClipboard(title, val),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF16A34A)),
            ],
          ),
        ),
      ),
    );
  }
}

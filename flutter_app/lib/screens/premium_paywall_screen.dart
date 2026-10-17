import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_telegram_alert.dart';
import '../services/premium_service.dart';

/// 👑 Premium Paywall — ₹49/month (config se aata hai).
/// Student: UPI se pay -> screenshot lagata hai -> app photo se
/// Ref No khud padhta hai -> request admin ke paas -> Approve par unlock.
class PremiumPaywallScreen extends StatefulWidget {
  final bool isDarkMode;
  const PremiumPaywallScreen({super.key, required this.isDarkMode});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _loading = true;
  Map<String, dynamic> _config = {};
  DateTime? _premiumUntil;
  Map<String, dynamic>? _myRequest;

  File? _screenshot;
  bool _readingPhoto = false;
  bool _submitting = false;
  final TextEditingController _refCtrl = TextEditingController();
  int? _detectedAmount;

  Timer? _pollTimer;

  bool get _isDark => widget.isDarkMode;
  int get _price => (_config['price'] as num?)?.toInt() ?? 49;
  int get _days => (_config['days'] as num?)?.toInt() ?? 30;
  String get _upiId => (_config['upi_id'] ?? '').toString().trim();
  String get _upiName =>
      (_config['upi_name'] ?? 'MockTester').toString().trim();
  bool get _isPremium =>
      _premiumUntil != null && _premiumUntil!.isAfter(DateTime.now());
  String get _requestStatus =>
      (_myRequest?['status'] ?? '').toString().toLowerCase();

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Pending request ho to har 8 sec me khud status check karo
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      if (_requestStatus == 'pending') _refreshStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final config = await PremiumService.getPaymentConfig();
    final until = await PremiumService.fetchPremiumUntil();
    final req = await PremiumService.fetchMyLatestRequest();
    if (!mounted) return;
    setState(() {
      _config = config;
      _premiumUntil = until;
      _myRequest = req;
      _loading = false;
    });
  }

  Future<void> _refreshStatus() async {
    final until = await PremiumService.fetchPremiumUntil();
    final req = await PremiumService.fetchMyLatestRequest();
    if (!mounted) return;
    final wasPending = _requestStatus == 'pending';
    setState(() {
      _premiumUntil = until;
      _myRequest = req;
    });
    if (wasPending && _isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Premium Active ho gaya! Saare Set khul gaye.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  String get _upiUri {
    final params = {
      'pa': _upiId,
      'pn': _upiName,
      'am': _price.toString(),
      'cu': 'INR',
      'tn': 'MockTester Premium $_days din',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }

  Future<void> _openUpiApp() async {
    if (_upiId.isEmpty) return;
    try {
      final ok = await launchUrl(
        Uri.parse(_upiUri),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('UPI app nahi khula. QR scan karke pay karo.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('UPI app nahi mila. QR scan karke pay karo.')),
        );
      }
    }
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (shot == null) return;
      setState(() {
        _screenshot = File(shot.path);
        _readingPhoto = true;
      });
      await _readPhotoText(shot.path);
      if (mounted) setState(() => _readingPhoto = false);
    } catch (e) {
      if (mounted) {
        setState(() => _readingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo nahi lagi: $e')),
        );
      }
    }
  }

  // Photo se Ref No + amount khud padho (student ko likhna na pade)
  Future<void> _readPhotoText(String path) async {
    TextRecognizer? recognizer;
    try {
      recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      final text = result.text;
      _detectedAmount = _extractAmount(text);
      final ref = _extractUpiRef(text);
      if (ref != null && mounted) {
        _refCtrl.text = ref;
      }
    } catch (_) {
      // Photo nahi padh paya — request phir bhi jayegi, admin screenshot dekhega
    } finally {
      await recognizer?.close();
    }
  }

  String? _extractUpiRef(String text) {
    final clean = text.replaceAll('\n', ' ');
    final labeled = RegExp(
      r'(?:UTR|UPI Ref|Ref(?:erence)?\s*No|UPI transaction ID)[^\d]{0,24}(\d{12})',
      caseSensitive: false,
    ).firstMatch(clean);
    if (labeled != null) return labeled.group(1);
    return RegExp(r'\b\d{12}\b').firstMatch(clean)?.group(0);
  }

  int? _extractAmount(String text) {
    final m = RegExp(r'(?:₹|Rs\.?|INR)\s*([0-9]{2,6})', caseSensitive: false)
        .firstMatch(text.replaceAll('\n', ' '));
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  Future<void> _submit() async {
    if (_screenshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pehle payment wala screenshot lagao 📸')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final userId = await PremiumService.currentUserId();
      final url =
          await PremiumService.uploadScreenshot(_screenshot!, userId);
      final result = await PremiumService.submitRequest(
        screenshotUrl: url,
        upiRef: _refCtrl.text,
        amount: _price,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        // Admin ko Telegram par turant khabar
        AdminTelegramAlert.sendPremiumPaymentRequest(
          userName: (result['request']?['user_name'] ?? 'Student').toString(),
          userId: userId,
          amount: _price,
          upiRef: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          screenshotUrl: url,
        );
        setState(() {
          _myRequest = result['request'] as Map<String, dynamic>?;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request bhej di! Admin check karke unlock karenge.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Request nahi gayi'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kuch gadbad hui: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FF);
    final cardBg = _isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('MockTester Premium 👑',
            style: TextStyle(
                color: textColor, fontSize: 16.5, fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStatus,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF92400E), Color(0xFFD97706), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('👑 PREMIUM',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(
                          '₹$_price/month me Sectional Mock ke SAARE Set unlock',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '✅ Set 01 sabke liye free hai\n✅ Premium se Set 02, 03, 04... sab khulenge\n✅ Ek baar liya to saare exam (BPSC, BSSC, SI) ke band set khule',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, height: 1.55),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_isPremium)
                    _statusCard(
                      cardBg,
                      const Color(0xFF16A34A),
                      '🎉 Premium Active Hai!',
                      'Tumhara Premium ${_premiumUntil!.day}/${_premiumUntil!.month}/${_premiumUntil!.year} tak hai '
                          '(${_premiumUntil!.difference(DateTime.now()).inDays + 1} din baki). Saare Set khule hai — jaakar mock do!',
                      textColor,
                      subColor,
                    )
                  else if (_requestStatus == 'pending') ...[
                    _statusCard(
                      cardBg,
                      const Color(0xFFD97706),
                      '⏳ Approval Ka Intezaar Ho Raha Hai',
                      'Tumhari request admin ke paas hai. Payment milte hi Approve hoga aur Set apne aap khul jayenge. '
                          'Ye screen khuli rakho ya thodi der me wapas aao — hum khud check kar rahe hai.',
                      textColor,
                      subColor,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _refreshStatus,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Status Phir Check Karo'),
                      ),
                    ),
                  ] else ...[
                    if (_requestStatus == 'rejected') ...[
                      _statusCard(
                        cardBg,
                        Colors.redAccent,
                        '❌ Pichli Request Reject Hui Thi',
                        'Payment nahi mila tha ya screenshot saaf nahi tha. Sahi se ₹$_price pay karke naya screenshot lagao.',
                        textColor,
                        subColor,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Step 1: Payment
                    _card(cardBg, [
                      _stepTitle('STEP 1 — ₹$_price UPI Se Pay Karo', textColor),
                      const SizedBox(height: 10),
                      if (_upiId.isEmpty)
                        Text(
                          'Payment abhi setup ho raha hai 🙏 Thodi der me phir try karo.',
                          style: TextStyle(color: subColor, fontSize: 12.5),
                        )
                      else ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: QrImageView(
                              data: _upiUri,
                              version: QrVersions.auto,
                              size: 178,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(_upiId,
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.copy_rounded,
                                  size: 17, color: subColor),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _upiId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('UPI ID copy ho gaya')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _openUpiApp,
                            icon: const Icon(Icons.payment_rounded, size: 19),
                            label: Text('UPI App Se Pay Karo ₹$_price',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 13.5)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Upar wala button dabane se PhonePe/GPay ₹$_price bhara hua khulega. Pay karke usi screen ka screenshot le lena.',
                          style: TextStyle(color: subColor, fontSize: 11.5, height: 1.4),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),

                    // Step 2: Screenshot
                    _card(cardBg, [
                      _stepTitle('STEP 2 — Payment Ka Screenshot Lagao', textColor),
                      const SizedBox(height: 10),
                      if (_screenshot != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_screenshot!,
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _readingPhoto ? null : _pickScreenshot,
                          icon: _readingPhoto
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.photo_library_rounded, size: 18),
                          label: Text(_readingPhoto
                              ? 'Photo padh rahe hai...'
                              : (_screenshot == null
                                  ? '📸 Screenshot Lagao'
                                  : 'Dusra Screenshot Lagao')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _refCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 12,
                        decoration: InputDecoration(
                          labelText: 'UPI Ref No. (photo se khud bhar jayega)',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.numbers_rounded, size: 19),
                          helperText: _detectedAmount != null
                              ? 'Photo me ₹$_detectedAmount mila'
                              : 'Na mile to khali chhod do — admin screenshot dekh lega',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: const Text('Request Bhejo — Unlock Karo 🚀',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 13.5)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Request jaate hi Set admin ke check ke baad khul jayenge (aam tor par kuch minute me).',
                        style: TextStyle(color: subColor, fontSize: 11.5, height: 1.4),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stepTitle(String text, Color color) {
    return Text(text,
        style:
            TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900));
  }

  Widget _card(Color bg, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _statusCard(Color bg, Color accent, String title, String body,
      Color textColor, Color subColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: textColor, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(body,
              style: TextStyle(color: subColor, fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}

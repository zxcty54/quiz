import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingWelcomeScreen({super.key, required this.nextScreen});

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentPage = 0;

  static const Color _primaryBlue = Color(0xFF1D4ED8);
  static const Color _biharSaffron = Color(0xFFD97706);
  static const Color _darkNavy = Color(0xFF0F172A);

  final List<Map<String, dynamic>> _featureSlides = [
    // 🏛️ SLIDE 1: CBT MOCK, REVISION HUB & FREE PDF NOTES
    {
      'tag': 'BIHAR GOVT EXAMS • CBT ENGINE',
      'title': 'Exam-Hall Level CBT\nMock & Revision Hub',
      'desc': 'BPSC 70th, BSSC CGL, Bihar SI & Police ke liye live timed CBT tests, static GK revision aur comprehensive free PDF notes.',
      'accentColor': Color(0xFF2563EB),
      'previewType': 'cbt',
      'pills': ['BPSC / BSSC CBT', 'Bilingual (HI/EN)', 'Static GK & PDFs'],
    },

    // 🧠 SLIDE 2: AI WRONG QUESTION VAULT & TRAP DIAGNOSTICS
    {
      'tag': 'DEEP LEARNING DIAGNOSTICS',
      'title': 'AI Wrong Question Vault\n& Examination Traps',
      'desc': 'Galti hone par AI se jaanein examiner ka distractor trap (50-50), aur 1-click mistake drill se zero error achieve karein.',
      'accentColor': Color(0xFFDC2626),
      'previewType': 'vault',
      'pills': ['AI Trap Analysis', '1-Click Re-Quiz', 'Socratic AI Tutor'],
    },

    // 🏫 SLIDE 3: LOCAL COACHING NETWORK & SYLLABUS
    {
      'tag': 'ALL BIHAR CITIES INTEGRATED',
      'title': 'Patna, Gaya, Arrah Coaching\nAb Ek Platform Par',
      'desc': 'Sabhi offline coaching centers ab Mocktester par launch kar rahe hain apne private classroom batches. Plus Raju & Aman Sir ka complete syllabus.',
      'accentColor': Color(0xFF059669),
      'previewType': 'coaching',
      'pills': ['Raju & Aman Sir Prep', 'Local Institute Hub', 'Secret Batch Codes'],
    },

    // 📢 SLIDE 4: COMMUNITY, CURRENT AFFAIRS & VACANCY NOTIFICATIONS
    {
      'tag': 'ASPIRANT ECOSYSTEM',
      'title': 'Daily Current Affairs,\nCommunity & Job Alerts',
      'desc': 'Har subah verified Bihar current affairs, live aspirant community discussions aur latest recruitment notifications sabse pehle.',
      'accentColor': Color(0xFFD97706),
      'previewType': 'community',
      'pills': ['Bihar Daily News', 'Aspirant Hub', 'Fast Job Alerts'],
    },
  ];

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarded', true);
    await prefs.setString('custom_aspirant_name', name);
    await prefs.setString('user_name', name);
    await prefs.setString('user_display_name', name);
    await prefs.setString('student_contact_id', phone.isNotEmpty ? phone : 'N/A');
    await prefs.setString('user_mobile', phone);

    // Clean Mobile Sync directly to Supabase Table
    if (phone.isNotEmpty) {
      try {
        await Supabase.instance.client.from('app_users').upsert({
          'mobile_number': phone,
          'full_name': name,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint("Supabase Onboarding Save Error: $e");
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 Header with Bihar Saffron & Blue Brand Accent
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_biharSaffron, _primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MockTester',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _darkNavy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Bihar Competitive Exam Studio',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_currentPage < _featureSlides.length)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: () {
                        _pageController.animateToPage(
                          _featureSlides.length,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text(
                        'Skip',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                ],
              ),
            ),

            // 📱 Main Carousel & Registration Screen
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  ..._featureSlides.map((s) => _buildVisualFeatureSlide(s)),
                  _buildRegistrationForm(),
                ],
              ),
            ),

            // 📍 Navigation Footer (Slides 1 to 4)
            if (_currentPage < _featureSlides.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dynamic Smooth Dot Expansion
                    Row(
                      children: List.generate(
                        _featureSlides.length + 1,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          height: 6.5,
                          width: _currentPage == index ? 24 : 6.5,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? _primaryBlue : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Row(
                        children: [
                          Text('Next Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🎨 Visual Mockup Cards (In place of flat text)
  Widget _buildVisualFeatureSlide(Map<String, dynamic> slide) {
    final Color accent = slide['accentColor'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // 🖼️ Mockup Graphic Preview Container
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.08), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.2), width: 1.2),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: _buildGraphicByType(slide['previewType'], accent),
          ),
          const SizedBox(height: 18),

          // Upper Tag Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Text(
              slide['tag'],
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.6),
            ),
          ),
          const SizedBox(height: 10),

          // Heading
          Text(
            slide['title'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _darkNavy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            slide['desc'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 14),

          // Highlights Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: (slide['pills'] as List<String>).map((pill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  pill,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🖼️ Realistic In-App Feature Visual Mockups
  Widget _buildGraphicByType(String type, Color color) {
    switch (type) {
      case 'cbt':
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                    child: const Text('⏱️ 14:58 Left', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: const Text('BPSC Mock #04', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Q14. 1857 ki kranti me Jagdishpur se netritva kisne kiya tha?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkNavy)),
              const SizedBox(height: 12),
              _buildMockOptionTile('A', 'Nana Saheb', false),
              const SizedBox(height: 6),
              _buildMockOptionTile('B', 'Veer Kunwar Singh', true),
            ],
          ),
        );

      case 'vault':
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                    child: const Text('⚠️ 50-50 Trap Detected', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                  ),
                  const Spacer(),
                  const Text('AI Diagnostic 🩺', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECDD3))),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Professor\'s Distractor Trap:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                    SizedBox(height: 3),
                    Text('Aapne Champaran ki jagah Kheda date choose kar li. Dono me Gandhiji the par saal alag tha.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF4C0519), height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Fix Error: 1-Click Re-Quiz ➔', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );

      case 'coaching':
        return Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  children: [
                    const CircleAvatar(backgroundColor: Color(0xFF059669), radius: 16, child: Icon(Icons.school, color: Colors.white, size: 16)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sankalp Academy • Patna', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          Text('Target BPSC Batch 2026-27', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                      child: const Text('BATCH #111', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.play_circle_fill_rounded, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Learn with Raju & Aman Sir\nComplete History & Bihar Special Handouts',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, height: 1.3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case 'community':
      default:
        return Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Row(
                  children: [
                    Text('📢', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(child: Text('BSSC 4th Graduate Notification Released • 2,640 Posts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Daily Rapid Quiz: Bihar ke kis jile me Sonpur mela lagta hai?', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF78350F)))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('412 Aspirants Active in Community Feed', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        );
    }
  }

  Widget _buildMockOptionTile(String prefix, String text, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCorrect ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1), width: isCorrect ? 1.4 : 1),
      ),
      child: Row(
        children: [
          Text('$prefix. ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isCorrect ? const Color(0xFF16A34A) : Colors.black87)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal))),
          if (isCorrect) const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
        ],
      ),
    );
  }

  // 📝 User Setup Page: Name (Mandatory) & Mobile Number (Optional + 10 Digits 8/9 prefix)
  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.badge_rounded, color: _primaryBlue, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              "Setup Aspirant Profile 🚀",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkNavy, letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            const Text(
              "Yeh naam aapke CBT test scorecard aur batch rank sheets par display hoga.",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Full Name (Mandatory)
                  Row(
                    children: const [
                      Text("Full Name", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _darkNavy)),
                      Text(" *", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Anand Sharma',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: _primaryBlue, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Kripya apna naam enter karein!';
                      if (val.trim().length < 2) return 'Kam se kam 2 characters ka naam daalein';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Mobile Number (Sirf Mobile No, Optional + 10 Digits & 8/9 Starts)
                  Row(
                    children: const [
                      Text("Mobile Number", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _darkNavy)),
                      SizedBox(width: 6),
                      Text("(Optional)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g. 9876543210 (Classroom sync ke liye)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null; // Optional

                      final clean = val.trim();
                      final regex = RegExp(r'^[89]\d{9}$');

                      if (!regex.hasMatch(clean)) {
                        if (!clean.startsWith('8') && !clean.startsWith('9')) {
                          return 'Number 9 ya 8 se shuru hona chahiye';
                        }
                        if (clean.length != 10) {
                          return 'Poora 10-digit number enter karein';
                        }
                        return 'Kripya valid 10-digit mobile number daalein';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _completeOnboarding,
                child: const Text('Start Preparation 🚀', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                '🔒 No OTP required • Instant Access to Mocks & Vault',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

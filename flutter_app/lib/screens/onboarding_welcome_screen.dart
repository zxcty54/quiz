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
  String _selectedExamFilter = 'ALL';

  static const Color _primaryBlue = Color(0xFF1E56D0);
  static const Color _cardBorderColor = Color(0xFFD6E4FF);
  static const Color _bgSoftBlue = Color(0xFFF1F6FE);
  static const Color _textDark = Color(0xFF132238);

  final List<Map<String, String>> _examFilters = [
    {'id': 'ALL', 'label': 'Sabhi Exams (All)'},
    {'id': 'BPSC', 'label': 'BPSC & BSSC'},
    {'id': 'BIHAR_SI', 'label': 'Bihar SI & Police'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'RLY', 'label': 'RRB NTPC & Group D'},
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

    if (phone.isNotEmpty) {
      try {
        await Supabase.instance.client.from('app_users').upsert({
          'mobile_number': phone,
          'full_name': name,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint("Supabase Onboarding Sync error: $e");
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
    const int totalSlides = 4; // 3 Showcase slides + 1 Profile setup slide

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 TOP BRAND HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'MockTester',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: _textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CBT',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Smart CBT Prep Platform',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_currentPage < 3)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: Color(0xFFCBD5E1), style: BorderStyle.solid),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                      onPressed: () {
                        _pageController.animateToPage(
                          3,
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

            // 🏷️ EXAM CATEGORY HORIZONTAL PILLS
            SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _examFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, idx) {
                  final f = _examFilters[idx];
                  final bool isSelected = _selectedExamFilter == f['id'];

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _selectedExamFilter = f['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF172554) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF172554) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // 📱 MAIN CAROUSEL (3 SHOWCASE PAGES + 1 SETUP FORM)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildExamHallCbtSlide(),
                  _buildCoachingNetworkSlide(),
                  _buildFeaturesOverviewSlide(),
                  _buildProfileSetupSlide(),
                ],
              ),
            ),

            // 📍 BOTTOM FOOTER (SLIDE COUNT & NAVIGATION)
            if (_currentPage < 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slide ${_currentPage + 1} of 4',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: List.generate(
                        totalSlides,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          height: 5.5,
                          width: _currentPage == index ? 22 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? _primaryBlue : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Row(
                        children: [
                          Text('Swipe ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
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

  // 1️⃣ SLIDE 1: EXACT EXAM-HALL CBT EXPERIENCE
  Widget _buildExamHallCbtSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgSoftBlue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorderColor, width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCEBFE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: _primaryBlue, size: 8),
                  SizedBox(width: 6),
                  Text(
                    '100% NTA & TCS Pattern',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _primaryBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hero Center Graphic Box
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                boxShadow: [
                  BoxShadow(color: _primaryBlue.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(Icons.laptop_chromebook_rounded, color: _primaryBlue, size: 60),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'TCS Engine',
                        style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Exact Exam-Hall CBT Experience',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Exact timer countdown, sectional navigation, real negative marking & live All-India percentile rank.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Benefit Tags
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildSmallPill('⚡ Instant Score Analysis'),
                _buildSmallPill('📊 AIR #1 Benchmark'),
                _buildSmallPill('🎯 Latest 2026-27 Interface'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2️⃣ SLIDE 2: COACHING INTEGRATION USP
  Widget _buildCoachingNetworkSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgSoftBlue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorderColor, width: 1.2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🎯 Coaching Integration USP',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🏫 1,000+ Verified Centers',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mock Classroom Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔑 Enter Batch Code: #PATNA99',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _textDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _primaryBlue, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Connected',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCoachingRow('LA', 'Lakshya Academy', 'Patna, Bihar • 4.2k Batch Students', 'CBT Live', const Color(0xFF2563EB)),
                  const Divider(height: 12),
                  _buildCoachingRow('SC', 'Sankalp Classes', 'Gaya & Sikar • BPSC & SSC Series', 'Verified', const Color(0xFF16A34A)),
                  const Divider(height: 12),
                  _buildCoachingRow('PS', 'Pioneer Study Hub', 'Arrah & Patna • Daily Handouts', 'Test #14', const Color(0xFFD97706)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Aapki City Ki Famous Coaching Ab MockTester Pe!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: _textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Local institute test series directly on MockTester TCS engine. Zero tech hassle: study in classroom, practice on real exam software.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // 3️⃣ SLIDE 3: ALL-IN-ONE APP FEATURES OVERVIEW
  Widget _buildFeaturesOverviewSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgSoftBlue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorderColor, width: 1.2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text("India's 1st Smart CBT Prep App 🎯",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text("AIR #1 Ready",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ),
              ],
            ),
            const SizedBox(height: 10),

            const Text(
              'Aapki Manzil, MockTester Ka Sankalp',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'All-in-one CBT Mocks, AI Question Vault, Top Coaching & Learn with Raju and Aman Sir ek hi jagah!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
            ),
            const SizedBox(height: 12),

            // Metric Counters Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('★ 4.9/5', 'Top Rated'),
                _buildMetricCol('2.5 Lakh+', 'Aspirants'),
                _buildMetricCol('1,000+', 'Institutes'),
              ],
            ),
            const SizedBox(height: 14),

            // Feature List Cards
            _buildFeaturePreviewTile(
              icon: Icons.computer_rounded,
              iconBg: const Color(0xFF2563EB),
              title: 'Real CBT Simulation',
              badgeText: 'TCS Engine',
              desc: 'Exact countdown timers, negative penalties & live percentiles.',
            ),
            const SizedBox(height: 8),
            _buildFeaturePreviewTile(
              icon: Icons.psychology_alt_rounded,
              iconBg: const Color(0xFFD97706),
              title: 'AI Trap Detector & Vault',
              badgeText: 'AI Powered',
              desc: 'Analyze recurring negative marks, silly traps & 50-50 elimination.',
            ),
            const SizedBox(height: 8),
            _buildFeaturePreviewTile(
              icon: Icons.school_rounded,
              iconBg: const Color(0xFF059669),
              title: 'Classroom Batches & Free PDFs',
              badgeText: 'Live Feed',
              desc: 'Local coaching batch tests, Raju & Aman Sir syllabus & study notes.',
            ),
          ],
        ),
      ),
    );
  }

  // 4️⃣ SLIDE 4: REGISTRATION FORM (NAME MANDATORY & MOBILE OPTIONAL VALIDATED)
  Widget _buildProfileSetupSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            const SizedBox(height: 12),
            const Text(
              "Setup Aspirant Profile 🚀",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _textDark, letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            const Text(
              "Yeh details aapke CBT test scorecard aur batch rank sheets par display hongi.",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),

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
                  // Full Name Field (Mandatory)
                  Row(
                    children: const [
                      Text("Full Name", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark)),
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

                  // Mobile Number Field (Optional, 10 Digits & Starts with 8/9)
                  Row(
                    children: const [
                      Text("Mobile Number", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark)),
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
                      hintText: 'e.g. 9876543210 (Classroom batch alerts)',
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
            const SizedBox(height: 20),

            // Start Preparation Action Button
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
                '🔒 No OTP required • Direct Instant Access',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 HELPER WIDGETS
  Widget _buildSmallPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
    );
  }

  Widget _buildCoachingRow(String initials, String name, String sub, String tag, Color tagColor) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _textDark)),
              Text(sub, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
          child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagColor)),
        ),
      ],
    );
  }

  Widget _buildMetricCol(String val, String lbl) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _textDark)),
        Text(lbl, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFeaturePreviewTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String badgeText,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconBg.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconBg, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(color: iconBg.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(badgeText, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: iconBg)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

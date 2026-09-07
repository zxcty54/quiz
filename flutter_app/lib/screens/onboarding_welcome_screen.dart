import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingWelcomeScreen({
    super.key,
    this.nextScreen = const HomeScreen(),
  });

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentSlide = 0;
  String _selectedExam = 'ALL';
  String _batchCodeInput = '#PATNA99';
  String _selectedHub = 'Patna';

  static const Color _primaryBlue = Color(0xFF0037B0);
  static const Color _textDark = Color(0xFF131B2E);
  static const Color _saffronAccent = Color(0xFFFEA619);
  static const Color _saffronDark = Color(0xFF855300);
  static const Color _borderColor = Color(0xFFC4C5D7);
  static const Color _bgSoft = Color(0xFFFAF8FF);

  final List<Map<String, String>> _examTabs = [
    {'id': 'ALL', 'label': 'Sabhi Exams (All)'},
    {'id': 'BPSC', 'label': 'BPSC & BSSC'},
    {'id': 'BIHAR_SI', 'label': 'Bihar SI & Police'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'IBPS', 'label': 'IBPS & SBI PO'},
  ];

  final List<String> _topHubs = ['Patna', 'Mukherjee Nagar', 'Prayagraj', 'Jaipur', 'Indore', 'Kota'];

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    // 1. Save Locally (Profile screen sync)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarded', true);
    await prefs.setString('custom_aspirant_name', name);
    await prefs.setString('user_name', name);
    await prefs.setString('user_display_name', name);
    await prefs.setString('student_contact_id', phone.isNotEmpty ? phone : 'N/A');
    await prefs.setString('user_mobile', phone);

    // 2. Direct clean sync to Supabase app_users table
    if (phone.isNotEmpty) {
      try {
        await Supabase.instance.client.from('app_users').upsert({
          'mobile_number': phone,
          'full_name': name,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint("Supabase Onboarding Save Warning: $e");
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
      backgroundColor: _bgSoft,
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
                          color: const Color(0xFF1D4ED8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
                                  color: _saffronAccent.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _saffronAccent.withOpacity(0.35)),
                                ),
                                child: const Text(
                                  'CBT',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _saffronDark),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Smart CBT Prep Platform',
                            style: TextStyle(fontSize: 10, color: Color(0xFF434655), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_currentSlide < 5)
                    InkWell(
                      onTap: () {
                        _pageController.animateToPage(
                          5,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E7FF).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF434655)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 🏷️ EXAM CATEGORY HORIZONTAL FILTER PILLS
            SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _examTabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, idx) {
                  final tab = _examTabs[idx];
                  final bool isSelected = _selectedExam == tab['id'];

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _selectedExam = tab['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF131B2E) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        tab['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF434655),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // 📱 5-SLIDE CAROUSEL + FINAL PROFILE FORM
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentSlide = idx),
                children: [
                  _buildSlide1TcsSimulation(),
                  _buildSlide2AiTrapDetector(),
                  _buildSlide3CoachingHub(),
                  _buildSlide4FacultyRajuAman(),
                  _buildSlide5DailyPractice(),
                  _buildSlide6ProfileSetup(),
                ],
              ),
            ),

            // 📍 BOTTOM CAROUSEL PROGRESS & CTA STRIP (Slides 1 to 5)
            if (_currentSlide < 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slide ${_currentSlide + 1} of 5 • ${_getSlideCategoryLabel()}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF434655), fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: List.generate(
                            6,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              height: 5.5,
                              width: _currentSlide == index ? 22 : 6,
                              decoration: BoxDecoration(
                                color: _currentSlide == index ? _primaryBlue : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Row(
                            children: [
                              Text('Swipe', style: TextStyle(fontSize: 11, color: Color(0xFF434655), fontWeight: FontWeight.bold)),
                              Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF434655)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Primary Get Started CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentSlide == 2 ? 'Join Your Coaching Batch' : 'Next / Aage Badhein',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Rating & Social Proof
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('⭐ 4.9/5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFEA619))),
                        SizedBox(width: 4),
                        Text(
                          '(1,000+ Institutes • 2.5 Lakh+ Aspirants)',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF434655)),
                        ),
                      ],
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
  Widget _buildSlide1TcsSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE1FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF0037B0), size: 14),
                  SizedBox(width: 6),
                  Text('100% NTA & TCS Pattern', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF001551))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hero Graphic Box with TCS Engine Pill
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEAEDFF), Color(0xFFF2F3FF), Color(0xFFDCE1FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.laptop_chromebook_rounded, size: 75, color: Color(0xFF0037B0)),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _saffronAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('TCS Engine', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF684000))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Exact Exam-Hall CBT Experience',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Exact timer countdown, sectional navigation, real negative marking & live All-India percentile rank.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF434655), height: 1.4),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildPillTag(Icons.bolt, 'Instant Score Analysis'),
                _buildPillTag(Icons.trending_up, 'AIR #1 Benchmark'),
                _buildPillTag(Icons.check_circle_outline, 'Latest 2026 Interface'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2️⃣ SLIDE 2: AI TRAP DETECTOR & VAULT
  Widget _buildSlide2AiTrapDetector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _saffronAccent.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF855300), size: 14),
                  SizedBox(width: 6),
                  Text('AI Powered Analysis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF684000))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_saffronAccent.withOpacity(0.2), const Color(0xFFE2E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _saffronAccent.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _saffronAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF684000))),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _saffronAccent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Colors.red),
                        SizedBox(width: 4),
                        Text('Trap Discovered!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Negative Marks Ko Zero Karein',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Analyze recurring silly mistakes & tricky examiner traps automatically with AI-backed step-by-step logic.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF434655), height: 1.4),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildPillTag(Icons.security, 'Exam Trap Detector'),
                _buildPillTag(Icons.menu_book, 'Personalized Vault'),
                _buildPillTag(Icons.check_circle_outline, 'Step-by-Step Logic'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3️⃣ SLIDE 3: COACHING INTEGRATION USP (Matching Screenshot 1)
  Widget _buildSlide3CoachingHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(color: const Color(0xFFDCE1FF), borderRadius: BorderRadius.circular(16)),
                  child: const Text('🎯 Coaching Integration USP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF001551))),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(16)),
                  child: const Text('🏫 1,000+ Verified Centers', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD6E4FF)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primaryBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 14, color: _primaryBlue),
                            const SizedBox(width: 4),
                            const Text('Enter Batch Code: ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _textDark)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFEAEDFF), borderRadius: BorderRadius.circular(4)),
                              child: Text(_batchCodeInput, style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: _primaryBlue)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _primaryBlue, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Connected', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildInstituteTile('LA', 'Lakshya Academy', 'Patna, Bihar • 4.2k Batch Students', 'CBT Live', const Color(0xFF2563EB)),
                  const SizedBox(height: 6),
                  _buildInstituteTile('SC', 'Sankalp Classes', 'Gaya & Sikar • BPSC & SSC Series', 'Verified', const Color(0xFF16A34A)),
                  const SizedBox(height: 6),
                  _buildInstituteTile('PS', 'Pioneer Study Hub', 'Arrah & Patna • Daily Handouts', 'Test #14', const Color(0xFFD97706)),

                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      const Text('Top Hubs: ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF434655))),
                      ..._topHubs.map((hub) => InkWell(
                            onTap: () => setState(() {
                              _selectedHub = hub;
                              _batchCodeInput = '#${hub.toUpperCase().substring(0, hub.length > 5 ? 5 : hub.length)}99';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedHub == hub ? _primaryBlue : const Color(0xFFEAEDFF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                hub,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedHub == hub ? Colors.white : const Color(0xFF434655),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Aapki City Ki Famous Coaching Ab MockTester Pe!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: _textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Local institute test series directly on MockTester TCS engine. Teachers upload mock papers easily; students practice on real exam software!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF434655), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  // 4️⃣ SLIDE 4: RAJU & AMAN SIR SYLLABUS
  Widget _buildSlide4FacultyRajuAman() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Top Expert Faculty 👨‍🏫', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF93000A))),
            ),
            const SizedBox(height: 16),

            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _primaryBlue.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 22, backgroundColor: _primaryBlue, child: const Text('Raju', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                      const SizedBox(width: 8),
                      CircleAvatar(radius: 22, backgroundColor: _saffronDark, child: const Text('Aman', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Daily Live Classes', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _textDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Learn Full Syllabus with Raju & Aman Sir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Daily live concept masterclasses, shortcut trick cheat-sheets, and 10-year free PYQs & notes PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF434655), height: 1.4),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildPillTag(Icons.calculate, 'Raju Sir (Maths & Reasoning)'),
                _buildPillTag(Icons.public, 'Aman Sir (GK & GS)'),
                _buildPillTag(Icons.download, 'Free PYQ Downloads'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 5️⃣ SLIDE 5: DAILY PRACTICE & JOBS
  Widget _buildSlide5DailyPractice() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDDB8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Daily Smart Prep ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2A1700))),
            ),
            const SizedBox(height: 16),

            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _saffronAccent.withOpacity(0.3)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active_rounded, size: 48, color: Color(0xFFD97706)),
                  SizedBox(height: 8),
                  Text('Aspirant Adda 24x7', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textDark)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Daily GK Capsule & Sarkari Alerts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Rapid-fire 10-min flashcards, bilingual current affairs, topper peer discussion adda & instant exam alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF434655), height: 1.4),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildPillTag(Icons.newspaper, 'Daily Bilingual GK'),
                _buildPillTag(Icons.campaign, 'Real-Time Job Alerts'),
                _buildPillTag(Icons.forum, 'Doubt Community'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 6️⃣ SLIDE 6: PROFILE SETUP FORM (Full Name Mandatory + Strict Mobile)
  Widget _buildSlide6ProfileSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.badge_rounded, color: _primaryBlue, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              "Setup Aspirant Profile 🚀",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark, letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            const Text(
              "Yeh details aapke CBT test scorecard aur batch rank sheets par display hongi.",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Full Name *", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark)),
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
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Kripya apna naam enter karein!';
                      if (val.trim().length < 2) return 'Kam se kam 2 characters ka naam daalein';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text("Mobile Number (Optional)", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark)),
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
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      final clean = val.trim();
                      final regex = RegExp(r'^[89]\d{9}$');
                      if (!regex.hasMatch(clean)) {
                        if (!clean.startsWith('8') && !clean.startsWith('9')) {
                          return 'Number 9 ya 8 se shuru hona chahiye';
                        }
                        if (clean.length != 10) {
                          return 'Poora 10-digit number enter karein';
                        }
                        return 'Kripya valid mobile number enter karein';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

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
          ],
        ),
      ),
    );
  }

  // 🔹 HELPER WIDGETS
  Widget _buildInstituteTile(String initials, String name, String sub, String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.12), child: Text(initials, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFEAEDFF), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _primaryBlue),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _textDark)),
        ],
      ),
    );
  }

  String _getSlideCategoryLabel() {
    switch (_currentSlide) {
      case 0:
        return 'TCS Simulation';
      case 1:
        return 'AI Trap Detector';
      case 2:
        return 'Coaching Hub';
      case 3:
        return 'Live Faculty';
      case 4:
        return 'Daily Practice';
      case 5:
        return 'Aspirant Profile';
      default:
        return '';
    }
  }
}

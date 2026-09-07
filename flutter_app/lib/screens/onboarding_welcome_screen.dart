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
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _currentSlide = 0;
  bool _isLoading = false;
  String _selectedExam = 'ALL';

  // State: Slide 2 (Trap Re-attempt)
  String? _slide2SelectedAnswer = 'D';

  // State: Slide 3 (Coaching Hub)
  String _slide3Persona = 'aspirant';
  String _slide3BatchCode = 'SNK-50';
  String _slide3City = 'Delhi';

  // State: Slide 4 (Faculty Audio)
  bool _slide4IsPlaying = false;
  bool _slide4Downloaded = false;

  // State: Slide 5 (Daily GK)
  int? _slide5SelectedOpt = 0;
  String _slide5Lang = 'hi';

  static const Color _primaryBlue = Color(0xFF0037B0);
  static const Color _textDark = Color(0xFF131B2E);
  static const Color _saffronAccent = Color(0xFFFEA619);
  static const Color _saffronDark = Color(0xFF855300);
  static const Color _borderColor = Color(0xFFC4C5D7);
  static const Color _bgSoft = Color(0xFFFAF8FF);

  final List<Map<String, String>> _examTabs = const [
    {'id': 'ALL', 'label': 'Sabhi Exams (All)'},
    {'id': 'BPSC', 'label': 'BPSC & BSSC'},
    {'id': 'BIHAR_SI', 'label': 'Bihar SI & Police'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'IBPS', 'label': 'IBPS & SBI PO'},
  ];

  Future<void> _completeOnboarding() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
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
          debugPrint("Supabase Onboarding Save Warning: $e");
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } catch (e) {
      debugPrint("Error completing onboarding: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            // Top App Header
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
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _saffronAccent.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _saffronAccent.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Text(
                                  'CBT',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: _saffronDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Smart CBT Prep Platform',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF434655),
                              fontWeight: FontWeight.w600,
                            ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E7FF).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF434655),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Exam Category Tabs
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF131B2E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF131B2E)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        tab['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF434655),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // 5 Visual Slides + Profile Step
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) {
                  FocusScope.of(context).unfocus();
                  setState(() => _currentSlide = idx);
                },
                children: [
                  _buildSlide1TcsSimulation(),
                  _buildSlide2AiTrapDetector(),
                  _buildSlide3CoachingHub(),
                  _buildSlide4FacultyPodcast(),
                  _buildSlide5DailyGKAndAlerts(),
                  _buildSlide6ProfileSetup(),
                ],
              ),
            ),

            // Bottom Carousel Indicator Strip
            if (_currentSlide < 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slide ${_currentSlide + 1} of 5 • ${_getSlideCategoryLabel()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF434655),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              height: 5.5,
                              width: _currentSlide == index ? 22 : 6,
                              decoration: BoxDecoration(
                                color: _currentSlide == index
                                    ? _primaryBlue
                                    : const Color(0xFFCBD5E1),
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
                              Text(
                                'Swipe',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF434655),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: Color(0xFF434655),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                              _currentSlide == 2
                                  ? 'Join Your Coaching Batch'
                                  : _currentSlide == 4
                                      ? 'Start Daily Prep / Get Started'
                                      : 'Next / Aage Badhein',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '⭐ 4.9/5',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFEA619),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(1,000+ Institutes • 2.5 Lakh+ Aspirants)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF434655),
                          ),
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

  // Slide 1: Real CBT Simulation
  Widget _buildSlide1TcsSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
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
                  Text(
                    '100% NTA & TCS Pattern',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001551),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEAEDFF),
                    Color(0xFFF2F3FF),
                    Color(0xFFDCE1FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.laptop_chromebook_rounded,
                    size: 70,
                    color: Color(0xFF0037B0),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: _saffronAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TCS Engine',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF684000),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Exact Exam-Hall CBT Experience',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Exact timer countdown, sectional navigation, real negative marking & live All-India percentile rank.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF434655),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildPillTag(Icons.bolt, 'Instant Score Analysis'),
                _buildPillTag(Icons.trending_up, 'AIR #1 Benchmark'),
                _buildPillTag(Icons.check_circle_outline, 'Latest Interface'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Slide 2: AI Trap Detector
  Widget _buildSlide2AiTrapDetector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: _saffronAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🧠 AI Trap Detector & Vault',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF855300),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✓ Zero Negative Marking',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Examiner Trap Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Examiner Trap Detector',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _textDark,
                                ),
                              ),
                              Text(
                                'Deceptive choices identified by AI',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFF434655),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TRAP ALERT',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Question Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Algebra Trap • SSC CGL Tier-1',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _primaryBlue,
                              ),
                            ),
                            Text(
                              '64% Aspirants Trapped',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'If x + 1/x = -4, then find x³ + 1/x³ = ?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Options
                        Row(
                          children: [
                            Expanded(child: _buildTrapOption('A', '+48', isTrap: true)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildTrapOption('B', '-48', isTrap: true)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _buildTrapOption('C', '+52', isTrap: false)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildTrapOption('D', '-52', isCorrect: true)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Explanation
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⚠️ Why this is a trap:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Sign Inversion Error',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Formula k³ - 3k for k = -4: (-4)³ - 3(-4) = -64 + 12 = -52. Bait options +48 & -48 trap hasty calculations under timer pressure.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF434655),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📁 Personalized Vault',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          'Wrong mocks auto-categorized',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF434655),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔄 Trap Elimination Mode',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          'Practice identical trap variants',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF434655),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrapOption(String id, String label,
      {bool isTrap = false, bool isCorrect = false}) {
    final bool isSelected = _slide2SelectedAnswer == id;
    Color bg = const Color(0xFFF2F3FF);
    Color border = Colors.transparent;
    Color txt = _textDark;

    if (isSelected) {
      if (isCorrect) {
        bg = const Color(0xFFD1FAE5);
        border = Colors.green;
        txt = const Color(0xFF065F46);
      } else {
        bg = Colors.red.shade100;
        border = Colors.red;
        txt = Colors.red.shade900;
      }
    } else if (isCorrect) {
      bg = Colors.green.shade50;
      border = Colors.green.shade300;
      txt = Colors.green.shade900;
    }

    return InkWell(
      onTap: () => setState(() => _slide2SelectedAnswer = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opt $id ($label)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: txt,
              ),
            ),
            if (isCorrect)
              const Text(
                '✓ Ans',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            if (isTrap && isSelected)
              const Text(
                '⚠️ Trap',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Slide 3: Coaching Hub
  Widget _buildSlide3CoachingHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE1FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '📡 Regional Coaching Hub',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001551),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🏫 1,200+ Centers Connected',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Persona Switcher
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _slide3Persona = 'aspirant'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _slide3Persona == 'aspirant'
                              ? _primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🎓 I am an Aspirant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _slide3Persona == 'aspirant'
                                ? Colors.white
                                : const Color(0xFF434655),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _slide3Persona = 'owner'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _slide3Persona == 'owner'
                              ? _primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🏫 Coaching Owner',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _slide3Persona == 'owner'
                                ? Colors.white
                                : const Color(0xFF434655),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (_slide3Persona == 'aspirant')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VERIFIED INSTITUTE CBT PASS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _primaryBlue,
                          ),
                        ),
                        Text(
                          'LIVE CBT PASS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14, color: Color(0xFFCBD5E1)),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _primaryBlue,
                          child: const Text(
                            'LA',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sankalp Career Academy',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _textDark,
                              ),
                            ),
                            Text(
                              'SSC CGL Super-50 | Room B-12',
                              style: TextStyle(
                                fontSize: 10,
                                color: _primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Code: $_slide3BatchCode',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: _primaryBlue,
                            ),
                          ),
                          const Text(
                            'Connected ✓',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEDFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Director & Faculty Admin',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload scanned question papers. MockTester automatically digitizes them into standard TCS exam screens for your batch.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF434655),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Top Hubs
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text(
                  'Top Hubs: ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF434655),
                  ),
                ),
                ...['Delhi', 'Patna', 'Prayagraj', 'Jaipur'].map((city) {
                  final bool isSelected = _slide3City == city;
                  return InkWell(
                    onTap: () => setState(() {
                      _slide3City = city;
                      _slide3BatchCode = '#${city.toUpperCase().substring(0, 4)}99';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryBlue : const Color(0xFFEAEDFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF434655),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Slide 4: Micro-Learning Podcast
  Widget _buildSlide4FacultyPodcast() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEDFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '🎧 Conversational Micro-Learning',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Aman & Raju Pod',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Aman Sir explain karte hain Raju ko bilkul easy style me!',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Complex math & exam traps solved via everyday smart dialogue.',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF434655)),
            ),
            const SizedBox(height: 10),

            // Dialogue Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFC4C5D7).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Episode 42: CI fast calculation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        '2 min 40s',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dialogue 1
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: _saffronDark,
                        child: Text(
                          'R',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Raju: "Sir, CI ke 3-year question me calculation itni lengthy hai, time kaise bachega?"',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _textDark,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Dialogue 2
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: _primaryBlue,
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Aman Sir: "3:3:1 ratio trick lagao Raju, bina formula option elimination se 10s me answer aayega!"',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Player Controls
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _slide4IsPlaying = !_slide4IsPlaying),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: _primaryBlue,
                            child: Icon(
                              _slide4IsPlaying ? Icons.pause : Icons.play_arrow,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          _slide4IsPlaying
                              ? 'Playing Audio Explanation...'
                              : 'Listen & Solve Interactive Clip',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            6,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 3,
                              height: _slide4IsPlaying ? (i % 2 == 0 ? 14 : 7) : 5,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Material PDF Tile
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Handwritten Formula Book & Notes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        '250+ High Quality PDFs • Bilingual',
                        style: TextStyle(fontSize: 9.5, color: Color(0xFF434655)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _slide4Downloaded = true),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _slide4Downloaded ? Icons.check : Icons.download,
                        color: Colors.white,
                        size: 14,
                      ),
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

  // Slide 5: Daily GK & Sarkari Job Alerts
  Widget _buildSlide5DailyGKAndAlerts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _saffronAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(radius: 3.5, backgroundColor: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'LIVE ALERT: SSC CGL 2024 (17,727 Posts)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF684000),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'View PDF',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFC4C5D7).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Current Affairs Capsule',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _slide5Lang = 'en'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _slide5Lang == 'en'
                                    ? _primaryBlue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _slide5Lang == 'en'
                                      ? Colors.white
                                      : _textDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => setState(() => _slide5Lang = 'hi'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _slide5Lang == 'hi'
                                    ? _primaryBlue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'HI',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _slide5Lang == 'hi'
                                      ? Colors.white
                                      : _textDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _slide5Lang == 'en'
                        ? 'Which corridor was launched at G20 to connect India to Europe?'
                        : 'भारत को यूरोप से जोड़ने के लिए G20 में कौन सा कॉरिडोर लॉन्च हुआ?',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _slide5SelectedOpt = 0),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _slide5SelectedOpt == 0
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFF2F3FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _slide5SelectedOpt == 0
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Text(
                              'IMEC Corridor ✓',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _slide5SelectedOpt = 1),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _slide5SelectedOpt == 1
                                  ? Colors.red.shade100
                                  : const Color(0xFFF2F3FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _slide5SelectedOpt == 1
                                    ? Colors.red
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Text(
                              'INSTC Route',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.calculate, size: 14, color: _primaryBlue),
                        Text(
                          'Age Cutoff',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          size: 14,
                          color: _saffronDark,
                        ),
                        Text(
                          'Admit Cards',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.assignment, size: 14, color: Colors.green),
                        Text(
                          'Syllabus Mocks',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Slide 6: Profile Setup Form
  Widget _buildSlide6ProfileSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.badge_rounded,
                color: _primaryBlue,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Setup Aspirant Profile 🚀",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _textDark,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Yeh details aapke CBT test scorecard aur batch rank sheets par display hongi.",
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Full Name *",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Anand Sharma',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: _primaryBlue,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Kripya apna naam enter karein!';
                      }
                      if (val.trim().length < 2) {
                        return 'Kam se kam 2 characters ka naam daalein';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Mobile Number (Optional)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g. 9876543210 (Classroom sync ke liye)',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.grey,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      final clean = val.trim();
                      // Handles valid Indian mobile starting prefix 6, 7, 8, 9
                      final regex = RegExp(r'^[6-9]\d{9}$');
                      if (!regex.hasMatch(clean)) {
                        if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                          return 'Number 6, 7, 8 ya 9 se shuru hona chahiye';
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
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _completeOnboarding,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Preparation 🚀',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _primaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
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

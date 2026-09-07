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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _currentSlide = 0;
  bool _isLoading = false;
  String _selectedExam = 'ALL';
  String _slide3Persona = 'aspirant';

  static const Color _brandBlue = Color(0xFF0044CC);
  static const Color _darkBlueText = Color(0xFF0F1B3E);
  static const Color _accentOrange = Color(0xFFF59E0B);
  static const Color _bgScreen = Color(0xFFF7F9FD);
  static const Color _borderLight = Color(0xFFE2E8F0);

  final List<Map<String, String>> _examTabs = const [
    {'id': 'ALL', 'label': '⚡ Sabhi Exams (All)'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'IBPS', 'label': 'IBPS & SBI PO'},
    {'id': 'BPSC', 'label': 'BPSC & Bihar SI'},
    {'id': 'RLY', 'label': 'RRB NTPC & ALP'},
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

  void _goToSlide(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
      backgroundColor: _bgScreen,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 6),
            _buildExamCategoryChips(),
            const SizedBox(height: 6),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentSlide = idx),
                children: [
                  _buildSlide0OverviewHero(),
                  _buildSlide1TcsInterface(),
                  _buildSlide2AiTrapDetector(),
                  _buildSlide3MistakeVault(),
                  _buildSlide4CoachingBatchPass(),
                  _buildSlide5FinalProfileSetup(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TOP BAR
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _brandBlue,
                  borderRadius: BorderRadius.circular(9),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _darkBlueText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'CBT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Smart CBT Prep Platform',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildTopToggleBadge('Overview', _currentSlide == 0, () => _goToSlide(0)),
              const SizedBox(width: 6),
              _buildTopToggleBadge('Walkthrough', _currentSlide > 0, () {
                if (_currentSlide == 0) _goToSlide(1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopToggleBadge(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _brandBlue : const Color(0xFFE8EEF8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildExamCategoryChips() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _examTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final tab = _examTabs[idx];
          final isSelected = _selectedExam == tab['id'];

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _selectedExam = tab['id']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? _brandBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _brandBlue : _borderLight,
                ),
              ),
              child: Text(
                tab['label']!,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 1️⃣ SLIDE 0: OVERVIEW (PURE CODE ILLUSTRATION)
  Widget _buildSlide0OverviewHero() {
    return _buildSlideCardWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Code-crafted Vector Desk Setup
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 0.9,
                    colors: [
                      Color(0xFFEFF6FF),
                      Color(0xFFE0E7FF),
                      Color(0xFFF1F5F9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Desk Mat Platform
                    Positioned(
                      bottom: 25,
                      child: Container(
                        width: 250,
                        height: 75,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE68A).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                    // Laptop Simulation
                    Positioned(
                      bottom: 40,
                      child: Container(
                        width: 140,
                        height: 90,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _brandBlue.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 28,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Container(
                                  width: 16,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(width: 80, height: 4, color: Colors.white70),
                            const SizedBox(height: 3),
                            Container(width: 60, height: 3, color: Colors.white38),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(width: 40, height: 8, decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(2))),
                                Container(width: 25, height: 8, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Floating Books & Lamp
                    Positioned(
                      left: 20,
                      bottom: 45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 32, height: 8, decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 2),
                          Container(width: 36, height: 8, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 2),
                          Container(width: 40, height: 9, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                    // Floating Trophy
                    const Positioned(
                      right: 25,
                      top: 25,
                      child: Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 36),
                    ),
                    // Student Avatar
                    Positioned(
                      top: 35,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: _brandBlue,
                        child: const Icon(Icons.person, color: Colors.white, size: 34),
                      ),
                    ),
                  ],
                ),
              ),

              // AIR #1 Ready Top Badge
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentOrange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'AIR #1 Ready',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 100% NTA Pattern Bottom Overlay Pill
              Positioned(
                bottom: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                      SizedBox(width: 5),
                      Text(
                        '100% NTA Pattern',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _darkBlueText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Heading and Tagline
          Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _darkBlueText,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(text: 'Aapki Manzil, '),
                    TextSpan(
                      text: 'MockTester',
                      style: TextStyle(color: _brandBlue),
                    ),
                    TextSpan(text: ' Ka\nSankalp'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All-in-one CBT Mocks, AI Question Vault, Top Coaching\n& Expert Mentorship ek hi jagah!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),

          // 3-Column Metrics Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('★ 4.9/5', 'Top Rated', const Color(0xFFD97706)),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildStatItem('2.5 Lakh+', 'Aspirants', _brandBlue),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildStatItem('1,000+', 'Institutes', const Color(0xFF0F766E)),
              ],
            ),
          ),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _goToSlide(1),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explore Walkthrough',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2️⃣ SLIDE 1: REAL TCS CBT SIMULATOR
  Widget _buildSlide1TcsInterface() {
    return _buildSlideCardWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCE6FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: _brandBlue),
                SizedBox(width: 6),
                Text(
                  'Exact TCS Server Sync & Negative Marking (-0.50)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002277),
                  ),
                ),
              ],
            ),
          ),

          // TCS Dark Screen Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: Colors.green),
                        SizedBox(width: 5),
                        Text(
                          'SSC CGL (Tier-1) Mock #01',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top, size: 11, color: Colors.amber),
                          SizedBox(width: 3),
                          Text(
                            '58:42 Left',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brandBlue,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Reasoning (25)',
                        style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('GK/GA (25)', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Text('Quants (25)', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Question 14', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('+2.00 / -0.50', style: TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Find the odd letter pair out of the following given alternatives:',
                            style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          _buildMockTcsOption('[A] BCD : EFG', false),
                          _buildMockTcsOption('[B] FGH : JKL (Saved)', true),
                          _buildMockTcsOption('[C] LMN : OPQ', false),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text('PALETTE 25 QS', style: TextStyle(color: Colors.grey, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                _buildPaletteDot('1', Colors.green),
                                _buildPaletteDot('2', Colors.green),
                                _buildPaletteDot('3', Colors.red),
                                _buildPaletteDot('4', Colors.green),
                                _buildPaletteDot('5', Colors.purple),
                                _buildPaletteDot('6', Colors.green),
                                _buildPaletteDot('7', Colors.green),
                                _buildPaletteDot('8', Colors.red),
                                _buildPaletteDot('14', Colors.green, border: true),
                                _buildPaletteDot('15', Colors.grey),
                                _buildPaletteDot('16', Colors.grey),
                                _buildPaletteDot('17', Colors.purple),
                              ],
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

          Column(
            children: const [
              Text(
                'Asli Exam Hall Jaisa Real CBT Interface!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: _darkBlueText,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Exam se pehle exam ka darr khatam. Same timer, same navigation palette, aur negative mark calculation direct TCS pattern par.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: _buildMiniSpecCard(
                  icon: Icons.language,
                  title: '99.8% NTA Match',
                  subtitle: 'Real exam simulation',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSpecCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Live AIR Percentile',
                  subtitle: 'Rank vs 50k+ aspirants',
                ),
              ),
            ],
          ),

          _buildSliderNavRow(
            onPrev: () => _goToSlide(0),
            onNext: () => _goToSlide(2),
            primaryLabel: 'Launch Live TCS Mock Engine',
          ),
        ],
      ),
    );
  }

  // 3️⃣ SLIDE 2: AI TRAP DETECTOR
  Widget _buildSlide2AiTrapDetector() {
    return _buildSlideCardWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '🧠 AI Trap Detector & Vault',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '✓ Zero Negative Marking',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
              ),
            ],
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.pink, size: 18),
                        SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Examiner Trap Detector',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkBlueText),
                            ),
                            Text(
                              'AI identifies intentionally deceptive answer choices',
                              style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TRAP ALERT',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Algebra Trap Sample • SSC CGL Tier-1',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _brandBlue),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '64% Aspirants Trapped',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'If x + 1/x = -4, then find x³ + 1/x³ = ?',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkBlueText),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(child: _buildTrapChoiceTile('Option A (+48)', false)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildTrapChoiceTile('Option B (-48)', false)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildTrapChoiceTile('Option C (+52)', false)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildTrapChoiceTile('Option D (-52)', true)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCCD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '⚠️ Why this is a trap:',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFBE123C)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Sign Inversion Error',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF9F1239)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Using identity (k³ - 3k) for k = -4: (-4)³ - 3(-4) = -64 + 12 = -52. Examiners purposely place +48 and -48 as bait options knowing students misapply negative brackets under timer pressure.',
                        style: TextStyle(fontSize: 9.5, color: Color(0xFF475569), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Color(0xFF0F766E)),
                    SizedBox(width: 5),
                    Text(
                      'Auto-saved in your Mistake Vault',
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.refresh, size: 12),
                  label: const Text('Re-attempt Trap', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          _buildSliderNavRow(
            onPrev: () => _goToSlide(1),
            onNext: () => _goToSlide(3),
            primaryLabel: 'Next: Mistake Vault',
          ),
        ],
      ),
    );
  }

  // 4️⃣ SLIDE 3: MISTAKE VAULT & ZERO NEGATIVE MARKS
  Widget _buildSlide3MistakeVault() {
    return _buildSlideCardWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCE6F5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.folder_open_rounded, color: _accentOrange, size: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Auto Sync', style: TextStyle(fontSize: 8.5, color: _brandBlue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Personalized Mistake Vault', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkBlueText)),
                      const SizedBox(height: 4),
                      const Text('Har mock test ke wrong questions automatically categorized', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCE6F5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.autorenew_rounded, color: _brandBlue, size: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Zero Negatives', style: TextStyle(fontSize: 8.5, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Trap Elimination Mode', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkBlueText)),
                      const SizedBox(height: 4),
                      const Text('Practice identical trap variants until accuracy reaches 100%', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Column(
            children: const [
              Text(
                'Negative Marks Ko Zero Karein',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _darkBlueText,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Analyze recurring silly mistakes & tricky examiner traps automatically with AI-backed step-by-step logic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.redAccent, size: 14),
                    SizedBox(width: 4),
                    Text('Exam Trap Detector', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _darkBlueText)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: _brandBlue, size: 14),
                    SizedBox(width: 4),
                    Text('Personalized Vault', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _darkBlueText)),
                  ],
                ),
              ),
            ],
          ),

          _buildSliderNavRow(
            onPrev: () => _goToSlide(2),
            onNext: () => _goToSlide(4),
            primaryLabel: 'Next: Coaching Hub',
          ),
        ],
      ),
    );
  }

  // 5️⃣ SLIDE 4: COACHING INTEGRATION BATCH PASS
  Widget _buildSlide4CoachingBatchPass() {
    return _buildSlideCardWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('📡 Regional Coaching Hub', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandBlue)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('• Live City Radar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
              ),
            ],
          ),

          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
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
                        color: _slide3Persona == 'aspirant' ? _brandBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '🎓 I am an Aspirant',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _slide3Persona == 'aspirant' ? Colors.white : const Color(0xFF475569),
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
                        color: _slide3Persona == 'owner' ? _brandBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '🏫 Coaching Owner',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _slide3Persona == 'owner' ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront, color: _brandBlue, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'VERIFIED INSTITUTE CBT PASS',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _brandBlue),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Text('LIVE CBT PASS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _brandBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('LA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sankalp Career Aca... (Jaipur)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkBlueText)),
                          Text('👥 SSC CGL Super-50 | Room B-12', style: TextStyle(fontSize: 10, color: _brandBlue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.qr_code_2_rounded, size: 28, color: Color(0xFF475569)),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(radius: 3.5, backgroundColor: Colors.green),
                          SizedBox(width: 5),
                          Text('Active Live Test: Full Mock #14 (T...', style: TextStyle(fontSize: 9.5, color: _darkBlueText, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(4)),
                        child: const Text('TCS UI', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                const Text('ENTER 6-DIGIT BATCH CODE:', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.key, size: 14, color: Colors.grey),
                            SizedBox(width: 6),
                            Text('SNK-50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _darkBlueText)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
                        child: const Text('Verify ✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LIVE CITY RADAR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _darkBlueText)),
                  Text('1,200+ Centers Connected', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCityChip('Mukherjee Nagar (Delhi)', true),
                    const SizedBox(width: 6),
                    _buildCityChip('Patna (Boring Rd)', false),
                    const SizedBox(width: 6),
                    _buildCityChip('Prayagraj', false),
                  ],
                ),
              ),
            ],
          ),

          _buildSliderNavRow(
            onPrev: () => _goToSlide(3),
            onNext: () => _goToSlide(5),
            primaryLabel: 'Create Profile & Get Started',
          ),
        ],
      ),
    );
  }

  // 6️⃣ SLIDE 5: MANDATORY ONBOARDING FORM
  Widget _buildSlide5FinalProfileSetup() {
    return _buildSlideCardWrapper(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_rounded, color: _brandBlue, size: 26),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Setup Aspirant Profile 🚀",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _darkBlueText,
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
              ],
            ),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Full Name *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkBlueText)),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Anand Sharma',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: _brandBlue, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Kripya apna naam enter karein!';
                      if (val.trim().length < 2) return 'Kam se kam 2 characters ka naam daalein';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text("Mobile Number (Optional)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkBlueText)),
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
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.grey, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      final clean = val.trim();
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

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  foregroundColor: Colors.white,
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _completeOnboarding,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Start Preparation 🚀', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SHARED REUSABLE COMPONENTS
  Widget _buildSlideCardWrapper({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
            child: IntrinsicHeight(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliderNavRow({
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required String primaryLabel,
  }) {
    return Row(
      children: [
        InkWell(
          onTap: onPrev,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _darkBlueText),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onNext,
              child: Text(
                primaryLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onNext,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _darkBlueText),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String val, String sub, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMockTcsOption(String text, bool isChecked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isChecked ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isChecked ? Colors.greenAccent : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(isChecked ? Icons.check_box : Icons.check_box_outline_blank, size: 12, color: isChecked ? Colors.greenAccent : Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 9.5, color: isChecked ? Colors.greenAccent : Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPaletteDot(String label, Color color, {bool border = false}) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: border ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMiniSpecCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _brandBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _darkBlueText)),
                Text(subtitle, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrapChoiceTile(String label, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isCorrect ? const Color(0xFF34D399) : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCorrect ? const Color(0xFF065F46) : _darkBlueText)),
          if (isCorrect) const Text('✓ Ans', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildCityChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? _brandBlue : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF475569)),
      ),
    );
  }
}

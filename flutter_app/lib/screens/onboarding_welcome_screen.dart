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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  int _currentIndex = 0;
  bool _isLoading = false;
  String _selectedExam = 'ALL';

  static const Color _brandBlue = Color(0xFF0038B8);
  static const Color _darkHeader = Color(0xFF0A1128);
  static const Color _accentGold = Color(0xFFF59E0B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _bgScreen = Color(0xFFF6F8FD);

  final List<Map<String, String>> _examTabs = const [
    {'id': 'ALL', 'label': '⚡ Sabhi Exams (All)'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'IBPS', 'label': 'IBPS & SBI PO'},
    {'id': 'BPSC', 'label': 'BPSC & State PCS'},
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
      await prefs.setString('user_mobile', phone);

      if (phone.isNotEmpty) {
        try {
          await Supabase.instance.client.from('app_users').upsert({
            'mobile_number': phone,
            'full_name': name,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint("Supabase save warning: $e");
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } catch (e) {
      debugPrint("Onboarding error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextSlide() {
    if (_currentIndex < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
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
      backgroundColor: _bgScreen,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildExamChips(),
            const SizedBox(height: 6),

            // 4-Slide Main Carousel Viewport (100% Height Fill)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                children: [
                  _buildSlideCard(_buildSlide1OverviewHero()),
                  _buildSlideCard(_buildSlide2TcsSimulator()),
                  _buildSlideCard(_buildSlide3CoachingHubShowcase()),
                  _buildSlideCard(_buildSlide4ProfileSetupForm()),
                ],
              ),
            ),

            // Unified Bottom Indicator & Navigation
            _buildGlobalBottomNavbar(),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'MockTester',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: _darkHeader,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'CBT',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Smart CBT Prep Platform',
                    style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          if (_currentIndex < 3)
            InkWell(
              onTap: () {
                _pageController.animateToPage(
                  3,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _brandBlue.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _brandBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExamChips() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _examTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final tab = _examTabs[idx];
          final isSelected = _selectedExam == tab['id'];

          return InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => setState(() => _selectedExam = tab['id']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? _brandBlue : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? _brandBlue : _borderSubtle,
                ),
              ),
              child: Text(
                tab['label']!,
                style: TextStyle(
                  fontSize: 10,
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

  Widget _buildSlideCard(Widget content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: content,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SLIDE 1: OVERVIEW HERO (REALISTIC METRICS)
  // =========================================================================
  Widget _buildSlide1OverviewHero() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 0.85,
                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFFF1F5F9)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 22,
                    child: Container(
                      width: 220,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 35,
                    child: Container(
                      width: 130,
                      height: 80,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(width: 20, height: 3, color: Colors.greenAccent),
                              Container(width: 15, height: 3, color: Colors.amber),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(width: 70, height: 3, color: Colors.white70),
                          const SizedBox(height: 3),
                          Container(width: 50, height: 3, color: Colors.white38),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(width: 30, height: 6, decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(2))),
                              Container(width: 20, height: 6, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 20,
                    top: 20,
                    child: Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 38),
                  ),
                  Positioned(
                    top: 30,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: _brandBlue,
                      child: const Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.white, size: 13),
                    SizedBox(width: 3),
                    Text('Exam Ready', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 13),
                    SizedBox(width: 4),
                    Text('100% NTA Pattern', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _darkHeader)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkHeader, letterSpacing: -0.4),
            children: [
              TextSpan(text: 'Aapki Manzil, '),
              TextSpan(text: 'MockTester', style: TextStyle(color: _brandBlue)),
              TextSpan(text: ' Ka\nSankalp'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'All-in-one CBT Mocks, Question Vault, Coaching Batches\n& Real Time Analysis ek hi platform par!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCol('100% Free', 'Practice Mode', const Color(0xFFD97706)),
              Container(height: 22, width: 1, color: _borderSubtle),
              _buildStatCol('TCS Engine', 'NTA Simulation', _brandBlue),
              Container(height: 22, width: 1, color: _borderSubtle),
              _buildStatCol('Instant', 'Score Analysis', const Color(0xFF0F766E)),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SLIDE 2: TCS CBT SIMULATOR (FEATURE 1)
  // =========================================================================
  Widget _buildSlide2TcsSimulator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: _brandBlue),
                  SizedBox(width: 6),
                  Text(
                    'Exact TCS Server Sync & Negative Marking (-0.50)',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF002277)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
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
                          CircleAvatar(radius: 3.5, backgroundColor: Colors.green),
                          SizedBox(width: 5),
                          Text(
                            'SSC CGL (Tier-1) Mock #01',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Text('⏳ ', style: TextStyle(fontSize: 9)),
                            Text('58:42 Left', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Reasoning (25)', style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      const Text('GK/GA (25)', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                      const SizedBox(width: 8),
                      const Text('Quants (25)', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                      const SizedBox(width: 8),
                      const Text('English (25)', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),

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
                                Text('Question 14', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                Text('+2.00 / -0.50', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Find the odd letter pair out of the following given alternatives:',
                              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 10, height: 1.25),
                            ),
                            const SizedBox(height: 6),
                            _buildTcsOption('[A] BCD : EFG', false),
                            _buildTcsOption('[B] FGH : JKL (Saved)', true),
                            _buildTcsOption('[C] LMN : OPQ', false),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Mark Review', style: TextStyle(fontSize: 8, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(3)),
                                  child: const Text('Save & Next >', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('PALETTE ', style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                                  Text('25 QS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 3,
                                runSpacing: 3,
                                children: [
                                  _buildDot('1', Colors.green),
                                  _buildDot('2', Colors.green),
                                  _buildDot('3', Colors.red),
                                  _buildDot('4', Colors.green),
                                  _buildDot('5', Colors.purple),
                                  _buildDot('6', Colors.green),
                                  _buildDot('7', Colors.green),
                                  _buildDot('8', Colors.red),
                                  _buildDot('14', Colors.green, isSelected: true),
                                  _buildDot('15', Colors.grey),
                                  _buildDot('16', Colors.grey),
                                  _buildDot('17', Colors.purple),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Divider(height: 1, color: Color(0xFF334155)),
                              const SizedBox(height: 3),
                              _buildPaletteStatRow('Answered', '18', Colors.green),
                              _buildPaletteStatRow('Not Ans', '05', Colors.red),
                              _buildPaletteStatRow('Review', '02', Colors.purple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              'Asli Exam Hall Jaisa Real CBT Interface!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: _darkHeader),
            ),
            const SizedBox(height: 4),
            const Text(
              'Exam se pehle exam ka darr khatam. Same timer, same navigation palette, aur negative mark calculation direct TCS pattern par.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: _buildMiniSpecTile(Icons.language, '100% TCS Match', 'Exam hall simulation')),
                const SizedBox(width: 6),
                Expanded(child: _buildMiniSpecTile(Icons.bar_chart, 'Live Percentile', 'Instant score comparison')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // SLIDE 3: COACHING HUB SHOWCASE (FEATURE 2)
  // =========================================================================
  Widget _buildSlide3CoachingHubShowcase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
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
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: _brandBlue),
                      SizedBox(width: 4),
                      Text('Coaching Integration USP', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hub_outlined, size: 12, color: Color(0xFF065F46)),
                      SizedBox(width: 4),
                      Text('Digital Classroom Sync', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.key, size: 14, color: _brandBlue),
                            SizedBox(width: 6),
                            Text('Batch Code: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkHeader)),
                            Text('#PATNA99', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Verified Batch', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  _buildCoachingListItem(
                    avatarText: 'LA',
                    avatarColor: const Color(0xFFDBEAFE),
                    avatarTextColor: _brandBlue,
                    title: 'Lakshya Academy',
                    subtitle: 'Patna, Bihar • Special Target Batch',
                    trailingBadgeText: 'CBT Live',
                    trailingBadgeBg: const Color(0xFFEFF6FF),
                    trailingBadgeTextColor: _brandBlue,
                  ),
                  const SizedBox(height: 5),

                  _buildCoachingListItem(
                    avatarText: 'SC',
                    avatarColor: const Color(0xFFFEF3C7),
                    avatarTextColor: const Color(0xFFB45309),
                    title: 'Sankalp Classes',
                    subtitle: 'Jaipur & Sikar • Dedicated Mock Series',
                    trailingBadgeText: 'Verified',
                    trailingBadgeBg: const Color(0xFFD1FAE5),
                    trailingBadgeTextColor: const Color(0xFF065F46),
                  ),
                  const SizedBox(height: 5),

                  _buildCoachingListItem(
                    avatarText: 'PS',
                    avatarColor: const Color(0xFFD1FAE5),
                    avatarTextColor: const Color(0xFF065F46),
                    title: 'Pioneer SSC Hub',
                    subtitle: 'Mukherjee Nagar, Delhi • Test Series',
                    trailingBadgeText: '• Test #14',
                    trailingBadgeBg: const Color(0xFFFEF3C7),
                    trailingBadgeTextColor: const Color(0xFFB45309),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Text('TOP HUBS: ', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Patna', 'Mukherjee Nagar', 'Prayagraj', 'Jaipur', 'Indore', 'Kota'].map((hub) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(hub, style: const TextStyle(fontSize: 8.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              'Aapki City Ki Famous Coaching Ab\nMockTester Pe!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: _darkHeader, height: 1.25),
            ),
            const SizedBox(height: 5),
            const Text(
              'Local institute test series directly on MockTester TCS engine. Teachers upload mock papers easily; students practice on real exam software!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSmallFeaturePill(Icons.login, 'Direct Batch Code Login'),
                const SizedBox(width: 5),
                _buildSmallFeaturePill(Icons.bar_chart, 'Classroom Live Ranking'),
              ],
            ),
            const SizedBox(height: 4),
            _buildSmallFeaturePill(Icons.cloud_upload_outlined, 'Easy Digital Paper Upload'),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // SLIDE 4: FINAL STEP (ASPIRANT PROFILE SETUP)
  // =========================================================================
  Widget _buildSlide4ProfileSetupForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.badge_rounded, color: _brandBlue, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Setup Aspirant Profile 🚀", style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: _darkHeader)),
                      Text("Yeh details aapke scorecard & batch rank par aayegi", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Full Name *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkHeader)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Anand Sharma',
                        hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: _brandBlue, size: 16),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderSubtle)),
                      ),
                      validator: (val) => (val == null || val.trim().length < 2) ? 'Kripya apna naam enter karein' : null,
                    ),
                    const SizedBox(height: 10),

                    const Text("Mobile Number (Optional)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkHeader)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: InputDecoration(
                        hintText: 'e.g. 9876543210 (Classroom sync ke liye)',
                        hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.grey, size: 16),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderSubtle)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return null;
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(val.trim())) return 'Valid 10-digit number enter karein';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 6),
                        Text('100% Free NTA/TCS Pattern Mocks unlocked', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkHeader)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 6),
                        Text('Coaching Classroom Live Sync activated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkHeader)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _completeOnboarding,
              child: _isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Start Preparation 🚀', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- BOTTOM NAV BAR ---
  Widget _buildGlobalBottomNavbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Slide ${_currentIndex + 1} of 4 • ${_getSlideCategoryLabel()}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _darkHeader),
              ),
              Row(
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    height: 5.5,
                    width: _currentIndex == index ? 20 : 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? _brandBlue : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: _nextSlide,
                child: const Row(
                  children: [
                    Text('Swipe', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_currentIndex < 3)
            Row(
              children: [
                if (_currentIndex > 0) ...[
                  InkWell(
                    onTap: _prevSlide,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderSubtle),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _darkHeader),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _nextSlide,
                      child: Text(
                        _currentIndex == 0
                            ? 'Explore Real CBT Engine'
                            : _currentIndex == 1
                                ? 'Next: Coaching Hub Integration'
                                : 'Setup Aspirant Profile',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _nextSlide,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderSubtle),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _darkHeader),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- COMPONENT HELPERS ---
  Widget _buildStatCol(String top, String bottom, Color topColor) {
    return Column(
      children: [
        Text(top, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: topColor)),
        const SizedBox(height: 1),
        Text(bottom, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCoachingListItem({
    required String avatarText,
    required Color avatarColor,
    required Color avatarTextColor,
    required String title,
    required String subtitle,
    required String trailingBadgeText,
    required Color trailingBadgeBg,
    required Color trailingBadgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: avatarColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(avatarText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: avatarTextColor)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkHeader)),
                    const SizedBox(width: 3),
                    const Icon(Icons.check_circle, size: 11, color: Color(0xFF059669)),
                  ],
                ),
                Text(subtitle, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: trailingBadgeBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(trailingBadgeText, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: trailingBadgeTextColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _brandBlue),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _darkHeader)),
        ],
      ),
    );
  }

  Widget _buildTcsOption(String text, bool isChecked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: isChecked ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isChecked ? Colors.greenAccent : Colors.transparent),
      ),
      child: Text(text, style: TextStyle(fontSize: 8.5, color: isChecked ? Colors.greenAccent : Colors.white70)),
    );
  }

  Widget _buildDot(String label, Color color, {bool isSelected = false}) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPaletteStatRow(String title, String val, Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 2.5, backgroundColor: col),
              const SizedBox(width: 3),
              Text(title, style: const TextStyle(fontSize: 7, color: Colors.grey)),
            ],
          ),
          Text(val, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  Widget _buildMiniSpecTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderSubtle)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _brandBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkHeader)),
                Text(subtitle, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSlideCategoryLabel() {
    switch (_currentIndex) {
      case 0:
        return 'Overview';
      case 1:
        return 'TCS Simulation';
      case 2:
        return 'Coaching Hub';
      case 3:
        return 'Aspirant Profile';
      default:
        return '';
    }
  }
}

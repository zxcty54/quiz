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
  final _batchCodeController = TextEditingController(text: 'SNK-50');

  int _currentIndex = 0;
  bool _isLoading = false;
  String _selectedExam = 'ALL';
  String _coachingPersona = 'aspirant';
  String _selectedCity = 'Mukherjee Nagar (Delhi)';

  static const Color _brandBlue = Color(0xFF0038B8);
  static const Color _darkHeader = Color(0xFF0A1128);
  static const Color _accentGold = Color(0xFFF59E0B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _bgScreen = Color(0xFFF6F8FD);

  final List<Map<String, String>> _examTabs = const [
    {'id': 'ALL', 'label': 'Sabhi Exams (All)'},
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
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextSlide() {
    if (_currentIndex < 2) {
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
    _batchCodeController.dispose();
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

            // 3-Slide Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                children: [
                  _buildSlideCard(_buildFeature1TcsSimulator()),
                  _buildSlideCard(_buildFeature2TrapAndCoachingHub()),
                  _buildSlideCard(_buildFeature3ProfileSetup()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP BAR (MockTester + Overview/Walkthrough Toggle) ---
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

          // Walkthrough progress badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Step ${_currentIndex + 1} of 3',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: _darkHeader,
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
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
  // SLIDE 1 (FEATURE 1): ASLI EXAM HALL CBT INTERFACE (Capture 1, 2 & 3)
  // =========================================================================
  Widget _buildFeature1TcsSimulator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            // Exact Capture 3 Top Badge
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

            // TCS Dark Terminal Simulation Box (Capture 3)
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
                  // Mock Title Bar with Green Indicator
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

                  // Section Tabs
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

                  // Split View: Question Area & 25-Question Palette
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Column
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

                      // NTA 25-Button Matrix (Exact Capture 3)
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

            // Capture 1 & 3 Headline & Description
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

            // Performance spec row (Capture 1 & 2)
            Row(
              children: [
                Expanded(child: _buildMiniSpecTile(Icons.language, '99.8% NTA Match', 'Real exam simulation')),
                const SizedBox(width: 6),
                Expanded(child: _buildMiniSpecTile(Icons.bar_chart, 'Live AIR Percentile', 'Rank vs 50k+ aspirants')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildCarouselActionRow(
          btnLabel: 'Launch Live TCS Mock Engine',
          onNext: _nextSlide,
          showBack: false,
        ),
      ],
    );
  }

  // =========================================================================
  // SLIDE 2 (FEATURE 2): AI TRAP + MISTAKE VAULT + COACHING HUB (Capture 4, 5, 6)
  // =========================================================================
  Widget _buildFeature2TrapAndCoachingHub() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            // Top Badges (Capture 4)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(14)),
                  child: const Text('🧠 AI Trap Detector & Vault', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(14)),
                  child: const Text('✓ Zero Negative Marking', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // AI Trap Card Box (Capture 4)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F9),
                borderRadius: BorderRadius.circular(14),
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
                          Icon(Icons.warning_amber_rounded, color: Colors.pink, size: 16),
                          SizedBox(width: 6),
                          Text('Examiner Trap Detector', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkHeader)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF43F5E), borderRadius: BorderRadius.circular(6)),
                        child: const Text('TRAP ALERT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSubtle)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Algebra Trap Sample • SSC CGL Tier-1', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(4)),
                              child: const Text('64% Aspirants Trapped', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('If x + 1/x = -4, then find x³ + 1/x³ = ?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkHeader)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(child: _buildTrapOpt('Option A (+48)', false)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildTrapOpt('Option B (-48)', false)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: _buildTrapOpt('Option C (+52)', false)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildTrapOpt('Option D (-52) ✓ Ans', true)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Trap logic explanation
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('⚠️ Why this is a trap:', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFBE123C))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(3)),
                              child: const Text('Sign Inversion Error', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF9F1239))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Using identity (k³ - 3k) for k = -4: (-4)³ - 3(-4) = -64 + 12 = -52. Bait options +48 & -48 trap hasty calculations under timer pressure.',
                          style: TextStyle(fontSize: 8.5, color: Color(0xFF475569), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Auto-saved & Re-attempt bar (Capture 4)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: Color(0xFF0F766E)),
                          SizedBox(width: 4),
                          Text('Auto-saved in your Mistake Vault', style: TextStyle(fontSize: 9, color: Color(0xFF475569))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          children: [
                            Text('Re-attempt Trap', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(width: 3),
                            Icon(Icons.refresh, size: 10, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Verified Institute Pass Box with Live City Radar (Capture 6)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(14),
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
                          Icon(Icons.storefront, size: 14, color: _brandBlue),
                          SizedBox(width: 4),
                          Text('VERIFIED INSTITUTE CBT PASS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _brandBlue)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text('LIVE CBT PASS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ),
                    ],
                  ),
                  const Divider(height: 10, color: Color(0xFFE2E8F0)),

                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: const Text('LA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sankalp Career Academy (Jaipur)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkHeader)),
                            Text('👥 SSC CGL Super-50 | Room B-12', style: TextStyle(fontSize: 9, color: _brandBlue, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.qr_code_2_rounded, size: 22, color: Color(0xFF475569)),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Code Entry Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.key, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(_batchCodeController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _darkHeader)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {},
                          child: const Text('Verify ✓', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Live City Radar Chips (Capture 6)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Live Radar: ', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        _buildCityChip('Mukherjee Nagar (Delhi)', true),
                        const SizedBox(width: 4),
                        _buildCityChip('Patna (Boring Rd)', false),
                        const SizedBox(width: 4),
                        _buildCityChip('Prayagraj', false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildCarouselActionRow(
          btnLabel: 'Proceed to Profile Setup',
          onNext: _nextSlide,
          onPrev: _prevSlide,
          showBack: true,
        ),
      ],
    );
  }

  // =========================================================================
  // SLIDE 3 (FINAL ENTRY): ASPIRANT PROFILE & REGISTRATION
  // =========================================================================
  Widget _buildFeature3ProfileSetup() {
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
                      Text("Yeh details aapke scorecard par display hongi", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
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
                        hintText: 'e.g. 9876543210 (Classroom sync)',
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

              // Benefits Checklist
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 6),
                        Text('100% NTA/TCS Pattern Free Mocks unlocked', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkHeader)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 6),
                        Text('AI Mistake Vault & Trap Re-attempt ready', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkHeader)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Button Row
          Row(
            children: [
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
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _completeOnboarding,
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Start Preparation 🚀', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- REUSABLE CAROUSEL NAVIGATOR (< & >) ---
  Widget _buildCarouselActionRow({
    required String btnLabel,
    required VoidCallback onNext,
    VoidCallback? onPrev,
    bool showBack = false,
  }) {
    return Row(
      children: [
        if (showBack) ...[
          InkWell(
            onTap: onPrev,
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
              onPressed: onNext,
              child: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onNext,
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
    );
  }

  // Helper Widget Renderers
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

  Widget _buildTrapOpt(String label, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: isCorrect ? const Color(0xFF34D399) : Colors.transparent),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: isCorrect ? const Color(0xFF065F46) : _darkHeader),
      ),
    );
  }

  Widget _buildCityChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? _brandBlue : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : _brandBlue),
      ),
    );
  }
}

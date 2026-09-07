import 'package:flutter/material.dart';
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
  String _activeExam = 'ALL';
  String _viewMode = 'overview';

  static const Color _primaryBlue = Color(0xFF0037B0);
  static const Color _darkNavy = Color(0xFF131B2E);
  static const Color _saffronAccent = Color(0xFFFEA619);
  static const Color _saffronDark = Color(0xFF855300);
  static const Color _borderColor = Color(0xFFC4C5D7);
  static const Color _bgSoft = Color(0xFFFAF8FF);

  final List<Map<String, String>> _exams = [
    {'id': 'ALL', 'label': 'Sabhi Exams (All)'},
    {'id': 'BPSC', 'label': 'BPSC & BSSC'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'BIHAR_SI', 'label': 'Bihar SI & Police'},
    {'id': 'IBPS', 'label': 'IBPS & SBI PO'},
    {'id': 'RLY', 'label': 'Railway NTPC'},
  ];

  void _navigateToNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSoft,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildExamFilterBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 14),
                    _buildSocialProofBar(),
                    const SizedBox(height: 20),
                    _buildFeaturesSection(),
                    const SizedBox(height: 16),
                    _buildTestimonialCard(),
                    const SizedBox(height: 20),
                    _buildInlineActionSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔝 1. TOP HEADER WITH VIEW SWITCHER
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSoft.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.25))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
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
                          color: _darkNavy,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _saffronAccent.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _saffronAccent.withOpacity(0.35)),
                        ),
                        child: const Text(
                          'CBT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _saffronDark),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEDFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    _buildSwitchTab('Slides', 'carousel', Icons.auto_awesome),
                    _buildSwitchTab('Overview', 'overview', Icons.layers_rounded),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _navigateToNext,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String label, String mode, IconData icon) {
    final bool isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 11, color: isSelected ? _primaryBlue : const Color(0xFF434655)),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? _primaryBlue : const Color(0xFF434655),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🏷️ 2. EXAM FILTER TABS
  Widget _buildExamFilterBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _exams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final exam = _exams[idx];
          final bool isSelected = _activeExam == exam['id'];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _activeExam = exam['id']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? _primaryBlue : const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                exam['label']!,
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
    );
  }

  // 🎯 3. HERO SECTION WITH BADGES
  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E7FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: _saffronAccent, size: 14),
              SizedBox(width: 4),
              Text(
                "India's 1st Smart CBT Prep App 🎯",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 220,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFFDAE2FD).withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFDAE2FD)),
                  boxShadow: [
                    BoxShadow(color: _primaryBlue.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.school_rounded, size: 68, color: _primaryBlue),
              ),
              Positioned(
                bottom: 6,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF004F35), size: 12),
                      SizedBox(width: 4),
                      Text('100% NTA Pattern', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF004F35))),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: _saffronAccent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: _saffronAccent.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: Color(0xFF855300), size: 12),
                      SizedBox(width: 3),
                      Text('AIR #1 Ready', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF684000))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _darkNavy, letterSpacing: -0.4),
            children: [
              TextSpan(text: 'Aapki Manzil, '),
              TextSpan(text: 'MockTester', style: TextStyle(color: Color(0xFF1D4ED8))),
              TextSpan(text: ' Ka Sankalp'),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'All-in-one CBT Mocks, AI Question Vault, Top Coaching & Expert Mentorship ek hi jagah!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF434655), height: 1.4),
        ),
      ],
    );
  }

  // 📊 4. SOCIAL PROOF STRIP
  Widget _buildSocialProofBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCol('★ 4.9/5', 'Top Rated', const Color(0xFF855300)),
          _buildStatDivider(),
          _buildStatCol('2.5 Lakh+', 'Aspirants', _primaryBlue),
          _buildStatDivider(),
          _buildStatCol('1,000+', 'Institutes', const Color(0xFF004F35)),
        ],
      ),
    );
  }

  Widget _buildStatCol(String val, String lbl, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        Text(lbl, style: const TextStyle(fontSize: 10.5, color: Color(0xFF434655), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 24, width: 1, color: _borderColor.withOpacity(0.5));
  }

  // 🛠️ 5. CORE FEATURES SECTION (9 SMART TOOLS)
  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _primaryBlue, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Khas Feature Mocks Ke Liye',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _darkNavy),
                ),
              ],
            ),
            const Text('9 Smart Tools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue)),
          ],
        ),
        const SizedBox(height: 10),

        _buildFeatureCard(
          icon: Icons.monitor_rounded,
          iconBg: const Color(0xFF1D4ED8).withOpacity(0.1),
          iconColor: const Color(0xFF1D4ED8),
          title: 'Real CBT Simulation',
          badgeText: 'TCS Engine',
          badgeBg: _primaryBlue.withOpacity(0.1),
          badgeColor: _primaryBlue,
          desc: 'Exact timer countdown, sectional switches, real negative marking & live All-India percentile rank calculation.',
        ),
        const SizedBox(height: 8),

        _buildFeatureCard(
          icon: Icons.psychology_rounded,
          iconBg: _saffronAccent,
          iconColor: const Color(0xFF684000),
          title: 'AI Trap Detector & Vault',
          badgeText: 'AI Powered',
          badgeBg: _saffronAccent,
          badgeColor: const Color(0xFF684000),
          desc: 'Analyze recurring negative marks, silly traps & examiner tricks automatically with AI-backed step-by-step logic.',
          isHighlighted: true,
        ),
        const SizedBox(height: 8),

        _buildFeatureCard(
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFF004F35).withOpacity(0.1),
          iconColor: const Color(0xFF004F35),
          title: 'All India Coaching Hub',
          badgeText: 'Verified',
          badgeBg: const Color(0xFF6FFBBE).withOpacity(0.4),
          badgeColor: const Color(0xFF002113),
          desc: '"Aapki City Ki Famous Coaching Ab MockTester Pe!" Local institutes create verified CBT papers for their batch students.',
        ),
        const SizedBox(height: 8),

        _buildFeatureCard(
          icon: Icons.school_rounded,
          iconBg: const Color(0xFFDCE1FF),
          iconColor: const Color(0xFF001551),
          title: 'Live Classes: Raju & Aman Sir',
          badgeText: 'Top Faculty',
          badgeBg: const Color(0xFFFFDAD6),
          badgeColor: const Color(0xFF93000A),
          desc: 'Complete syllabus coverage, daily live doubt sessions, time-management masterclasses, and subject conceptual clarity.',
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.refresh_rounded,
                title: '10-Min Revision',
                desc: 'Rapid-fire interactive flashcard decks before tests.',
                iconColor: _primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.newspaper_rounded,
                title: 'Daily GK Capsule',
                desc: 'Daily bilingual current affairs & static GK booster quiz.',
                iconColor: const Color(0xFF004F35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.menu_book_rounded,
                title: 'Free PYQ & Notes',
                desc: 'Download 10-year solved papers & short-trick cheat sheets.',
                iconColor: const Color(0xFF855300),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.groups_rounded,
                title: 'Aspirant Adda',
                desc: 'Peer doubt resolution, topper study rooms & leaderboard.',
                iconColor: _primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E7FF).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: _saffronAccent, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF684000), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Real-Time Sarkari Job Alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkNavy)),
                        SizedBox(width: 4),
                        CircleAvatar(radius: 3, backgroundColor: Colors.red),
                      ],
                    ),
                    Text('Instant notifications for SSC, Railway, Banking vacancies & admit cards.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF434655))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeBg,
    required Color badgeColor,
    required String desc,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _saffronAccent.withOpacity(0.5) : _borderColor.withOpacity(0.35),
          width: isHighlighted ? 1.4 : 1,
        ),
        boxShadow: isHighlighted
            ? [BoxShadow(color: _saffronAccent.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))]
            : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkNavy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                      child: Text(badgeText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF434655), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniToolTile({
    required IconData icon,
    required String title,
    required String desc,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkNavy)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF434655), height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // 🏆 6. TESTIMONIAL CARD
  Widget _buildTestimonialCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: _primaryBlue, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"MockTester ke trap analysis ne mere negative score ko 18 se ghatakar 2 par la diya!"',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _darkNavy, height: 1.3),
                ),
                SizedBox(height: 2),
                Text('— Rakesh Verma (Selected, SSC CGL 2023)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF434655))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 7. INLINE BOTTOM ACTION SECTION
  Widget _buildInlineActionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _navigateToNext,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Get Started / Shuru Karein', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: _navigateToNext,
                child: const Text('Already a Member? Log In',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryBlue)),
              ),
              Container(height: 14, width: 1, color: _borderColor),
              TextButton(
                onPressed: () {},
                child: const Text('Coaching Center? Register',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _saffronDark)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF004F35), size: 13),
              SizedBox(width: 4),
              Text('Free Daily Quizzes • No Credit Card Required',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF434655), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

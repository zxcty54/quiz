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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _activeExam = 'ALL';
  bool _isLoading = false;

  static const Color _primaryBlue = Color(0xFF0038B8);
  static const Color _darkNavy = Color(0xFF0A1128);
  static const Color _saffronAccent = Color(0xFFFEA619);
  static const Color _saffronDark = Color(0xFF855300);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _bgSoft = Color(0xFFF8FAFC);

  final List<Map<String, String>> _exams = const [
    {'id': 'ALL', 'label': '⚡ Sabhi Exams (All)'},
    {'id': 'BPSC', 'label': 'BPSC & BSSC'},
    {'id': 'SSC', 'label': 'SSC CGL & CHSL'},
    {'id': 'BIHAR_SI', 'label': 'Bihar SI & Police'},
    {'id': 'IBPS', 'label': 'IBPS & SBI PO'},
    {'id': 'RLY', 'label': 'Railway NTPC'},
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
          debugPrint("Supabase sync warning: $e");
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

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildExamFilterBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 18),
                    _buildSocialProofBar(),
                    const SizedBox(height: 24),
                    _buildFeaturesSection(),
                    const SizedBox(height: 18),
                    _buildTestimonialCard(),
                    const SizedBox(height: 22),
                    _buildProfileRegistrationCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔝 1. TOP BRAND HEADER
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.6))),
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
                  color: _primaryBlue,
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
                          fontSize: 16.5,
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
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _saffronAccent.withOpacity(0.35)),
                        ),
                        child: const Text(
                          'CBT',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: _saffronDark),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Smart CBT Prep Platform',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: _skip,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryBlue.withOpacity(0.2)),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🏷️ 2. HORIZONTAL EXAM PILLS
  Widget _buildExamFilterBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 5),
      color: Colors.white,
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
                color: isSelected ? _primaryBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? _primaryBlue : _borderColor),
              ),
              child: Text(
                exam['label']!,
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

  // 🎯 3. HERO SECTION WITH BADGES
  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primaryBlue.withOpacity(0.15)),
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
          height: 175,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFFDBEAFE).withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
              Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                  boxShadow: [
                    BoxShadow(color: _primaryBlue.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.school_rounded, size: 64, color: _primaryBlue),
              ),
              Positioned(
                bottom: 4,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 12),
                      SizedBox(width: 4),
                      Text('100% NTA Pattern', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Text('AIR #1 Ready', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF684000))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _darkNavy, letterSpacing: -0.4),
            children: [
              TextSpan(text: 'Aapki Manzil, '),
              TextSpan(text: 'MockTester', style: TextStyle(color: _primaryBlue)),
              TextSpan(text: ' Ka Sankalp'),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'All-in-one CBT Mocks, AI Question Vault, Top Coaching & Expert Mentorship ek hi platform par!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
        ),
      ],
    );
  }

  // 📊 4. SOCIAL PROOF STRIP
  Widget _buildSocialProofBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCol('★ 4.9/5', 'Top Rated', const Color(0xFFD97706)),
          _buildStatDivider(),
          _buildStatCol('2.5 Lakh+', 'Aspirants', _primaryBlue),
          _buildStatDivider(),
          _buildStatCol('1,000+', 'Institutes', const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildStatCol(String val, String lbl, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 1),
        Text(lbl, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 22, width: 1, color: _borderColor);
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
        const SizedBox(height: 12),

        _buildFeatureCard(
          icon: Icons.monitor_rounded,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: _primaryBlue,
          title: 'Real CBT Simulation',
          badgeText: 'TCS Engine',
          badgeBg: _primaryBlue.withOpacity(0.1),
          badgeColor: _primaryBlue,
          desc: 'Exact countdown timer, sectional navigation, real negative marking & live All-India percentile rank calculation.',
        ),
        const SizedBox(height: 10),

        _buildFeatureCard(
          icon: Icons.psychology_rounded,
          iconBg: _saffronAccent.withOpacity(0.18),
          iconColor: const Color(0xFF855300),
          title: 'AI Trap Detector & Vault',
          badgeText: 'AI Powered',
          badgeBg: _saffronAccent,
          badgeColor: const Color(0xFF684000),
          desc: 'Analyze recurring negative marks, silly traps & examiner tricks automatically with step-by-step reasoning.',
          isHighlighted: true,
        ),
        const SizedBox(height: 10),

        _buildFeatureCard(
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF059669),
          title: 'All India Coaching Hub',
          badgeText: 'Verified',
          badgeBg: const Color(0xFFD1FAE5),
          badgeColor: const Color(0xFF065F46),
          desc: '"Aapki City Ki Famous Coaching Ab MockTester Pe!" Local institutes create verified CBT papers for their batch students.',
        ),
        const SizedBox(height: 10),

        _buildFeatureCard(
          icon: Icons.school_rounded,
          iconBg: const Color(0xFFE0E7FF),
          iconColor: const Color(0xFF3730A3),
          title: 'Live Classes: Raju & Aman Sir',
          badgeText: 'Top Faculty',
          badgeBg: const Color(0xFFFEE2E2),
          badgeColor: const Color(0xFF991B1B),
          desc: 'Complete syllabus coverage, daily live doubt sessions, time-management masterclasses & conceptual clarity.',
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.refresh_rounded,
                title: '10-Min Revision',
                desc: 'Rapid-fire interactive flashcards before tests.',
                iconColor: _primaryBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.newspaper_rounded,
                title: 'Daily GK Capsule',
                desc: 'Daily bilingual current affairs booster drill.',
                iconColor: const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.menu_book_rounded,
                title: 'Free PYQ & Notes',
                desc: '10-year solved papers & short trick cheat-sheets.',
                iconColor: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniToolTile(
                icon: Icons.groups_rounded,
                title: 'Aspirant Adda',
                desc: 'Peer doubt resolution & topper rank boards.',
                iconColor: _primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
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
                    SizedBox(height: 2),
                    Text('Instant push updates for SSC, Railway, Banking vacancies & admit cards.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _saffronAccent.withOpacity(0.55) : _borderColor,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkNavy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                      child: Text(badgeText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkNavy)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // 🏆 6. TESTIMONIAL CARD
  Widget _buildTestimonialCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: _primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"MockTester ke trap analysis ne mere negative score ko 18 se ghatakar 2 par la diya!"',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _darkNavy, height: 1.35),
                ),
                SizedBox(height: 3),
                Text('— Rakesh Verma (Selected, SSC CGL 2023)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📝 7. PROFILE SETUP FORM (Inline Seamless Box)
  Widget _buildProfileRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: _primaryBlue, size: 22),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Free Preparation 🚀', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _darkNavy)),
                    Text('Enter details for test scorecard & batch sync', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Full Name *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkNavy)),
            const SizedBox(height: 5),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Anand Sharma',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: _primaryBlue, size: 18),
                filled: true,
                fillColor: _bgSoft,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Kripya apna naam enter karein!';
                if (val.trim().length < 2) return 'Kam se kam 2 characters ka naam daalein';
                return null;
              },
            ),
            const SizedBox(height: 12),

            const Text('Mobile Number (Optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkNavy)),
            const SizedBox(height: 5),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. 9876543210 (Classroom sync ke liye)',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.grey, size: 18),
                filled: true,
                fillColor: _bgSoft,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null;
                final clean = val.trim();
                final regex = RegExp(r'^[6-9]\d{9}$');
                if (!regex.hasMatch(clean)) {
                  if (clean.length != 10) return 'Poora 10-digit number enter karein';
                  return 'Valid mobile number enter karein';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

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
                onPressed: _isLoading ? null : _completeOnboarding,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Get Started / Shuru Karein', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),

            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 13),
                SizedBox(width: 4),
                Text('Free Daily Quizzes • No Password Required',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

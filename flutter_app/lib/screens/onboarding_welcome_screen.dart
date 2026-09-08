import 'dart:ui';

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

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  late final AnimationController _pageAnimation;
  late final AnimationController _floatAnimation;

  int _currentIndex = 0;
  bool _isLoading = false;

  // ===========================================================================
  // PREMIUM DESIGN SYSTEM
  // ===========================================================================

  static const Color _background = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  static const Color _navy = Color(0xFF101828);
  static const Color _primary = Color(0xFF155EEF);
  static const Color _primaryDark = Color(0xFF0040C1);

  static const Color _secondary = Color(0xFF667085);
  static const Color _muted = Color(0xFF98A2B3);

  static const Color _border = Color(0xFFE4E7EC);

  static const Color _green = Color(0xFF12B76A);
  static const Color _purple = Color(0xFF7F56D9);
  static const Color _orange = Color(0xFFF79009);

  @override
  void initState() {
    super.initState();

    _pageAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _floatAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _pageAnimation.dispose();
    _floatAnimation.dispose();
    super.dispose();
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _nextPage() {
    if (_currentIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skipToProfile() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  // ===========================================================================
  // REGISTRATION
  // ===========================================================================

  Future<void> _completeRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();

    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      await prefs.setBool('is_onboarded', true);
      await prefs.setString('custom_aspirant_name', name);
      await prefs.setString('user_name', name);
      await prefs.setString('user_mobile', phone);

      // Supabase sync
      if (phone.isNotEmpty) {
        try {
          await Supabase.instance.client.from('app_users').upsert({
            'mobile_number': phone,
            'full_name': name,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Supabase sync issue: $e');
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.nextScreen,
        ),
      );
    } catch (e) {
      debugPrint('Storage error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _navy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              // Extremely subtle premium background lighting.
              _buildBackgroundGlow(),

              Column(
                children: [
                  _buildTopBar(),

                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });

                        _pageAnimation
                          ..reset()
                          ..forward();
                      },
                      children: [
                        _buildWelcomePage(),
                        _buildCoachingPage(),
                        _buildProfilePage(),
                      ],
                    ),
                  ),

                  _buildBottomProgress(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BACKGROUND
  // ===========================================================================

  Widget _buildBackgroundGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primary.withValues(alpha: 0.065),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _purple.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOP BAR
  // ===========================================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 18, 4),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1677FF),
                      Color(0xFF0047D9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MockTester',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'SMART EXAM PREP',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          if (_currentIndex < 2)
            TextButton(
              onPressed: _skipToProfile,
              style: TextButton.styleFrom(
                foregroundColor: _secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(48, 42),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 1 — BRAND HERO
  // ===========================================================================

  Widget _buildWelcomePage() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _pageAnimation,
        curve: Curves.easeOut,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
        child: Column(
          children: [
            const Spacer(flex: 1),

            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                final double y =
                    lerpDouble(-4, 4, _floatAnimation.value) ?? 0;

                return Transform.translate(
                  offset: Offset(0, y),
                  child: child,
                );
              },
              child: _buildHeroVisual(),
            ),

            const SizedBox(height: 26),

            const Text(
              'Prepare Better.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _navy,
                fontSize: 31,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.3,
              ),
            ),

            const SizedBox(height: 1),

            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFF155EEF),
                    Color(0xFF7F56D9),
                  ],
                ).createShader(bounds);
              },
              child: const Text(
                'Perform Better.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.3,
                ),
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'Bihar competitive exams ke liye\n'
              'real exam environment mein practice karein.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondary,
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(flex: 2),

            _buildPrimaryButton(
              label: 'Start Exploring',
              icon: Icons.arrow_forward_rounded,
              onPressed: _nextPage,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO VISUAL
  // ===========================================================================

  Widget _buildHeroVisual() {
    return SizedBox(
      width: 255,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft glow
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _primary.withValues(alpha: 0.11),
                  _primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),

          // Main dashboard
          Container(
            width: 205,
            height: 158,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.10),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: _primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mock Test',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Bihar Exams',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Row(
                  children: [
                    _buildHeroStat(
                      value: '85%',
                      label: 'Accuracy',
                    ),
                    const SizedBox(width: 8),
                    _buildHeroStat(
                      value: '124',
                      label: 'Rank',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Check badge
          Positioned(
            top: 13,
            right: 8,
            child: _buildFloatingBadge(
              icon: Icons.check_rounded,
              color: _green,
            ),
          ),

          // Small progress badge
          Positioned(
            bottom: 7,
            left: 8,
            child: _buildFloatingBadge(
              icon: Icons.trending_up_rounded,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 9,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBadge({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 51,
      height: 51,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PAGE 2 — COACHING + CBT
  // ===========================================================================

  Widget _buildCoachingPage() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _pageAnimation,
        curve: Curves.easeOut,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 15, 22, 6),
        child: Column(
          children: [
            _buildSectionHeader(),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildCBTCard(),

                    const SizedBox(height: 14),

                    _buildCoachingCard(),

                    const SizedBox(height: 14),

                    _buildMiniFeatureStrip(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildPrimaryButton(
              label: 'Create My Profile',
              icon: Icons.arrow_forward_rounded,
              onPressed: _nextPage,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'ONE PLATFORM',
            style: TextStyle(
              color: _primary,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Your exam. Your coaching.\nOne platform.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            fontSize: 26,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 9),

        const Text(
          'Real exam practice aur local coaching tests —\n'
          'sab kuch ek hi experience mein.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _secondary,
            fontSize: 11.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CBT CARD
  // ---------------------------------------------------------------------------

  Widget _buildCBTCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -35,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withValues(alpha: 0.16),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.monitor_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Real CBT Experience',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              const Text(
                'Timer • Question Palette • Navigation\n'
                'Negative Marking • Exam-like Interface',
                style: TextStyle(
                  color: Color(0xFFBFC9D9),
                  fontSize: 10.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  _darkPill('CBT MODE'),
                  const SizedBox(width: 7),
                  _darkPill('EXAM READY'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD8E4F7),
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COACHING CARD
  // ---------------------------------------------------------------------------

  Widget _buildCoachingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFEAF2FF),
                  Color(0xFFF1ECFF),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: _primary,
              size: 23,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Coaching. Now Digital.',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Apne local coaching centre ke mock tests bhi '
                  'isi platform par digitally attempt karein.',
                  style: TextStyle(
                    color: _secondary,
                    fontSize: 10.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MINI STRIP
  // ---------------------------------------------------------------------------

  Widget _buildMiniFeatureStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _border,
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _MiniFeature(
              icon: Icons.language_rounded,
              title: 'Bilingual',
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _MiniFeature(
              icon: Icons.insights_rounded,
              title: 'Performance',
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _MiniFeature(
              icon: Icons.bolt_rounded,
              title: 'Fast Practice',
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 3 — PROFILE
  // ===========================================================================

  Widget _buildProfilePage() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _pageAnimation,
          curve: Curves.easeOut,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 15),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildProfileHeader(),

                const SizedBox(height: 22),

                _buildProfileForm(),

                const SizedBox(height: 18),

                _buildPrimaryButton(
                  label: _isLoading
                      ? 'Setting up...'
                      : 'Start My Preparation',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _isLoading
                      ? null
                      : _completeRegistration,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 9),

                const Text(
                  'You can update your profile anytime from Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFEAF2FF),
                Color(0xFFF0EBFF),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: _primary,
            size: 29,
          ),
        ),

        const SizedBox(height: 13),

        const Text(
          'Let’s get you started.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Create your profile to personalize your\n'
          'MockTester preparation experience.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _secondary,
            fontSize: 11.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel(
            'FULL NAME',
            required: true,
          ),

          const SizedBox(height: 8),

          _buildTextField(
            controller: _nameController,
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return 'Please enter your name';
              }

              return null;
            },
          ),

          const SizedBox(height: 18),

          _buildInputLabel(
            'MOBILE NUMBER',
            required: false,
          ),

          const SizedBox(height: 4),

          const Text(
            'Optional • Useful for coaching & classroom sync',
            style: TextStyle(
              color: _muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          _buildTextField(
            controller: _phoneController,
            hint: '10-digit mobile number',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }

              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
                return 'Enter a valid 10-digit number';
              }

              return null;
            },
          ),

          const SizedBox(height: 15),

          _buildPrivacyNote(),
        ],
      ),
    );
  }

  Widget _buildInputLabel(
    String text, {
    required bool required,
  }) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _navy,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.75,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(0xFFD92D20),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      cursorColor: _primary,
      style: const TextStyle(
        color: _navy,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: _primary,
          size: 19,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: _border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: _border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: _primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFD92D20),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFD92D20),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: _primary,
              size: 15,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Your details are used to personalize your experience '
              'and connect your coaching profile.',
              style: TextStyle(
                color: _secondary,
                fontSize: 9.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRIMARY BUTTON
  // ===========================================================================

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final bool enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFF1677FF),
                    Color(0xFF0047D9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFF98A2B3),
                    Color(0xFF98A2B3),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(
                      icon,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM PROGRESS
  // ===========================================================================

  Widget _buildBottomProgress() {
    final String title;

    switch (_currentIndex) {
      case 0:
        title = 'Intro';
        break;
      case 1:
        title = 'Platform';
        break;
      default:
        title = 'Profile';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 13),
      child: Row(
        children: [
          Text(
            '0${_currentIndex + 1}',
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E7EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      height: 4,
                      width: constraints.maxWidth *
                          ((_currentIndex + 1) / 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF155EEF),
                            Color(0xFF7F56D9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          Text(
            title,
            style: const TextStyle(
              color: _secondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MINI FEATURE
// =============================================================================

class _MiniFeature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _MiniFeature({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: const Color(0xFF155EEF),
          size: 15,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// VERTICAL DIVIDER
// =============================================================================

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: const Color(0xFFE4E7EC),
    );
  }
}
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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  late final AnimationController _fadeController;
  late final AnimationController _floatController;

  int _currentIndex = 0;
  bool _isLoading = false;

  // ---------------------------------------------------------------------------
  // PREMIUM EDU-TECH DESIGN SYSTEM
  // ---------------------------------------------------------------------------

  static const Color _background = Color(0xFFF7F9FC);
  static const Color _surface = Colors.white;

  static const Color _navy = Color(0xFF081A3A);
  static const Color _primary = Color(0xFF155EEF);
  static const Color _primaryDark = Color(0xFF0B46C1);
  static const Color _primaryLight = Color(0xFFEAF2FF);

  static const Color _textPrimary = Color(0xFF101828);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _textTertiary = Color(0xFF98A2B3);

  static const Color _border = Color(0xFFE4E7EC);

  static const Color _orange = Color(0xFFFF9F1C);
  static const Color _green = Color(0xFF12B76A);
  static const Color _purple = Color(0xFF7F56D9);
  static const Color _cyan = Color(0xFF06AED4);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // REGISTRATION
  // ---------------------------------------------------------------------------

  Future<void> _completeRegistration() async {
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

      if (mounted) {
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
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goNext() {
    if (_currentIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
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

                  _fadeController
                    ..reset()
                    ..forward();
                },
                children: [
                  _buildWelcomePage(),
                  _buildFeaturesPage(),
                  _buildProfilePage(),
                ],
              ),
            ),

            _buildBottomProgress(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP BAR
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          // Brand
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF155EEF),
                      Color(0xFF0040C1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MockTester',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'SMART EXAM PREP',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          if (_currentIndex < 2)
            TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: _textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 1 — HERO
  // ---------------------------------------------------------------------------

  Widget _buildWelcomePage() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
        child: Column(
          children: [
            const Spacer(flex: 1),

            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final offset =
                    lerpDouble(-5, 5, _floatController.value) ?? 0;

                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildHeroIllustration(),
            ),

            const SizedBox(height: 32),

            const Text(
              'Your Preparation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 1.05,
              ),
            ),

            const SizedBox(height: 3),

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
                'Your Selection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                  height: 1.05,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Bihar competitive exams ke liye\n'
              'real exam experience ke saath practice karein.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 22),

            _buildTrustPill(),

            const Spacer(flex: 2),

            _buildPrimaryButton(
              label: 'Explore MockTester',
              icon: Icons.arrow_forward_rounded,
              onPressed: _goNext,
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroIllustration() {
    return SizedBox(
      width: 240,
      height: 205,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow
          Container(
            width: 175,
            height: 175,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _primary.withValues(alpha: 0.16),
                  _primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),

          // Main card
          Container(
            width: 190,
            height: 145,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: _primary,
                          size: 20,
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
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Bihar Exams',
                              style: TextStyle(
                                fontSize: 9,
                                color: _textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAFBF3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: _green,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _miniStat('85%', 'Accuracy'),
                      const SizedBox(width: 8),
                      _miniStat('124', 'Rank'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating check
          Positioned(
            right: 8,
            top: 15,
            child: _floatingBadge(
              Icons.check_rounded,
              _green,
            ),
          ),

          // Floating rocket
          Positioned(
            left: 5,
            bottom: 10,
            child: _floatingBadge(
              Icons.rocket_launch_rounded,
              _orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _textTertiary,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingBadge(IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildTrustPill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: const BoxDecoration(
              color: Color(0xFFEAFBF3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: _green,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Built for serious aspirants',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 2 — FEATURES
  // ---------------------------------------------------------------------------

  Widget _buildFeaturesPage() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
        child: Column(
          children: [
            _buildPageHeading(
              eyebrow: 'ONE PLATFORM',
              title: 'Everything you need\nto prepare smarter.',
              subtitle:
                  'Practice like the real exam. Analyse mistakes. Improve every day.',
            ),

            const SizedBox(height: 22),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildPremiumFeature(
                      icon: Icons.monitor_rounded,
                      iconColor: _primary,
                      title: 'Real CBT Experience',
                      description:
                          'Exam-like timer, question palette, navigation aur negative marking.',
                      tag: 'EXAM MODE',
                    ),
                    const SizedBox(height: 12),

                    _buildPremiumFeature(
                      icon: Icons.psychology_rounded,
                      iconColor: _purple,
                      title: 'Smart Mistake Analysis',
                      description:
                          'Tricky questions aur common mistakes identify karke accuracy improve karein.',
                      tag: 'SMART AI',
                    ),
                    const SizedBox(height: 12),

                    _buildPremiumFeature(
                      icon: Icons.groups_rounded,
                      iconColor: _green,
                      title: 'Coaching & Batch Sync',
                      description:
                          'Apne institute ke batch ke saath tests aur performance seamlessly sync karein.',
                      tag: 'CONNECTED',
                    ),
                    const SizedBox(height: 12),

                    _buildPremiumFeature(
                      icon: Icons.bolt_rounded,
                      iconColor: _orange,
                      title: 'Daily Fast Practice',
                      description:
                          'Current affairs, formulas aur quick drills se daily preparation consistent rakhein.',
                      tag: '10 MIN DAILY',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildPrimaryButton(
              label: 'Create My Profile',
              icon: Icons.arrow_forward_rounded,
              onPressed: _goNext,
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeading({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            eyebrow,
            style: const TextStyle(
              color: _primary,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 26,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumFeature({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String tag,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 6.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10.5,
                    height: 1.4,
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
  // PAGE 3 — PROFILE
  // ---------------------------------------------------------------------------

  Widget _buildProfilePage() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _fadeController,
          curve: Curves.easeOut,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildProfileHeader(),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withValues(alpha: 0.045),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
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

                      const SizedBox(height: 17),

                      _buildInputLabel(
                        'MOBILE NUMBER',
                        required: false,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Optional • Useful for coaching & classroom sync',
                        style: TextStyle(
                          color: _textTertiary,
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

                          if (!RegExp(r'^[6-9]\d{9}$')
                              .hasMatch(value.trim())) {
                            return 'Enter a valid 10-digit number';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildPrivacyNote(),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                _buildPrimaryButton(
                  label: _isLoading
                      ? 'Setting up your preparation...'
                      : 'Start My Preparation',
                  icon: Icons.rocket_launch_rounded,
                  onPressed: _isLoading ? null : _completeRegistration,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 8),

                const Text(
                  'You can update your profile later from Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textTertiary,
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
                Color(0xFFF0EAFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
          'Let’s personalize your journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Your name will appear on scorecards,\nrank lists and your preparation dashboard.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            color: _textPrimary,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFD92D20),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _textTertiary,
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
        border: Border.all(
          color: _border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: _primaryLight,
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
              'Your information is used only to personalize your '
              'MockTester experience and sync your classroom profile.',
              style: TextStyle(
                color: _textSecondary,
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

  // ---------------------------------------------------------------------------
  // PRIMARY BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(
                  colors: [
                    Color(0xFF98A2B3),
                    Color(0xFF98A2B3),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFF155EEF),
                    Color(0xFF0040C1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
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

  // ---------------------------------------------------------------------------
  // BOTTOM PROGRESS
  // ---------------------------------------------------------------------------

  Widget _buildBottomProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 5, 24, 14),
      child: Row(
        children: [
          Text(
            '${_currentIndex + 1} / 3',
            style: const TextStyle(
              color: _textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 5,
                color: const Color(0xFFE4E7EC),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (_currentIndex + 1) / 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF155EEF),
                            Color(0xFF7F56D9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            _currentIndex == 0
                ? 'Welcome'
                : _currentIndex == 1
                    ? 'Features'
                    : 'Profile',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
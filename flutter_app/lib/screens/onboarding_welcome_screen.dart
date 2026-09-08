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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  late AnimationController _floatController;
  late AnimationController _entryController;

  int _currentPage = 0;
  bool _isLoading = false;

  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------

  static const Color bg = Color(0xFFF7F9FC);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color faint = Color(0xFF98A2B3);

  static const Color blue = Color(0xFF155EEF);
  static const Color blueDeep = Color(0xFF0039B7);
  static const Color violet = Color(0xFF6941C6);

  static const Color green = Color(0xFF12B76A);
  static const Color orange = Color(0xFFF79009);

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _floatController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // REGISTRATION
  // ===========================================================================

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
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Registration error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  void _profile() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  // ===========================================================================
  // ROOT
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (value) {
                    setState(() => _currentPage = value);

                    _entryController
                      ..reset()
                      ..forward();
                  },
                  children: [
                    _pageOne(),
                    _pageTwo(),
                    _pageThree(),
                  ],
                ),
              ),

              _bottomProgress(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 13, 18, 8),
      child: Row(
        children: [
          // Minimal brand instead of boxed logo.
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'mock',
                  style: TextStyle(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                TextSpan(
                  text: 'tester',
                  style: TextStyle(
                    color: blue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          if (_currentPage < 2)
            GestureDetector(
              onTap: _profile,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFFE4E7EC),
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 1
  // ===========================================================================

  Widget _pageOne() {
    return FadeTransition(
      opacity: _entryController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Small eyebrow
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'BUILT FOR SERIOUS ASPIRANTS',
                    style: TextStyle(
                      color: muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Large typography.
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your exam.\nYour edge.',
                style: TextStyle(
                  color: ink,
                  fontSize: 43,
                  height: .98,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.4,
                ),
              ),
            ),

            const SizedBox(height: 11),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Practice in a real CBT environment.\n'
                'Build speed, accuracy and confidence.',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: _examDashboard(),
            ),

            const SizedBox(height: 10),

            _blueButton(
              'Enter MockTester',
              Icons.arrow_forward_rounded,
              _next,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EXAM DASHBOARD VISUAL
  // ===========================================================================

  Widget _examDashboard() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, child) {
        final y = lerpDouble(
          -5,
          5,
          _floatController.value,
        )!;

        return Transform.translate(
          offset: Offset(0, y),
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Large gradient backdrop.
          Positioned(
            top: 20,
            left: 7,
            right: 7,
            bottom: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE8F1FF),
                    Color(0xFFF0ECFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(34),
              ),
            ),
          ),

          // Dashboard
          Positioned(
            top: 37,
            left: 17,
            right: 17,
            bottom: 20,
            child: Transform.rotate(
              angle: -.012,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: ink.withValues(alpha: .12),
                      blurRadius: 35,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: blue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BPSC Full Mock',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Question 48 of 150',
                                style: TextStyle(
                                  color: faint,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '01:24:18',
                          style: TextStyle(
                            color: ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 60,
                        height: 5,
                        decoration: BoxDecoration(
                          color: blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Which of the following is known as '
                        'the "Sorrow of Bihar"?',
                        style: TextStyle(
                          color: ink,
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _answer('A', 'Kosi River', true),
                    const SizedBox(height: 6),
                    _answer('B', 'Ganga River', false),
                    const SizedBox(height: 6),
                    _answer('C', 'Son River', false),

                    const Spacer(),

                    Row(
                      children: [
                        _miniStat('68%', 'Accuracy'),
                        const SizedBox(width: 7),
                        _miniStat('↑ 12', 'Rank'),
                        const SizedBox(width: 7),
                        _miniStat('24', 'Correct'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Score badge
          Positioned(
            right: 1,
            top: 5,
            child: _floatingBadge(
              icon: Icons.trending_up_rounded,
              title: '+12',
              subtitle: 'Rank',
              color: green,
            ),
          ),

          // CBT badge
          Positioned(
            left: 1,
            bottom: 8,
            child: _floatingBadge(
              icon: Icons.verified_rounded,
              title: 'REAL',
              subtitle: 'CBT Mode',
              color: blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _answer(
    String letter,
    String text,
    bool selected,
  ) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFEAF2FF)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected
              ? blue.withValues(alpha: .3)
              : const Color(0xFFEAECF0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? blue : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? blue : const Color(0xFFD0D5DD),
              ),
            ),
            child: Text(
              letter,
              style: TextStyle(
                color: selected ? Colors.white : muted,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: selected ? blueDeep : muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    String value,
    String label,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: ink,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: faint,
                fontSize: 6.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingBadge({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: ink.withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: faint,
                      fontSize: 6.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PAGE 2 — COACHING → DIGITAL
  // ===========================================================================

  Widget _pageTwo() {
    return FadeTransition(
      opacity: _entryController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 5),
        child: Column(
          children: [
            const SizedBox(height: 6),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'FROM CLASSROOM',
                style: TextStyle(
                  color: blue,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 7),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'To digital.\nWithout losing the teacher.',
                style: TextStyle(
                  color: ink,
                  fontSize: 31,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
            ),

            const SizedBox(height: 9),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your local coaching can now deliver mocks, '
                'track performance and keep students connected — '
                'right inside MockTester.',
                style: TextStyle(
                  color: muted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 19),

            Expanded(
              child: _coachingTransformation(),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _simpleBenefit(
                  Icons.flash_on_rounded,
                  'Live Mocks',
                  blue,
                ),
                const SizedBox(width: 8),
                _simpleBenefit(
                  Icons.analytics_rounded,
                  'Performance',
                  violet,
                ),
                const SizedBox(width: 8),
                _simpleBenefit(
                  Icons.translate_rounded,
                  'Bilingual',
                  orange,
                ),
              ],
            ),

            const SizedBox(height: 13),

            _blueButton(
              'Continue',
              Icons.arrow_forward_rounded,
              _next,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _coachingTransformation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background stage
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0B2A78),
                Color(0xFF17104D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
        ),

        Positioned(
          top: -35,
          right: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          bottom: -45,
          left: -35,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: violet.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _coachingSide(),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),

                  Expanded(
                    child: _digitalSide(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                height: 1,
                color: Colors.white.withValues(alpha: .12),
              ),

              const SizedBox(height: 18),

              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF32D583),
                    size: 16,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Coaching test → Digital mock → Result → Analysis',
                      style: TextStyle(
                        color: Color(0xFFD0D5DD),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coachingSide() {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(height: 11),
        const Text(
          'YOUR\nCOACHING',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Local',
          style: TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _digitalSide() {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2585FF),
                Color(0xFF6941C6),
              ],
            ),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Icon(
            Icons.phone_android_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(height: 11),
        const Text(
          'MOCK\nTESTER',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Digital',
          style: TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _simpleBenefit(
    IconData icon,
    String text,
    Color color,
  ) {
    return Expanded(
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFE4E7EC),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 17,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: ink,
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PAGE 3 — CONVERSATIONAL PROFILE
  // ===========================================================================

  Widget _pageThree() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: FadeTransition(
        opacity: _entryController,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Number
                      const Text(
                        '03',
                        style: TextStyle(
                          color: blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'First,\nwhat should we call you?',
                        style: TextStyle(
                          color: ink,
                          fontSize: 34,
                          height: 1.03,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.6,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Your name will appear on your scorecard '
                        'and personalised experience.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      _conversationField(
                        label: 'MY NAME IS',
                        controller: _nameController,
                        hint: 'Your full name',
                        icon: Icons.person_outline_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null ||
                              value.trim().length < 2) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      _conversationField(
                        label: 'MOBILE NUMBER',
                        controller: _phoneController,
                        hint: '10-digit number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return null;
                          }

                          if (!RegExp(r'^[6-9]\d{9}$')
                              .hasMatch(value.trim())) {
                            return 'Enter a valid 10-digit number';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: faint,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Optional — useful when your coaching centre '
                              'uses MockTester.',
                              style: TextStyle(
                                color: faint,
                                fontSize: 8.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 35),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.rocket_launch_rounded,
                              color: blue,
                              size: 19,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ready? Your preparation starts here.',
                                style: TextStyle(
                                  color: blueDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky action area
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: .96),
              ),
              child: _blueButton(
                _isLoading
                    ? 'Setting up...'
                    : 'Start My Preparation',
                Icons.arrow_forward_rounded,
                _isLoading ? null : _completeRegistration,
                loading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          inputFormatters: formatters,
          validator: validator,
          cursorColor: blue,
          style: const TextStyle(
            color: ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFB0B7C3),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color: blue,
              size: 21,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE4E7EC),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE4E7EC),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: blue,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFD92D20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BUTTON
  // ===========================================================================

  Widget _blueButton(
    String text,
    IconData icon,
    VoidCallback? onPressed, {
    bool loading = false,
  }) {
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFF2585FF),
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
          borderRadius: BorderRadius.circular(17),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: blue.withValues(alpha: .22),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: loading
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
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
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

  Widget _bottomProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 3, 22, 13),
      child: Row(
        children: [
          Text(
            '0${_currentPage + 1}',
            style: const TextStyle(
              color: ink,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Row(
              children: List.generate(
                3,
                (index) {
                  final active = index == _currentPage;
                  final completed = index < _currentPage;

                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      margin: EdgeInsets.only(
                        right: index == 2 ? 0 : 5,
                      ),
                      height: active ? 4 : 3,
                      decoration: BoxDecoration(
                        color: active || completed
                            ? blue
                            : const Color(0xFFE4E7EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 10),

          Text(
            '03',
            style: TextStyle(
              color: _currentPage == 2 ? blue : faint,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
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

  // ===========================================================================
  // PREMIUM PALETTE
  // ===========================================================================

  static const Color bg = Color(0xFFF7F9FC);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color faint = Color(0xFF98A2B3);

  static const Color blue = Color(0xFF155EEF);
  static const Color blueDeep = Color(0xFF0039B7);
  static const Color blueLight = Color(0xFFEAF2FF);

  static const Color violet = Color(0xFF6941C6);
  static const Color green = Color(0xFF12B76A);
  static const Color orange = Color(0xFFF79009);

  static const Color border = Color(0xFFE4E7EC);

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();

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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

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
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });

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
  // HEADER / BRAND
  // ===========================================================================

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 13, 18, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2585FF),
                  Color(0xFF0047D9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: .18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          const Text(
            'MockTester',
            style: TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.65,
            ),
          ),

          const SizedBox(width: 7),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'CBT',
              style: TextStyle(
                color: Color(0xFFB54708),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
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
                    color: border,
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
            const SizedBox(height: 9),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PREPARE SMARTER WITH MOCKTESTER',
                style: TextStyle(
                  color: blue,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                ),
              ),
            ),

            const SizedBox(height: 13),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your exam.\nYour edge.',
                style: TextStyle(
                  color: ink,
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.15,
                ),
              ),
            ),

            const SizedBox(height: 10),

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

            const SizedBox(height: 16),

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
  // EXAM DASHBOARD
  // ===========================================================================

  Widget _examDashboard() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, child) {
        final y = lerpDouble(
          -4,
          4,
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
          Positioned(
            top: 18,
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

          Positioned(
            top: 34,
            left: 17,
            right: 17,
            bottom: 19,
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
                            color: blueLight,
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

                    _answer(
                      'A',
                      'Kosi River',
                      true,
                    ),

                    const SizedBox(height: 6),

                    _answer(
                      'B',
                      'Ganga River',
                      false,
                    ),

                    const SizedBox(height: 6),

                    _answer(
                      'C',
                      'Son River',
                      false,
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        _miniStat(
                          '68%',
                          'Accuracy',
                        ),
                        const SizedBox(width: 7),
                        _miniStat(
                          '↑ 12',
                          'Rank',
                        ),
                        const SizedBox(width: 7),
                        _miniStat(
                          '24',
                          'Correct',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: 1,
            top: 3,
            child: _floatingBadge(
              icon: Icons.trending_up_rounded,
              title: '+12',
              subtitle: 'Rank',
              color: green,
            ),
          ),

          Positioned(
            left: 1,
            bottom: 7,
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
            ? blueLight
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
              color: selected
                  ? blue
                  : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? blue
                    : const Color(0xFFD0D5DD),
              ),
            ),
            child: Text(
              letter,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : muted,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            text,
            style: TextStyle(
              color: selected
                  ? blueDeep
                  : muted,
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
        padding: const EdgeInsets.symmetric(
          vertical: 7,
        ),
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
            color: Colors.white.withValues(alpha: .94),
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
  // PAGE 2 (REDESIGNED FOR CLEAR MESSAGING)
  // ===========================================================================

  Widget _pageTwo() {
    return FadeTransition(
      opacity: _entryController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          5,
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),

            // -----------------------------------------------------------------
            // SECTION LABEL
            // -----------------------------------------------------------------

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'YOUR COACHING GOES ONLINE',
                style: TextStyle(
                  color: blue,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 7),

            // -----------------------------------------------------------------
            // HEADLINE
            // -----------------------------------------------------------------

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aapki Apni Coaching,\nAb Digital Mock Tests Par.',
                style: TextStyle(
                  color: ink,
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              ),
            ),

            const SizedBox(height: 9),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Padhai wahi aapke classroom teachers se, practice official exam-level CBT portal par.',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // -----------------------------------------------------------------
            // TRANSFORMATION VISUAL
            // -----------------------------------------------------------------

            Expanded(
              child: _coachingTransformation(),
            ),

            const SizedBox(height: 12),

            // -----------------------------------------------------------------
            // READABLE BENEFITS
            // -----------------------------------------------------------------

            Row(
              children: [
                _premiumBenefit(
                  Icons.menu_book_rounded,
                  'Teacher Tests',
                  'Coaching faculty papers',
                  blue,
                ),
                const SizedBox(width: 9),
                _premiumBenefit(
                  Icons.timer_outlined,
                  'Exam Mode',
                  'Negative marking & rank',
                  violet,
                ),
                const SizedBox(width: 9),
                _premiumBenefit(
                  Icons.query_stats_rounded,
                  'Instant Score',
                  'Solutions & rank sheet',
                  green,
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

  // ===========================================================================
  // COACHING TRANSFORMATION (REDESIGNED)
  // ===========================================================================

  Widget _coachingTransformation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0A1C47),
                Color(0xFF140D36),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),

        // Glow effects
        Positioned(
          top: -25,
          right: -25,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: .22),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          bottom: -35,
          left: -25,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: violet.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Core Visual Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _pillarCard(
                      icon: Icons.school_rounded,
                      iconBg: const Color(0xFF2E90FA),
                      tag: 'OFFLINE',
                      tagColor: const Color(0xFF53B1FD),
                      title: 'Aapke Teachers',
                      desc: 'Classroom teaching & doubt sessions',
                    ),
                  ),

                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .15),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  Expanded(
                    child: _pillarCard(
                      icon: Icons.laptop_chromebook_rounded,
                      iconBg: const Color(0xFF7F56D9),
                      tag: 'ONLINE',
                      tagColor: const Color(0xFF9B8AFB),
                      title: 'MockTester',
                      desc: 'Real exam pattern CBT tests',
                    ),
                  ),
                ],
              ),

              // Bottom Integration Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12B76A).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF32D583),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Guidance + Modern CBT Tech',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Teacher ke questions direct aapke mobile screen par',
                            style: TextStyle(
                              color: Color(0xFF98A2B3),
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pillarCard({
    required IconData icon,
    required Color iconBg,
    required String tag,
    required Color tagColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconBg,
                  size: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 8,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PREMIUM BENEFIT CARDS
  // ===========================================================================

  Widget _premiumBenefit(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.fromLTRB(
          10,
          11,
          8,
          10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .025),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                color: color,
                size: 17,
              ),
            ),

            const Spacer(),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ink,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: muted,
                fontSize: 7.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PAGE 3
  // ===========================================================================

  Widget _pageThree() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: FadeTransition(
        opacity: _entryController,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  22,
                  20,
                  22,
                  20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.25,
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

                      // NAME
                      _conversationField(
                        label: 'MY NAME IS',
                        controller: _nameController,
                        hint: 'Your full name',
                        icon: Icons.person_outline_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Please enter your name';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // MOBILE
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
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }

                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
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
                              'Optional — useful when your coaching '
                              'centre uses MockTester.',
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
                          color: blueLight,
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

            Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                10,
              ),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: .96),
              ),
              child: _blueButton(
                _isLoading ? 'Setting up...' : 'Start My Preparation',
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

  // ===========================================================================
  // FORM FIELD
  // ===========================================================================

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
                color: border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: border,
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
  // PREMIUM BLUE BUTTON
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
  // PROGRESS
  // ===========================================================================

  Widget _bottomProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        3,
        22,
        13,
      ),
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

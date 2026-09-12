import 'dart:math' as math;

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

class _OnboardingWelcomeScreenState
    extends State<OnboardingWelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  late AnimationController _introController;
  late AnimationController _floatController;
  late AnimationController _formController;

  int _currentPage = 0;
  bool _isLoading = false;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color bg = Color(0xFFF8FAFC);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color faint = Color(0xFF98A2B3);

  static const Color blue = Color(0xFF155EEF);
  static const Color blueDeep = Color(0xFF0039B7);
  static const Color blueLight = Color(0xFFEAF2FF);

  static const Color border = Color(0xFFE4E7EC);

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _setSystemUi();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1100,
      ),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 650,
      ),
    );

    Future.delayed(
      const Duration(milliseconds: 150),
      () {
        if (mounted) {
          _introController.forward();
        }
      },
    );
  }

  void _setSystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();

    _introController.dispose();
    _floatController.dispose();
    _formController.dispose();

    super.dispose();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _nextPage() {
    FocusScope.of(context).unfocus();

    _pageController.animateToPage(
      1,
      duration: const Duration(
        milliseconds: 600,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  void _pageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    if (page == 1) {
      _formController
        ..reset()
        ..forward();
    }
  }

  // ============================================================
  // ROOT
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (_, __) {
                  return CustomPaint(
                    painter: _BackgroundPainter(
                      _floatController.value,
                    ),
                  );
                },
              ),
            ),

            // ==================================================
            // FULL SCREEN PAGE VIEW
            // ==================================================

            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics:
                    const BouncingScrollPhysics(),
                onPageChanged: _pageChanged,
                children: [
                  _welcomeScreen(),
                  _nameScreen(),
                ],
              ),
            ),

            // ==================================================
            // HEADER
            // ==================================================

            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                      10,
              left: 22,
              right: 22,
              child: _header(),
            ),

            // ==================================================
            // PROGRESS
            // ==================================================

            Positioned(
              left: 22,
              right: 22,
              bottom:
                  MediaQuery.of(context).padding.bottom +
                      12,
              child: _bottomProgress(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2585FF),
                Color(0xFF0047D9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: blue.withOpacity(.18),
                blurRadius: 14,
                offset:
                    const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        const Text(
          'MockTester',
          style: TextStyle(
            color: ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),

        const SizedBox(width: 7),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color:
                const Color(0xFFFFF4E5),
            borderRadius:
                BorderRadius.circular(6),
          ),
          child: const Text(
            'CBT',
            style: TextStyle(
              color:
                  Color(0xFFB54708),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
        ),

        const Spacer(),

        Text(
          '0${_currentPage + 1} / 02',
          style: const TextStyle(
            color: faint,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SCREEN 1 — WELCOME
  // ============================================================

  Widget _welcomeScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top:
                MediaQuery.of(context).padding.top +
                    100,
            bottom:
                MediaQuery.of(context).padding.bottom +
                    75,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight -
                      MediaQuery.of(context)
                          .padding
                          .top -
                      MediaQuery.of(context)
                          .padding
                          .bottom -
                      50,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                FadeSlide(
                  animation:
                      _introController,
                  delay: .05,
                  child: const Text(
                    'YOUR PREPARATION STARTS HERE',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: blue,
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 1.45,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                _AnimatedTitle(
                  text:
                      'Welcome to MockTester',
                  animation:
                      _introController,
                ),

                const SizedBox(height: 17),

                FadeSlide(
                  animation:
                      _introController,
                  delay: .40,
                  child: const Text(
                    'Padhai Pe Sabka Haq Hai',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: -.3,
                    ),
                  ),
                ),

                const SizedBox(height: 11),

                FadeSlide(
                  animation:
                      _introController,
                  delay: .52,
                  child: const Text(
                    'Bihar ke sabhi exams ki latest mock test series, '
                    'ab ek hi app par.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.55,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                FadeSlide(
                  animation:
                      _introController,
                  delay: .22,
                  child: _studyVisual(),
                ),

                const SizedBox(height: 25),

                FadeSlide(
                  animation:
                      _introController,
                  delay: .72,
                  child: _primaryButton(
                    text: 'Continue',
                    icon:
                        Icons.arrow_forward_rounded,
                    onTap: _nextPage,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // VISUAL
  // ============================================================

  Widget _studyVisual() {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 145,
            height: 145,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  blue.withOpacity(.045),
            ),
          ),

          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFFEAF2FF),
                  Color(0xFFDCEAFF),
                ],
              ),
              border: Border.all(
                color:
                    const Color(0xFFB9D3FF),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      blue.withOpacity(.09),
                  blurRadius: 25,
                  offset:
                      const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: blue,
              size: 43,
            ),
          ),

          Positioned(
            left: 35,
            top: 17,
            child: _floatingIcon(
              Icons.check_rounded,
              const Color(0xFF12B76A),
            ),
          ),

          Positioned(
            right: 32,
            bottom: 14,
            child: _floatingIcon(
              Icons.trending_up_rounded,
              const Color(0xFF6941C6),
            ),
          ),

          Positioned(
            right: 44,
            top: 12,
            child: _floatingIcon(
              Icons.timer_outlined,
              blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingIcon(
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 37,
      height: 37,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 17,
      ),
    );
  }

  // ============================================================
  // SCREEN 2 — NAME ENTRY
  // ============================================================

  Widget _nameScreen() {
    return FadeTransition(
      opacity: _formController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin:
              const Offset(0, .035),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent:
                _formController,
            curve:
                Curves.easeOutCubic,
          ),
        ),
        child: GestureDetector(
          onTap: () =>
              FocusScope.of(context)
                  .unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
              physics:
                  const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22,
                MediaQuery.of(context)
                        .padding
                        .top +
                    95,
                22,
                MediaQuery.of(context)
                        .padding
                        .bottom +
                    80,
              ),
              children: [
                const Text(
                  '02',
                  style: TextStyle(
                    color: blue,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 17),

                const Text(
                  'First,\nwhat should we call you?',
                  style: TextStyle(
                    color: ink,
                    fontSize: 34,
                    height: 1.04,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: -1.25,
                  ),
                ),

                const SizedBox(height: 12),

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

                _inputField(
                  label: 'MY NAME IS',
                  controller:
                      _nameController,
                  hint: 'Your full name',
                  icon:
                      Icons.person_outline_rounded,
                  capitalization:
                      TextCapitalization.words,
                  validator: (value) {
                    if (value == null ||
                        value.trim().length < 2) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                _inputField(
                  label: 'MOBILE NUMBER',
                  controller:
                      _phoneController,
                  hint: '10-digit number',
                  icon:
                      Icons.phone_android_rounded,
                  keyboardType:
                      TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter
                        .digitsOnly,
                    LengthLimitingTextInputFormatter(
                      10,
                    ),
                  ],
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return null;
                    }

                    if (!RegExp(
                      r'^[6-9]\d{9}$',
                    ).hasMatch(
                      value.trim(),
                    )) {
                      return 'Enter a valid 10-digit number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: faint,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Mobile number is optional.',
                      style: TextStyle(
                        color: faint,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: blueLight,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          blue.withOpacity(.08),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons
                            .rocket_launch_rounded,
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
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                _primaryButton(
                  text: _isLoading
                      ? 'Setting up...'
                      : 'Start My Preparation',
                  icon:
                      Icons.arrow_forward_rounded,
                  onTap: _isLoading
                      ? null
                      : _completeRegistration,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT FIELD
  // ============================================================

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization =
        TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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
          textCapitalization:
              capitalization,
          inputFormatters:
              formatters,
          validator: validator,
          cursorColor: blue,
          style: const TextStyle(
            color: ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          decoration:
              InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(
              color:
                  Color(0xFFB0B7C3),
              fontSize: 17,
              fontWeight:
                  FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color: blue,
              size: 21,
            ),
            filled: true,
            fillColor:
                Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  const BorderSide(
                color: border,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  const BorderSide(
                color: border,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  const BorderSide(
                color: blue,
                width: 1.5,
              ),
            ),
            errorBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFFD92D20),
              ),
            ),
            focusedErrorBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFFD92D20),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REGISTRATION
  // ============================================================

  Future<void> _completeRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() ||
        _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name =
        _nameController.text.trim();

    final phone =
        _phoneController.text.trim();

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setBool(
        'is_onboarded',
        true,
      );

      await prefs.setString(
        'custom_aspirant_name',
        name,
      );

      await prefs.setString(
        'user_name',
        name,
      );

      if (phone.isNotEmpty) {
        await prefs.setString(
          'user_mobile',
          phone,
        );
      }

      // ========================================================
      // SUPABASE SYNC
      // ========================================================

      if (phone.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('app_users')
              .upsert({
            'mobile_number': phone,
            'full_name': name,
            'updated_at':
                DateTime.now()
                    .toIso8601String(),
          });
        } catch (e) {
          debugPrint(
            'Supabase sync issue: $e',
          );
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration:
              const Duration(
            milliseconds: 450,
          ),
          pageBuilder:
              (_, __, ___) =>
                  widget.nextScreen,
          transitionsBuilder:
              (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      debugPrint(
        'Registration error: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
          behavior:
              SnackBarBehavior.floating,
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

  // ============================================================
  // BUTTON
  // ============================================================

  Widget _primaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration:
            const Duration(milliseconds: 200),
        opacity:
            onTap == null ? .55 : 1,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFF2585FF),
                Color(0xFF0047D9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color:
                    blue.withOpacity(.22),
                blurRadius: 20,
                offset:
                    const Offset(0, 9),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        width: 9,
                      ),
                      Icon(
                        icon,
                        color:
                            Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _bottomProgress() {
    return Row(
      children: [
        AnimatedContainer(
          duration:
              const Duration(milliseconds: 350),
          width:
              _currentPage == 0 ? 34 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: blue,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),

        const SizedBox(width: 5),

        AnimatedContainer(
          duration:
              const Duration(milliseconds: 350),
          width:
              _currentPage == 1 ? 34 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: _currentPage == 1
                ? blue
                : const Color(
                    0xFFE4E7EC,
                  ),
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),

        const Spacer(),

        Text(
          _currentPage == 0
              ? '01 / 02'
              : '02 / 02',
          style: const TextStyle(
            color: faint,
            fontSize: 9,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ANIMATED TITLE
// ============================================================================

class _AnimatedTitle extends StatelessWidget {
  final String text;
  final AnimationController animation;

  const _AnimatedTitle({
    required this.text,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final value =
            Curves.easeOutCubic.transform(
          animation.value,
        );

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              18 * (1 - value),
            ),
            child: Transform.scale(
              scale:
                  .965 + (.035 * value),
              child: Text(
                text,
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 34,
                  height: 1.08,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -1.3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// FADE SLIDE
// ============================================================================

class FadeSlide extends StatelessWidget {
  final AnimationController animation;
  final double delay;
  final Widget child;

  const FadeSlide({
    super.key,
    required this.animation,
    required this.child,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final raw =
            ((animation.value - delay) /
                    (1 - delay))
                .clamp(0.0, 1.0);

        final value =
            Curves.easeOutCubic.transform(
          raw,
        );

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              12 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ============================================================================
// BACKGROUND PAINTER
// ============================================================================

class _BackgroundPainter
    extends CustomPainter {
  final double animation;

  _BackgroundPainter(this.animation);

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final bluePaint = Paint()
      ..color = const Color(0xFF155EEF)
          .withOpacity(.035);

    final violetPaint = Paint()
      ..color = const Color(0xFF6941C6)
          .withOpacity(.025);

    final move1 =
        math.sin(
              animation * math.pi * 2,
            ) *
            18;

    final move2 =
        math.cos(
              animation * math.pi * 2,
            ) *
            15;

    canvas.drawCircle(
      Offset(
        size.width + 30,
        100 + move1,
      ),
      120,
      bluePaint,
    );

    canvas.drawCircle(
      Offset(
        -35,
        size.height - 90 + move2,
      ),
      140,
      violetPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _BackgroundPainter oldDelegate,
  ) {
    return oldDelegate.animation !=
        animation;
  }
}
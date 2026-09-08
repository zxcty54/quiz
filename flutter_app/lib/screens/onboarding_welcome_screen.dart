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
  final PageController _featurePageController =
      PageController(viewportFraction: 0.86);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  int _currentIndex = 0;
  int _featureIndex = 0;
  bool _isLoading = false;

  late final AnimationController _contentAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;

  static const Color _primary = Color(0xFF0038B8);
  static const Color _primaryDark = Color(0xFF002B8A);
  static const Color _primarySoft = Color(0xFFEFF6FF);

  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const Color _saffron = Color(0xFFFEA619);
  static const Color _saffronDark = Color(0xFF855300);

  static const List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.laptop_chromebook_rounded,
      title: 'Real CBT Engine',
      desc:
          'Timer, question palette aur negative marking ke saath real exam jaisa practice.',
      color: Color(0xFF0284C7),
    ),
    _FeatureData(
      icon: Icons.psychology_rounded,
      title: 'AI Trap Vault',
      desc:
          'Tricky options aur common silly mistakes identify karke accuracy improve karein.',
      color: Color(0xFFD97706),
    ),
    _FeatureData(
      icon: Icons.groups_rounded,
      title: 'Coaching Hub',
      desc:
          'Batch code se coaching se connect karein aur assigned tests online attempt karein.',
      color: Color(0xFF059669),
    ),
    _FeatureData(
      icon: Icons.menu_book_rounded,
      title: 'Daily Practice',
      desc:
          'Current affairs capsules, formulas aur quick drills se daily preparation maintain karein.',
      color: _primary,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _contentAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _contentAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _featurePageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  void _goToNextSlide() {
    if (_currentIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToPreviousSlide() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    _contentAnimationController
      ..reset()
      ..forward();
  }

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
          const SnackBar(
            content: Text(
              'Profile save nahi ho paya. Please try again.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  _buildWelcomePage(),
                  _buildFeaturesPage(),
                  _buildRegistrationPage(),
                ],
              ),
            ),
            _buildBottomProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _currentIndex > 0
                ? _NavCircleButton(
                    key: const ValueKey('back'),
                    icon: Icons.arrow_back_rounded,
                    onTap: _goToPreviousSlide,
                    color: _text,
                    background: _surface,
                    border: _border,
                  )
                : Container(
                    key: const ValueKey('brand'),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          const Text(
            'MockTester',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _saffron.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _saffron.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: const Text(
              'CBT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: _saffronDark,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(),
          if (_currentIndex < 2)
            TextButton(
              onPressed: _skipOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: _muted,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final active = _currentIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 26 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? _primary : _border,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentIndex + 1} of 3',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (_, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(position: _slideAnimation, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),
            _buildPageBadge(
              icon: Icons.verified_rounded,
              text: "BIHAR'S TRUSTED CBT PLATFORM",
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            color: _primarySoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Icon(Icons.school_rounded, color: _primary, size: 42),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _saffron,
                        shape: BoxShape.circle,
                        border: Border.all(color: _bg, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _saffron.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Welcome to',
              style: TextStyle(color: _muted, fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            const Text(
              'MockTester',
              style: TextStyle(
                color: _text,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _primary.withValues(alpha: 0.12)),
              ),
              child: const Column(
                children: [
                  Text(
                    'Bihar Exams • CBT Practice • Better Rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Yahan Test Pass Kiya,\nToh Bihar Mein Selection Pakka!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _text,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _primaryButton(
              label: 'EXPLORE FEATURES',
              icon: Icons.arrow_forward_rounded,
              onPressed: _goToNextSlide,
            ),
            const SizedBox(height: 8),
            const Text(
              'Takes less than a minute to get started',
              style: TextStyle(color: _muted, fontSize: 10.5),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesPage() {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (_, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(position: _slideAnimation, child: child),
        );
      },
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildPageBadge(icon: Icons.bolt_rounded, text: 'BUILT FOR SERIOUS ASPIRANTS'),
          const SizedBox(height: 12),
          const Text(
            'Everything you need\nto practice smarter',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Real exam experience. Better analysis. Daily consistency.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11.5),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: PageView.builder(
              controller: _featurePageController,
              itemCount: _features.length,
              onPageChanged: (i) => setState(() => _featureIndex = i),
              itemBuilder: (_, index) {
                return AnimatedBuilder(
                  animation: _featurePageController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_featurePageController.position.haveDimensions) {
                      final page = _featurePageController.page ?? 0;
                      scale = (1 - ((page - index).abs() * 0.08)).clamp(0.92, 1.0);
                    }
                    return Center(child: Transform.scale(scale: scale, child: child));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _buildFeatureCard(_features[index]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_features.length, (index) {
              final active = _featureIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _features[_featureIndex].color : _border,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _primaryButton(
              label: 'SETUP MY PROFILE',
              icon: Icons.arrow_forward_rounded,
              onPressed: _goToNextSlide,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRegistrationPage() {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (_, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(position: _slideAnimation, child: child),
        );
      },
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(
            children: [
              _buildPageBadge(icon: Icons.person_rounded, text: 'ALMOST READY'),
              const SizedBox(height: 12),
              const Text(
                'Create your\nAspirant Profile',
                textAlign: TextAlign.center,
                style: TextStyle(color: _text, fontSize: 26, height: 1.15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your name will appear on scorecards and rank lists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('FULL NAME', required: true),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 14, color: _text, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration(
                        hint: 'e.g. Anand Sharma',
                        icon: Icons.person_outline_rounded,
                        iconColor: _primary,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Kripya apna naam enter karein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildFieldLabel('MOBILE NUMBER', required: false),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'OPTIONAL',
                            style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: _muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(fontSize: 14, color: _text, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration(
                        hint: '9876543210',
                        icon: Icons.phone_android_rounded,
                        iconColor: _muted,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
                          return 'Valid 10-digit number enter karein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: _muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mobile number sirf classroom sync aur account'
                            ' related features ke liye use hoga.',
                            style: TextStyle(color: _muted, fontSize: 9.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _finalCtaButton(
                label: 'START PREPARATION',
                icon: Icons.rocket_launch_rounded,
                loading: _isLoading,
                onPressed: _isLoading ? null : _completeRegistration,
              ),
              const SizedBox(height: 10),
              const Text(
                'You can update these details later from your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: _primary,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureData feature) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: feature.color.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(feature.icon, color: feature.color, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            feature.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, {required bool required}) {
    return Text(
      required ? '$text *' : text,
      style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: iconColor, size: 19),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.4),
      ),
      errorStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withValues(alpha: 0.55),
          elevation: 0,
          shadowColor: _primary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: loading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.35),
                  ),
                  const SizedBox(width: 9),
                  Icon(icon, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _finalCtaButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: disabled
                ? [_primary.withValues(alpha: 0.5), _primary.withValues(alpha: 0.5)]
                : [_saffron, _primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: _saffron.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Icon(icon, size: 19, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  final Color border;

  const _NavCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: CircleBorder(side: BorderSide(color: border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}
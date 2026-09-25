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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // 📍 Bihar ke sabhi 38 districts
  final List<String> _biharDistricts = const [
    'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur', 'Bhojpur',
    'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad',
    'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura',
    'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia',
    'Rohtas', 'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar',
    'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali', 'West Champaran'
  ];

  String _selectedDistrict = 'Patna';

  late AnimationController _introController;
  late AnimationController _floatController;
  late AnimationController _formController;

  int _currentPage = 0;
  bool _isLoading = false;

  // 🎨 Midnight Sapphire & Indigo Dark Palette
  static const Color bg = Color(0xFF070B14);          // Obsidian Midnight Navy
  static const Color ink = Color(0xFFF1F5F9);         // Primary High-Contrast Text
  static const Color muted = Color(0xFF94A3B8);       // Secondary Text
  static const Color faint = Color(0xFF64748B);       // Subtle Muted Label

  static const Color blue = Color(0xFF38BDF8);        // Electric Horizon Cyan
  static const Color blueDeep = Color(0xFF2563EB);    // Deep Indigo Accent
  static const Color blueLight = Color(0xFF0E1C38);   // Atmospheric Glow / Card Surface

  static const Color border = Color(0x1FFFFFFF);      // Subtle Border

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _introController.forward();
    });
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

  void _nextPage() {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  void _pageChanged(int page) {
    setState(() => _currentPage = page);
    if (page == 1) {
      _formController
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
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
                    painter: _BackgroundPainter(_floatController.value),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _pageChanged,
                children: [
                  _welcomeScreen(),
                  _nameScreen(),
                ],
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 22,
              right: 22,
              child: _header(),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: _bottomProgress(),
            ),
          ],
        ),
      ),
    );
  }

  // Top Minimal Header with Glowing Dot (Screen 1 Image ke anusar)
  Widget _header() {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: blue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: blue.withOpacity(0.8),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'MOCKTESTER',
          style: TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
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

  // SCREEN 1: Exact Layout & Texts from Image
  Widget _welcomeScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: MediaQuery.of(context).padding.top + 70,
            bottom: MediaQuery.of(context).padding.bottom + 85,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  70,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Chart / Analytics Icon Box
                FadeSlide(
                  animation: _introController,
                  delay: .05,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: blue.withOpacity(.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: blue.withOpacity(.25)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: blue,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Main Title: "Welcome to MockTester"
                FadeSlide(
                  animation: _introController,
                  delay: .15,
                  child: const Text(
                    'Welcome to\nMockTester',
                    style: TextStyle(
                      color: ink,
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Tagline: "Bihar's Own Exam Prep Hub"
                FadeSlide(
                  animation: _introController,
                  delay: .30,
                  child: const Text(
                    "Bihar's Own Exam Prep Hub",
                    style: TextStyle(
                      color: blue,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Description Text
                FadeSlide(
                  animation: _introController,
                  delay: .45,
                  child: const Text(
                    'Standardized mock tests with state-level accuracy, timed simulation, and realistic percentile evaluation.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 5. Exam Pills (BPSC CCE, Bihar SI, BSSC CGL , All Bihar Exams)
               FadeSlide(
  animation: _introController,
  delay: .60,
  child: Wrap(
    spacing: 8,
    runSpacing: 10,
    children: [
      _buildExamPill(Icons.track_changes_rounded, 'BPSC CCE'),
      _buildExamPill(Icons.shield_outlined, 'Bihar SI'),
      _buildExamPill(Icons.menu_book_rounded, 'BSSC CGL'),
      _buildExamPill(Icons.auto_awesome_rounded, 'All Bihar Exams'),
    ],
  ),
),
                const SizedBox(height: 36),

                // 6. Continue Button
                FadeSlide(
                  animation: _introController,
                  delay: .72,
                  child: _primaryButton(
                    text: 'Continue',
                    icon: Icons.arrow_forward_rounded,
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

  Widget _buildExamPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0DF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: blue),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // SCREEN 2: Name, District & Mobile Input Form
  Widget _nameScreen() {
    return FadeTransition(
      opacity: _formController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .035),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _formController,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22,
                MediaQuery.of(context).padding.top + 80,
                22,
                MediaQuery.of(context).padding.bottom + 80,
              ),
              children: [
                const Text(
                  '02',
                  style: TextStyle(
                    color: blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.25,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your name & district will appear on your scorecard and district leaderboard.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // 1. Name Field
                _inputField(
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
                const SizedBox(height: 18),

                // 2. District Dropdown Field
                _districtDropdownField(),

                const SizedBox(height: 18),

                // 3. Mobile Number Field
                _inputField(
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x1A38BDF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x3338BDF8),
                    ),
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
                            color: Color(0xFF7DD3FC),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                _primaryButton(
                  text: _isLoading ? 'Setting up...' : 'Start My Preparation',
                  icon: Icons.arrow_forward_rounded,
                  onTap: _isLoading ? null : _completeRegistration,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _districtDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT YOUR DISTRICT',
          style: TextStyle(
            color: faint,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x0DF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedDistrict,
              dropdownColor: const Color(0xFF0E1A2D),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: blue),
              style: const TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              items: _biharDistricts.map((String district) {
                return DropdownMenuItem<String>(
                  value: district,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: blue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(district),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newVal) {
                if (newVal != null) {
                  setState(() => _selectedDistrict = newVal);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
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
            color: faint,
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
              color: Color(0x4DF1F5F9),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: blue, size: 21),
            filled: true,
            fillColor: const Color(0x0DF1F5F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: blue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF87171)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // 🔑 CLEAN USER ID + SUPABASE SYNC IMPLEMENTATION
  Future<void> _completeRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();

      String? userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) {
        const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        final rnd = math.Random();
        final randomCode = List.generate(16, (i) => chars[rnd.nextInt(chars.length)]).join();
        userId = 'usr_$randomCode';
        await prefs.setString('user_id', userId);
      }

      await prefs.setBool('is_onboarded', true);
      await prefs.setString('custom_aspirant_name', name);
      await prefs.setString('user_name', name);
      await prefs.setString('user_district', _selectedDistrict);

      if (phone.isNotEmpty) {
        await prefs.setString('user_mobile', phone);
      }

      try {
        final Map<String, dynamic> userPayload = {
          'user_id': userId,
          'full_name': name,
          'district': _selectedDistrict,
          'mobile_number': phone.isNotEmpty ? phone : 'N/A',
          'updated_at': DateTime.now().toIso8601String(),
        };

        await Supabase.instance.client
            .from('app_users')
            .upsert(userPayload, onConflict: 'user_id');

        debugPrint('✅ Clean User ID and details registered: $userId | $name');
      } catch (e) {
        debugPrint('Supabase sync error (offline fallback intact): $e');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _primaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? .55 : 1,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withOpacity(.3),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Center(
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
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Icon(icon, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _bottomProgress() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: _currentPage == 0 ? 34 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: _currentPage == 1 ? 34 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: _currentPage == 1 ? blue : const Color(0x33F1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const Spacer(),
        Text(
          _currentPage == 0 ? '01 / 02' : '02 / 02',
          style: const TextStyle(
            color: faint,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

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
        final raw = ((animation.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final value = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animation;

  _BackgroundPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final bluePaint = Paint()..color = const Color(0xFF0E1C38).withOpacity(.85);
    final violetPaint = Paint()..color = const Color(0xFF1E1B4B).withOpacity(.6);

    final move1 = math.sin(animation * math.pi * 2) * 18;
    final move2 = math.cos(animation * math.pi * 2) * 15;

    canvas.drawCircle(
      Offset(size.width + 30, 100 + move1),
      150,
      bluePaint,
    );

    canvas.drawCircle(
      Offset(-35, size.height - 90 + move2),
      160,
      violetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

// v1 source: flutter_app/lib/screens/onboarding_welcome_screen.dart
//
// Same two-step flow, same prefs/Supabase logic, new visual language:
//  * animated aurora background (core/widgets/aurora_background.dart) instead
//    of two hand-painted circles,
//  * brand mark + gradient wordmark from core/widgets/brand_mark.dart,
//  * feature tiles so a first-time user sees what the app actually does,
//  * the form step now lives on a translucent sheet with the shared input
//    treatment, and the CTA uses the brand gradient with a glow.
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mocktester_v2/core/theme/app_gradients.dart';
import 'package:mocktester_v2/core/theme/app_tokens.dart';
import 'package:mocktester_v2/core/widgets/aurora_background.dart';
import 'package:mocktester_v2/core/widgets/brand_mark.dart';
import 'package:mocktester_v2/features/shell/presentation/home_shell_screen.dart';

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
  late AnimationController _formController;

  int _currentPage = 0;
  bool _isLoading = false;

  // 🎨 Midnight Sapphire & Indigo Dark Palette (v1 values)
  static const Color bg = Color(0xFF070B14);          // Obsidian Midnight Navy
  static const Color ink = Color(0xFFF1F5F9);         // Primary High-Contrast Text
  static const Color muted = Color(0xFF94A3B8);       // Secondary Text
  static const Color faint = Color(0xFF64748B);       // Subtle Muted Label

  static const Color blue = Color(0xFF38BDF8);        // Electric Horizon Cyan
  static const Color blueDeep = Color(0xFF2563EB);    // Deep Indigo Accent
  static const Color blueLight = Color(0xFF0E1C38);   // Atmospheric Glow / Card Surface

  static const Color border = Color(0x1FFFFFFF);      // Subtle Border

  /// Glass surface used by every card on this screen.
  static Color get glass => Colors.white.withOpacity(0.045);
  static Color get glassStrong => Colors.white.withOpacity(0.075);

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
        backgroundColor: bg,
        body: AuroraBackground(
          intensity: 1.0,
          child: Stack(
            children: [
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
                top: MediaQuery.of(context).padding.top + 14,
                left: 22,
                right: 22,
                child: _header(),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: MediaQuery.of(context).padding.bottom + 14,
                child: _bottomProgress(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header --
  Widget _header() {
    return Row(
      children: [
        const BrandWordmark(fontSize: 11.5, color: ink),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: glass,
            borderRadius: AppRadii.pillAll,
            border: Border.all(color: border),
          ),
          child: Text(
            'SETUP ${_currentPage + 1}/02',
            style: const TextStyle(
              color: blue,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------- SCREEN 1: the welcome --
  Widget _welcomeScreen() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: MediaQuery.of(context).padding.top + 76,
            bottom: MediaQuery.of(context).padding.bottom + 92,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  76,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Brand mark + headline
                FadeSlide(
                  animation: _introController,
                  delay: .05,
                  child: const BrandMark(size: 62),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlide(
                  animation: _introController,
                  delay: .15,
                  child: const Text(
                    'Welcome to\nMockTester',
                    style: TextStyle(
                      color: ink,
                      fontSize: 34,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlide(
                  animation: _introController,
                  delay: .30,
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) =>
                        AppGradients.brand.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      "Bihar's Own Exam Prep Hub",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlide(
                  animation: _introController,
                  delay: .42,
                  child: const Text(
                    'Standardized mock tests with state-level accuracy, timed '
                    'simulation, and realistic percentile evaluation.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 2. What the app gives you (new: v1 jumped straight to pills)
                FadeSlide(
                  animation: _introController,
                  delay: .55,
                  child: Column(
                    children: const <Widget>[
                      _FeatureRow(
                        icon: Icons.timer_outlined,
                        title: 'Live CBT mocks',
                        subtitle: 'Real exam timer, palette & instant percentile',
                        gradient: AppGradients.brand,
                      ),
                      SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.newspaper_rounded,
                        title: 'Daily current affairs',
                        subtitle: 'Bihar + national, jobs aur alerts — roz subah',
                        gradient: AppGradients.study,
                      ),
                      SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI doubt solver',
                        subtitle: 'Photo bhejo, step-by-step explanation pao',
                        gradient: AppGradients.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 3. Exam pills (unchanged copy)
                FadeSlide(
                  animation: _introController,
                  delay: .68,
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
                const SizedBox(height: AppSpacing.xxl),

                // 4. Continue
                FadeSlide(
                  animation: _introController,
                  delay: .78,
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: glass,
        borderRadius: AppRadii.pillAll,
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

  // --------------------------------------------- SCREEN 2: the profile form --
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
                MediaQuery.of(context).padding.top + 82,
                22,
                MediaQuery.of(context).padding.bottom + 92,
              ),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand,
                        borderRadius: AppRadii.xsAll,
                      ),
                      child: const Text(
                        '02',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'YOUR PROFILE',
                      style: TextStyle(
                        color: faint,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'First,\nwhat should we call you?',
                  style: TextStyle(
                    color: ink,
                    fontSize: 32,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your name & district will appear on your scorecard and '
                  'district leaderboard.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // The form sits on a translucent sheet so it reads as one unit.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: glass,
                    borderRadius: AppRadii.lgAll,
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      // 1. Name
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
                      const SizedBox(height: 16),

                      // 2. District
                      _districtDropdownField(),
                      const SizedBox(height: 16),

                      // 3. Mobile (optional)
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
                        helper: 'Optional — sirf leaderboard verification ke liye',
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
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: blue.withOpacity(0.10),
                    borderRadius: AppRadii.mdAll,
                    border: Border.all(color: blue.withOpacity(0.28)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ready? Your preparation starts here.',
                          style: TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

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
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: glassStrong,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedDistrict,
              dropdownColor: const Color(0xFF0E1A2D),
              borderRadius: AppRadii.mdAll,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: blue),
              style: const TextStyle(
                color: ink,
                fontSize: 15.5,
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
                        size: 19,
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

  /// Dark-on-aurora field: the app theme may be in light mode while this
  /// screen is always dark, so the colours are set explicitly (v1 did the same).
  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: faint,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0x4DF1F5F9),
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: blue, size: 20),
            filled: true,
            fillColor: glassStrong,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadii.mdAll,
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.mdAll,
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.mdAll,
              borderSide: const BorderSide(color: blue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadii.mdAll,
              borderSide: const BorderSide(color: Color(0xFFF87171)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadii.mdAll,
              borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
            ),
          ),
        ),
        if (helper != null) ...<Widget>[
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: faint, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  helper,
                  style: const TextStyle(color: faint, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 📱 Device ID Helper function
  Future<String> _getPermanentDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Permanent Android ID
      } else {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios_unknown';
      }
    } catch (_) {
      return 'unknown_device';
    }
  }

  // 🔑 CLEAN USER ID + SUPABASE SYNC IMPLEMENTATION (Device ID Integrated)
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
      final deviceId = await _getPermanentDeviceId();

      // 🔍 1. Agar phone number dala hai, toh pehle check karein
      if (phone.isNotEmpty && (userId == null || userId.isEmpty)) {
        try {
          final existingPhoneUser = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .eq('mobile_number', phone)
              .maybeSingle();

          if (existingPhoneUser != null && existingPhoneUser['user_id'] != null) {
            userId = existingPhoneUser['user_id'].toString();
          }
        } catch (_) {}
      }

      // 🔍 2. Agar phone number NAHI dala, toh Device ID se check karein
      if (userId == null || userId.isEmpty) {
        try {
          final existingDeviceUser = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .eq('device_id', deviceId)
              .maybeSingle();

          if (existingDeviceUser != null && existingDeviceUser['user_id'] != null) {
            userId = existingDeviceUser['user_id'].toString();
          }
        } catch (_) {}
      }

      // 🆕 3. Agar bilkul naya device hai, tabhi fresh user ID generate karein
      if (userId == null || userId.isEmpty) {
        const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        final rnd = math.Random();
        final randomCode = List.generate(16, (i) => chars[rnd.nextInt(chars.length)]).join();
        userId = 'usr_$randomCode';
      }

      await prefs.setString('user_id', userId);
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
          'device_id': deviceId,
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
        duration: AppMotion.fast,
        opacity: onTap == null ? .55 : 1,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: AppRadii.mdAll,
            boxShadow: AppElevation.glow(blueDeep, opacity: 0.32),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
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
        for (int i = 0; i < 2; i++) ...<Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: _currentPage == i ? 34 : 12,
            height: 4,
            decoration: BoxDecoration(
              gradient: _currentPage == i ? AppGradients.brand : null,
              color: _currentPage == i ? null : Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          if (i == 0) const SizedBox(width: 5),
        ],
        const Spacer(),
        Text(
          _currentPage == 0 ? '01 / 02' : '02 / 02',
          style: const TextStyle(
            color: faint,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// One row of the "what you get" list on the welcome step.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

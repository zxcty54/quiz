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
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int _currentIndex = 0;
  bool _isLoading = false;

  // Eye-Friendly Authentic Palette
  static const Color _bgScreen = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _primaryBlue = Color(0xFF0038B8);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _saffronAccent = Color(0xFFFEA619);
  static const Color _saffronDark = Color(0xFF855300);

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
          debugPrint("Supabase sync issue: $e");
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } catch (e) {
      debugPrint("Storage error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToNextSlide() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgScreen,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MockTester',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _saffronAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'CBT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: _saffronDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentIndex < 2)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          2,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3-Slide Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                children: [
                  _buildScreen1Welcome(),
                  _buildScreen2Features(),
                  _buildScreen3Registration(),
                ],
              ),
            ),

            // Light-theme Animated Indicator Dots
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: _currentIndex == index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? _primaryBlue : _borderSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1️⃣ SLIDE 1: Welcome & Bihar Selection Hook
  Widget _buildScreen1Welcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 48,
              color: _primaryBlue,
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Welcome to',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'MockTester',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textDark,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryBlue.withOpacity(0.2)),
            ),
            child: const Text(
              'Yahan Test Pass Kiya,\nToh Bihar Me Selection Pakka!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryBlue,
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const Spacer(flex: 3),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goToNextSlide,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EXPLORE FEATURES',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // 2️⃣ SLIDE 2: Functional Features
  Widget _buildScreen2Features() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            'Platform Features',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Strictly aligned with state competitive exams',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
          const Spacer(),

          _buildFeatureCard(
            Icons.laptop_chromebook_rounded,
            'Real CBT Engine',
            'Same countdown timer, palette, aur negative mark calculation direct TCS pattern par.',
            const Color(0xFF0284C7),
          ),
          const SizedBox(height: 10),

          _buildFeatureCard(
            Icons.warning_amber_rounded,
            'AI Trap Vault',
            'Examiner ke tricky options aur silly mistakes ko identify karke zero negative marks banayein.',
            const Color(0xFFD97706),
          ),
          const SizedBox(height: 10),

          _buildFeatureCard(
            Icons.apartment_rounded,
            'Coaching Hub Sync',
            'Apne coaching institute ke batch code se judein aur class ke tests live online attempt karein.',
            const Color(0xFF059669),
          ),
          const SizedBox(height: 10),

          _buildFeatureCard(
            Icons.menu_book_rounded,
            'Bilingual Daily Practice',
            '10-Minute current affairs capsule aur formula cheat sheets daily fast drill ke liye.',
            _primaryBlue,
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goToNextSlide,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SETUP PROFILE',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // 3️⃣ SLIDE 3: Profile Registration Form
  Widget _buildScreen3Registration() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: _primaryBlue.withOpacity(0.15)),
              ),
              child: const Icon(Icons.badge_rounded, color: _primaryBlue, size: 30),
            ),
            const SizedBox(height: 12),

            const Text(
              'Aspirant Profile',
              style: TextStyle(
                color: _textDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Yeh details aapke CBT scorecard aur rank list par dikhengi',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Name *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _textDark),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 13, color: _textDark),
                    decoration: InputDecoration(
                      hintText: 'e.g. Anand Sharma',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: _bgScreen,
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: _primaryBlue, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSubtle)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSubtle)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue)),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Kripya apna naam enter karein' : null,
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Mobile Number (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _textDark),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(fontSize: 13, color: _textDark),
                    decoration: InputDecoration(
                      hintText: 'e.g. 9876543210 (Classroom sync)',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: _bgScreen,
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: _textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSubtle)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSubtle)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(val.trim())) {
                        return 'Valid 10-digit number enter karein';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'START PREPARATION',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.rocket_launch_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  // Eye-friendly clean feature card builder
  Widget _buildFeatureCard(IconData icon, String title, String desc, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: _textMuted, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

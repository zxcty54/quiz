import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingScreen({
    super.key,
    this.nextScreen = const HomeScreen(),
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int _currentIndex = 0;
  bool _isLoading = false;

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
      duration: const Duration(milliseconds: 320),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B63F6),
              Color(0xFF0647B8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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

              // Bottom Indicator Dots
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => _Dot(active: _currentIndex == index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SCREEN 1: WELCOME & BIHAR SELECTION HOOK
  // -------------------------------------------------------------
  Widget _buildScreen1Welcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 50,
              color: Color(0xFF0B63F6),
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Welcome to',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'MockTester',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 22),

          // Authentic Hook
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Text(
              'Yahan Test Pass Kiya,\nToh Bihar Me Selection Pakka!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const Spacer(flex: 3),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _goToNextSlide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B63F6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EXPLORE FEATURES',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SCREEN 2: ALL REAL APP FEATURES (NO FAKE STATS)
  // -------------------------------------------------------------
  Widget _buildScreen2Features() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'App Features',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Strictly aligned with state competitive syllabus',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFDCE9FF), fontSize: 13),
          ),
          const Spacer(),

          _buildFeatureTile(
            Icons.laptop_chromebook_rounded,
            'Real CBT Engine',
            'Same timer countdown, navigation palette, aur negative mark calculation direct TCS pattern par.',
          ),
          const SizedBox(height: 12),

          _buildFeatureTile(
            Icons.warning_amber_rounded,
            'AI Trap Vault',
            'Examiner ke deceptive options aur recurring silly mistakes ko identify karke zero penalty banayein.',
          ),
          const SizedBox(height: 12),

          _buildFeatureTile(
            Icons.apartment_rounded,
            'Coaching Hub Integration',
            'Apne offline institute ke batch code se judein aur class ke test online mock screen par attempt karein.',
          ),
          const SizedBox(height: 12),

          _buildFeatureTile(
            Icons.menu_book_rounded,
            'Bilingual Daily Practice',
            '10-Minute current affairs capsule aur formula cheat sheets for fast exam drill.',
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _goToNextSlide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B63F6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SETUP PROFILE',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SCREEN 3: ASPIRANT NAME & MOBILE ENTRY
  // -------------------------------------------------------------
  Widget _buildScreen3Registration() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),

            const Text(
              'Aspirant Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Yeh details aapke CBT scorecard aur rank list par dikhengi',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFDCE9FF), fontSize: 12.5),
            ),
            const SizedBox(height: 24),

            // White Floating Input Container
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Name *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0A1128)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Anand Sharma',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF0B63F6), size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Kripya apna naam enter karein' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Mobile Number (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0A1128)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g. 9876543210 (Classroom sync)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: Colors.grey, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0B63F6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B63F6)),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'START PREPARATION',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.rocket_launch_rounded, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Feature Card Builder for Screen 2
  Widget _buildFeatureTile(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0B63F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Color(0xFFDCE9FF), fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;

  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

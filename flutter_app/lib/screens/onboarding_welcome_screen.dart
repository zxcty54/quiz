import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingWelcomeScreen({super.key, required this.nextScreen});

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentPage = 0;

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _darkNavy = Color(0xFF0F172A);

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.bolt_rounded,
      'gradient': [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      'badge': 'EXAM LEVEL CBT SIMULATION',
      'title': 'Real Exam Hall\nCBT Experience',
      'desc': 'BPSC, BSSC aur state exams ke liye timed testing, negative marking calculation aur dynamic question navigation.',
      'highlights': ['⏱️ Sectional Timers', '🎯 Live Negative Penalty', '📊 Instant Scorecard'],
    },
    {
      'icon': Icons.psychology_rounded,
      'gradient': [Color(0xFFDC2626), Color(0xFF991B1B)],
      'badge': 'AI ERROR DIAGNOSTICS',
      'title': 'AI Wrong Question\nVault & Mastery',
      'desc': 'Galtiyon ko bhulne ke bajaye deep trap analysis karein aur 1-click mistake re-quiz se kamzori ko taaqat banayein.',
      'highlights': ['🧠 Trap Detection (50-50)', '🔁 1-Click Re-Quiz', '💬 Socratic AI Doubt Tutor'],
    },
    {
      'icon': Icons.workspace_premium_rounded,
      'gradient': [Color(0xFF059669), Color(0xFF047857)],
      'badge': 'CLASSROOM NETWORK',
      'title': 'Top Institutes &\nPrivate Batches',
      'desc': 'Apne coaching center se judkar exclusive classroom tests, study handouts aur real-time batch percentile dekhein.',
      'highlights': ['🏫 Secret Batch Unlock', '📚 PDF Handouts', '🏆 Wall of Fame Selections'],
    },
  ];

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarded', true);
    await prefs.setString('custom_aspirant_name', name);
    await prefs.setString('student_contact_id', phone.isNotEmpty ? phone : 'N/A');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 Top Action Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_primaryBlue, Color(0xFF1D4ED8)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MockTester',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _darkNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < _slides.length)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _pageController.animateToPage(
                          _slides.length,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 📱 Carousel & Form PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  ..._slides.map((s) => _buildCarouselCard(s)),
                  _buildRegistrationForm(),
                ],
              ),
            ),

            // 📍 Bottom Dynamic Indicator & CTA
            if (_currentPage < _slides.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dynamic Smooth Expanding Dots
                    Row(
                      children: List.generate(
                        _slides.length + 1,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          height: 7,
                          width: _currentPage == index ? 26 : 7,
                          decoration: BoxDecoration(
                            gradient: _currentPage == index
                                ? const LinearGradient(colors: [_primaryBlue, Color(0xFF60A5FA)])
                                : null,
                            color: _currentPage == index ? null : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    // Next Circular Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: _primaryBlue.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Row(
                        children: [
                          Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🎨 High-Standard Feature Carousel Page
  Widget _buildCarouselCard(Map<String, dynamic> slide) {
    final List<Color> gradient = slide['gradient'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Layered Glow Card Icon
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradient.first.withOpacity(0.12),
                ),
              ),
              Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(slide['icon'], size: 48, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Upper Pill Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gradient.first.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gradient.first.withOpacity(0.25)),
            ),
            child: Text(
              slide['badge'],
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: gradient.first,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Heading
          Text(
            slide['title'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _darkNavy,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            slide['desc'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Feature Highlights Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: (slide['highlights'] as List<String>).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 📝 Student Name (Mandatory) & Mobile (Optional) Card
  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school_rounded, color: _primaryBlue, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              "Setup Aspirant Profile 🚀",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkNavy, letterSpacing: -0.4),
            ),
            const SizedBox(height: 6),
            const Text(
              "Yeh naam aapke mock scorecard, batch ranking aur coaching certificates par print hoga.",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Student Name (Mandatory)
                  Row(
                    children: const [
                      Text("Full Name", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _darkNavy)),
                      Text(" *", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Anand Sharma',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: _primaryBlue, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Kripya apna naam daalein!';
                      if (val.trim().length < 2) return 'Kam se kam 2 characters ka naam daalein';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Mobile / Roll Number (Optional)
                  Row(
                    children: const [
                      Text("Mobile / Roll No.", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _darkNavy)),
                      SizedBox(width: 6),
                      Text("(Optional)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'e.g. 9876543210 (Classroom sync ke liye)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _primaryBlue.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _completeOnboarding,
                child: const Text('Start Practicing 🚀', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '🔒 Your data is stored safely on your device.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

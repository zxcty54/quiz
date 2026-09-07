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

  final List<Map<String, String>> _slides = [
    {
      'emoji': '⚡',
      'title': 'Real Exam CBT Simulation',
      'desc': 'BPSC, BSSC aur state competitive exams ke liye timed CBT mock tests aur negative marking analysis.',
    },
    {
      'emoji': '🎯',
      'title': 'AI Wrong Question Vault',
      'desc': 'Galat hue sawalon ka deep AI trap analysis aur 1-click mistake re-drill system.',
    },
    {
      'emoji': '👨‍🏫',
      'title': 'Classroom Batches & Coaching Hub',
      'desc': 'Top teachers ke exclusive batch tests, study handouts aur real-time percentile ranking.',
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
    const primaryBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip button (sirf slides par dikhega)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MockTester',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (_currentPage < _slides.length)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          _slides.length,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Skip', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            // PageView Area
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  // Slide 1, 2, 3 (Carousel)
                  ..._slides.map((slide) => Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Text(slide['emoji']!, style: const TextStyle(fontSize: 56)),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              slide['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide['desc']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )),

                  // Final Slide: User Name & Mobile Input Form
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('👋', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          const Text(
                            "Welcome Aspirant!",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Classroom tests aur mock test scorecard ke liye apni details fill karein.",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 24),

                          // Name Field (Mandatory)
                          const Text(
                            "Student Name *",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'e.g. Rahul Kumar',
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: primaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Kripya apna naam daalein!';
                              }
                              if (val.trim().length < 2) {
                                return 'Naam kam se kam 2 characters ka hona chahiye';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Mobile Field (Optional)
                          Row(
                            children: [
                              const Text(
                                "Mobile / Roll No.",
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "(Optional)",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'e.g. 9876543210 (Optional)',
                              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _completeOnboarding,
                              child: const Text('Start Preparation 🚀', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Navigation Dots & Next Button (slides 1 to 3 ke liye)
            if (_currentPage < _slides.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Carousel Indicators
                    Row(
                      children: List.generate(
                        _slides.length + 1,
                        (index) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          height: 6,
                          width: _currentPage == index ? 22 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? primaryBlue : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),

                    // Next button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Row(
                        children: [
                          Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
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
}

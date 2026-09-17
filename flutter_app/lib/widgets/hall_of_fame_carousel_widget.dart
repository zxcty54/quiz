import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// HELPER EXTENSION: Auto Title Case & Upper Case
// -----------------------------------------------------------------------------
extension StringCasingExtension on String {
  String toTitleCase() {
    if (trim().isEmpty) return '';
    return split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class HallOfFameCarouselWidget extends StatefulWidget {
  final bool isDarkMode;

  const HallOfFameCarouselWidget({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<HallOfFameCarouselWidget> createState() =>
      HallOfFameCarouselWidgetState();
}

class HallOfFameCarouselWidgetState
    extends State<HallOfFameCarouselWidget> {
  List<Map<String, dynamic>> _hallOfFameList = [];
  bool _isLoading = true;

  final PageController _pageController = PageController(
    viewportFraction: 0.86,
  );

  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    fetchHallOfFame();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // FETCH HALL OF FAME
  // ===========================================================================

  Future<void> fetchHallOfFame() async {
    try {
      final res = await Supabase.instance.client
          .from('coaching_selections')
          .select('*, coachings(name)')
          .eq('is_verified', true)
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;

      setState(() {
        _hallOfFameList = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });

      _startAutoScroll();
    } catch (e) {
      debugPrint('[DEBUG] Hall of Fame fetch error: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // AUTO CAROUSEL
  // ===========================================================================

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();

    if (_hallOfFameList.length <= 1) return;

    _autoScrollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!_pageController.hasClients || _hallOfFameList.isEmpty) {
          return;
        }

        _currentPage++;

        if (_currentPage >= _hallOfFameList.length) {
          _currentPage = 0;
        }

        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  // ===========================================================================
  // BUILD (Only Hall of Fame)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _hallOfFameList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(),
        const SizedBox(height: 12),
        _hallOfFameCards(),
      ],
    );
  }

  // ===========================================================================
  // SECTION HEADER
  // ===========================================================================

  Widget _sectionHeader() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hall of Fame',
                style: TextStyle(
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.3,
                ),
              ),
              Text(
                'Real students. Real selections.',
                style: TextStyle(
                  color: widget.isDarkMode
                      ? Colors.white54
                      : const Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                color: Color(0xFF16A34A),
                size: 12,
              ),
              SizedBox(width: 4),
              Text(
                'VERIFIED',
                style: TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CAROUSEL
  // ===========================================================================

  Widget _hallOfFameCards() {
    return SizedBox(
      height: 355,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _hallOfFameList.length,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          _currentPage = index;
        },
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            child: _selectionCard(
              _hallOfFameList[index],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // SINGLE SELECTION CARD
  // ===========================================================================

  Widget _selectionCard(
    Map<String, dynamic> item,
  ) {
    final rawCoaching = item['coachings']?['name']?.toString().trim() ?? '';
    final coachingName =
        rawCoaching.isNotEmpty ? rawCoaching.toTitleCase() : 'Mentored Coaching';

    final rawName = item['student_name']?.toString().trim() ?? '';
    final studentName =
        rawName.isNotEmpty ? rawName.toTitleCase() : 'Candidate';

    final rawPost = item['post_cleared']?.toString().trim() ?? '';
    final post = rawPost.isNotEmpty ? rawPost.toTitleCase() : 'Selected';

    final rawExam = item['target_exam']?.toString().trim() ?? '';
    final exam =
        rawExam.isNotEmpty ? rawExam.toUpperCase() : 'COMPETITIVE EXAM';

    final quote = item['testimonial_text']?.toString().trim() ?? '';

    final imageUrl = item['profile_image_url'] ??
        item['student_image_url'] ??
        item['photo_url'];

    const double avatarRadius = 42;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Background Base Card
        Container(
          margin: const EdgeInsets.only(top: avatarRadius),
          padding: const EdgeInsets.fromLTRB(16, avatarRadius + 12, 16, 14),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? const Color(0xFF172033)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isDarkMode
                  ? Colors.white.withOpacity(.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  widget.isDarkMode ? .25 : .05,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Student Name & Verified Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF16A34A),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 2. Post & Exam Capsule
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF93C5FD),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      exam,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),

              // 3. Clean Journey Text
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: widget.isDarkMode
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFF1F5F9),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      quote.isNotEmpty
                          ? quote
                          : 'I am proud to share my selection journey.',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white70
                            : const Color(0xFF475569),
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 4. Prepared at Coaching Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.white.withOpacity(.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: widget.isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Color(0xFF2563EB),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREPARED AT',
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            coachingName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
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

        // Floating Overlapping Circular Avatar
        Positioned(
          top: 0,
          child: _circularStudentPhoto(
            studentName,
            imageUrl,
            avatarRadius,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CIRCULAR OVERLAPPING PHOTO WITH DUAL GRADIENT RING & SHADOW
  // ===========================================================================

  Widget _circularStudentPhoto(
    String studentName,
    dynamic imageUrl,
    double radius,
  ) {
    final hasImage =
        imageUrl != null && imageUrl.toString().trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF172033)
            : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CircleAvatar(
          radius: radius - 5,
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF24304A)
              : const Color(0xFFE8F1FF),
          child: ClipOval(
            child: hasImage
                ? Image.network(
                    imageUrl.toString(),
                    width: (radius - 5) * 2,
                    height: (radius - 5) * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoFallback(studentName),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _photoLoading();
                    },
                  )
                : _photoFallback(studentName),
          ),
        ),
      ),
    );
  }

  Widget _photoFallback(
    String studentName,
  ) {
    final initial = studentName.trim().isNotEmpty
        ? studentName.trim()[0].toUpperCase()
        : 'A';

    return Container(
      color: widget.isDarkMode
          ? const Color(0xFF24304A)
          : const Color(0xFFE8F1FF),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _photoLoading() {
    return Container(
      color: widget.isDarkMode
          ? const Color(0xFF24304A)
          : const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

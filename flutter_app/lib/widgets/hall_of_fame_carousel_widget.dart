import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'selection_proof_system.dart';

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
        _hallOfFameList =
            List<Map<String, dynamic>>.from(res);
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
        if (!_pageController.hasClients ||
            _hallOfFameList.isEmpty) {
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
  // OPEN CLAIM / SHARE SUCCESS STORY
  // ===========================================================================

  Future<void> _openClaimSelectionModal() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    String targetCoachingId = '';
    String targetCoachingName = 'Coaching Institute';

    if (user != null) {
      try {
        final recentSub = await client
            .from('batch_submissions')
            .select(
              'batch_tests(batches(coaching_id, coachings(id, name)))',
            )
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle();

        if (recentSub != null &&
            recentSub['batch_tests'] != null) {
          final batchTests = recentSub['batch_tests'];

          if (batchTests['batches'] != null) {
            final coaching =
                batchTests['batches']['coachings'];

            if (coaching != null) {
              targetCoachingId =
                  coaching['id'].toString();

              targetCoachingName =
                  coaching['name']?.toString() ??
                      'Coaching Institute';
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[DEBUG] Coaching lookup error: $e',
        );
      }
    }

    if (targetCoachingId.isEmpty) {
      try {
        final coaching = await client
            .from('coachings')
            .select('id, name')
            .limit(1)
            .maybeSingle();

        if (coaching != null) {
          targetCoachingId =
              coaching['id'].toString();

          targetCoachingName =
              coaching['name']?.toString() ??
                  'Coaching Institute';
        }
      } catch (e) {
        debugPrint(
          '[DEBUG] Fallback coaching error: $e',
        );
      }
    }

    if (!mounted) return;

    if (targetCoachingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Filhal koi coaching registered nahi mili.',
          ),
        ),
      );
      return;
    }

    StudentClaimSelectionSheet.show(
      context,
      coachingId: targetCoachingId,
      coachingName: targetCoachingName,
      isDarkMode: widget.isDarkMode,
      onSuccess: fetchHallOfFame,
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _claimBanner(),

        if (!_isLoading &&
            _hallOfFameList.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionHeader(),
          const SizedBox(height: 12),
          _hallOfFameCards(),
        ],
      ],
    );
  }

  // ===========================================================================
  // SHARE SUCCESS STORY BANNER
  // ===========================================================================

  Widget _claimBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? const [
                  Color(0xFF211B4B),
                  Color(0xFF121A31),
                ]
              : const [
                  Color(0xFFF1F5FF),
                  Color(0xFFE8EDFF),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF6366F1),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crack Kiya Koi Exam? 🎓',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Apni success story share karein aur apni coaching ko credit dein.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white70
                        : const Color(0xFF64748B),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openClaimSelectionModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              'Share',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
      height: 350,
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
  // SINGLE SELECTION CARD (CIRCULAR OVERLAP & NO DOUBLE QUOTES)
  // ===========================================================================

  Widget _selectionCard(
    Map<String, dynamic> item,
  ) {
    final coachingName =
        item['coachings']?['name']?.toString().trim().isNotEmpty == true
            ? item['coachings']['name'].toString().trim()
            : 'Mentored Coaching';

    final studentName =
        item['student_name']?.toString().trim().isNotEmpty == true
            ? item['student_name'].toString().trim()
            : 'Candidate';

    final post =
        item['post_cleared']?.toString().trim().isNotEmpty == true
            ? item['post_cleared'].toString().trim()
            : 'Selected';

    final exam =
        item['target_exam']?.toString().trim().isNotEmpty == true
            ? item['target_exam'].toString().trim()
            : 'Competitive Exam';

    final quote =
        item['testimonial_text']?.toString().trim() ?? '';

    final imageUrl =
        item['profile_image_url'] ??
            item['student_image_url'] ??
            item['photo_url'];

    const double avatarRadius = 40;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Background Base Card
        Container(
          margin: const EdgeInsets.only(top: avatarRadius),
          padding: const EdgeInsets.fromLTRB(16, avatarRadius + 10, 16, 14),
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
                        fontSize: 16,
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
              const SizedBox(height: 5),

              // 2. Post & Exam Capsule
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '$post • $exam',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Clean Journey Text (Without quotes)
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
                  borderRadius: BorderRadius.circular(10),
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
  // CIRCULAR OVERLAPPING PHOTO WITH SHADOW & RING
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
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.35 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius - 3.5,
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF24304A)
            : const Color(0xFFE8F1FF),
        child: ClipOval(
          child: hasImage
              ? Image.network(
                  imageUrl.toString(),
                  width: (radius - 3.5) * 2,
                  height: (radius - 3.5) * 2,
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
    );
  }

  // ===========================================================================
  // PHOTO FALLBACK
  // ===========================================================================

  Widget _photoFallback(
    String studentName,
  ) {
    final initial =
        studentName.trim().isNotEmpty
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

  // ===========================================================================
  // PHOTO LOADING
  // ===========================================================================

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

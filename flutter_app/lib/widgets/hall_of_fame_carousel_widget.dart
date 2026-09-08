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

  @override
  void initState() {
    super.initState();
    fetchHallOfFame();
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
    } catch (e) {
      debugPrint(
        '[DEBUG] Hall of Fame fetch error: $e',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // OPEN CLAIM MODAL
  // ===========================================================================

  Future<void> _openClaimSelectionModal() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    String targetCoachingId = '';
    String targetCoachingName = 'Coaching Institute';

    // -------------------------------------------------------------------------
    // FIND USER'S RECENT COACHING
    // -------------------------------------------------------------------------

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
          final batchTests =
              recentSub['batch_tests'];

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

    // -------------------------------------------------------------------------
    // FALLBACK COACHING
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // OPEN CLAIM SHEET
    // -------------------------------------------------------------------------

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
      crossAxisAlignment:
          CrossAxisAlignment.start,
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
  // CLAIM BANNER
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
          color: const Color(0xFF6366F1)
              .withOpacity(.25),
        ),
      ),
      child: Row(
        children: [
          // ICON
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1)
                  .withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF6366F1),
              size: 25,
            ),
          ),

          const SizedBox(width: 12),

          // TEXT
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Crack Kiya Koi Exam? 🎓',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Apna selection share karein aur apni coaching ko credit dein.',
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

          // BUTTON
          ElevatedButton(
            onPressed:
                _openClaimSelectionModal,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 10,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              'Claim',
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
            borderRadius:
                BorderRadius.circular(10),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
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

        // VERIFIED BADGE
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A)
                .withOpacity(.10),
            borderRadius:
                BorderRadius.circular(8),
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
  // HALL OF FAME CARDS
  // ===========================================================================

  Widget _hallOfFameCards() {
    return SizedBox(
      height: 325,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        itemCount: _hallOfFameList.length,
        itemBuilder: (context, index) {
          return _selectionCard(
            _hallOfFameList[index],
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
    final coachingName =
        item['coachings']?['name'] ??
            'Mentored Coaching';

    final studentName =
        item['student_name'] ??
            'Candidate';

    final post =
        item['post_cleared'] ??
            'Officer';

    final exam =
        item['target_exam'] ??
            'Competitive Exam';

    final quote =
        item['testimonial_text'] ??
            '';

    // Optional image support.
    //
    // If your database later contains a field
    // such as profile_image_url, this card will
    // automatically use it.
    final imageUrl =
        item['profile_image_url'] ??
            item['student_image_url'] ??
            item['photo_url'];

    return Container(
      width: 285,
      margin:
          const EdgeInsets.only(right: 13),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF172033)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDarkMode
              ? Colors.white.withOpacity(.07)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              widget.isDarkMode ? .20 : .055,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // TOP PROFILE AREA
          // ===================================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              0,
            ),
            child: Row(
              children: [
                // -------------------------------------------------------------
                // STUDENT IMAGE
                // -------------------------------------------------------------

                _studentAvatar(
                  studentName,
                  imageUrl,
                ),

                const SizedBox(width: 11),

                // -------------------------------------------------------------
                // NAME + POST
                // -------------------------------------------------------------

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              studentName,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color: widget
                                        .isDarkMode
                                    ? Colors.white
                                    : const Color(
                                        0xFF0F172A,
                                      ),
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color:
                                Color(0xFF16A34A),
                            size: 15,
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        post,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        exam,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget
                                  .isDarkMode
                              ? Colors.white54
                              : const Color(
                                  0xFF94A3B8,
                                ),
                          fontSize: 9.5,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ===================================================================
          // SEPARATOR
          // ===================================================================

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Container(
              height: 1,
              color: widget.isDarkMode
                  ? Colors.white
                      .withOpacity(.07)
                  : const Color(0xFFF1F5F9),
            ),
          ),

          // ===================================================================
          // STATEMENT
          // ===================================================================

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                13,
                16,
                8,
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // QUOTE ICON
                    Container(
                      width: 27,
                      height: 27,
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFF2563EB,
                        ).withOpacity(.10),
                        borderRadius:
                            BorderRadius.circular(
                          8,
                        ),
                      ),
                      child: const Icon(
                        Icons.format_quote_rounded,
                        color:
                            Color(0xFF2563EB),
                        size: 17,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // MAIN STATEMENT
                    Expanded(
                      child: Align(
                        alignment:
                            Alignment.topLeft,
                        child: Text(
                          quote.isNotEmpty
                              ? quote
                              : 'I am proud to share my selection journey.',
                          maxLines: 5,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget
                                    .isDarkMode
                                ? Colors.white
                                : const Color(
                                    0xFF334155,
                                  ),
                            fontSize: 11.5,
                            height: 1.45,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===================================================================
          // COACHING FOOTER
          // ===================================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              15,
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white
                        .withOpacity(.05)
                    : const Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    decoration:
                        BoxDecoration(
                      color: const Color(
                        0xFF6366F1,
                      ).withOpacity(.10),
                      borderRadius:
                          BorderRadius.circular(
                        7,
                      ),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color:
                          Color(0xFF6366F1),
                      size: 14,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coaching',
                          style: TextStyle(
                            color: widget
                                    .isDarkMode
                                ? Colors.white38
                                : const Color(
                                    0xFF94A3B8,
                                  ),
                            fontSize: 7.5,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          coachingName.toString(),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget
                                    .isDarkMode
                                ? Colors.white
                                : const Color(
                                    0xFF334155,
                                  ),
                            fontSize: 10.5,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STUDENT AVATAR / IMAGE
  // ===========================================================================

  Widget _studentAvatar(
    String studentName,
    dynamic imageUrl,
  ) {
    final hasImage =
        imageUrl != null &&
            imageUrl.toString().trim().isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF2563EB)
              .withOpacity(.18),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        _avatarFallback(
                  studentName,
                ),
              )
            : _avatarFallback(
                studentName,
              ),
      ),
    );
  }

  Widget _avatarFallback(
    String studentName,
  ) {
    final initial =
        studentName.trim().isNotEmpty
            ? studentName
                .trim()[0]
                .toUpperCase()
            : 'A';

    return Container(
      color: const Color(0xFFE8F1FF),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
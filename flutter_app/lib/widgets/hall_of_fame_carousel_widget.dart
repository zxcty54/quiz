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

  // ===========================================================================
  // PREMIUM PALETTE
  // ===========================================================================

  static const Color blue = Color(0xFF155EEF);
  static const Color blueDark = Color(0xFF0039B7);
  static const Color blueLight = Color(0xFFEAF2FF);

  static const Color gold = Color(0xFFF59E0B);
  static const Color green = Color(0xFF12B76A);

  static const Color lightBg = Color(0xFFF7F9FC);
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF101828);
  static const Color lightMuted = Color(0xFF667085);
  static const Color lightFaint = Color(0xFF98A2B3);
  static const Color lightBorder = Color(0xFFE4E7EC);

  static const Color darkBg = Color(0xFF0B1220);
  static const Color darkCard = Color(0xFF111B2E);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkMuted = Color(0xFF98A2B3);
  static const Color darkBorder = Color(0xFF24324A);

  @override
  void initState() {
    super.initState();
    fetchHallOfFame();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> fetchHallOfFame() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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
  // CLAIM SELECTION
  // ===========================================================================

  Future<void> _openClaimSelectionModal() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    String targetCoachingId = '';
    String targetCoachingName = 'Coaching Institute';

    // -------------------------------------------------------------------------
    // TRY TO FIND USER'S RECENT COACHING
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

          if (batchTests != null &&
              batchTests['batches'] != null) {
            final batches = batchTests['batches'];

            final cData = batches['coachings'];

            if (cData != null) {
              targetCoachingId =
                  cData['id']?.toString() ?? '';

              targetCoachingName =
                  cData['name']?.toString() ??
                      'Coaching Institute';
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[DEBUG] Coaching auto-detect error: $e',
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
              coaching['id']?.toString() ?? '';

          targetCoachingName =
              coaching['name']?.toString() ??
                  'Coaching Institute';
        }
      } catch (e) {
        debugPrint(
          '[DEBUG] Coaching fallback error: $e',
        );
      }
    }

    if (!mounted) return;

    // -------------------------------------------------------------------------
    // NO COACHING FOUND
    // -------------------------------------------------------------------------

    if (targetCoachingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Filhal koi coaching registered nahi mili.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: widget.isDarkMode
              ? darkCard
              : lightText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
    final background =
        widget.isDarkMode ? darkBg : lightBg;

    return Container(
      color: background,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionHeader(),
          const SizedBox(height: 12),
          _claimBanner(),
          const SizedBox(height: 20),
          _hallOfFameContent(),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION HEADER
  // ===========================================================================

  Widget _sectionHeader() {
    final textColor =
        widget.isDarkMode ? darkText : lightText;

    final mutedColor =
        widget.isDarkMode ? darkMuted : lightMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? gold.withOpacity(.12)
                : const Color(0xFFFFF7E6),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: gold,
            size: 21,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Hall of Fame',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Real students. Real selections.',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // VERIFIED PILL
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: green.withOpacity(.10),
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: green.withOpacity(.18),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                color: green,
                size: 13,
              ),
              SizedBox(width: 4),
              Text(
                'VERIFIED',
                style: TextStyle(
                  color: green,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CLAIM BANNER
  // ===========================================================================

  Widget _claimBanner() {
    final cardColor =
        widget.isDarkMode
            ? darkCard
            : lightCard;

    final titleColor =
        widget.isDarkMode
            ? darkText
            : lightText;

    final subtitleColor =
        widget.isDarkMode
            ? darkMuted
            : lightMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDarkMode
              ? darkBorder
              : lightBorder,
        ),
        boxShadow: [
          if (!widget.isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
        ],
      ),
      child: Row(
        children: [
          // ICON
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2585FF),
                  Color(0xFF155EEF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 23,
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
                  'Aapka bhi selection hua?',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Apni achievement share karein aur '
                  'apni coaching ko credit dein.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // CTA
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed:
                  _openClaimSelectionModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(11),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
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
  // CONTENT
  // ===========================================================================

  Widget _hallOfFameContent() {
    if (_isLoading) {
      return _loadingState();
    }

    if (_hallOfFameList.isEmpty) {
      return _emptyState();
    }

    return _cardsCarousel();
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _loadingState() {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 12),
        itemBuilder: (_, __) {
          return Container(
            width: 285,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? darkCard
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: widget.isDarkMode
                    ? darkBorder
                    : lightBorder,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: blue,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _emptyState() {
    final cardColor =
        widget.isDarkMode
            ? darkCard
            : Colors.white;

    final textColor =
        widget.isDarkMode
            ? darkText
            : lightText;

    final mutedColor =
        widget.isDarkMode
            ? darkMuted
            : lightMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDarkMode
              ? darkBorder
              : lightBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: blue.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: blue,
              size: 25,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'Hall of Fame is waiting for you',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Be among the first students to share '
            'their selection.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedColor,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CAROUSEL
  // ===========================================================================

  Widget _cardsCarousel() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          right: 12,
        ),
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
  // SELECTION CARD
  // ===========================================================================

  Widget _selectionCard(
    Map<String, dynamic> item,
  ) {
    final cardColor =
        widget.isDarkMode
            ? darkCard
            : Colors.white;

    final textColor =
        widget.isDarkMode
            ? darkText
            : lightText;

    final mutedColor =
        widget.isDarkMode
            ? darkMuted
            : lightMuted;

    final coachingName =
        item['coachings']?['name']
                ?.toString() ??
            'Mentored Coaching';

    final studentName =
        item['student_name']?.toString() ??
            'Candidate';

    final post =
        item['post_cleared']?.toString() ??
            'Selected';

    final exam =
        item['target_exam']?.toString() ??
            'Competitive Exam';

    final quote =
        item['testimonial_text']
                ?.toString() ??
            '';

    final firstLetter =
        studentName.isNotEmpty
            ? studentName[0].toUpperCase()
            : 'A';

    return Container(
      width: 292,
      margin: const EdgeInsets.only(
        right: 12,
        bottom: 5,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDarkMode
              ? darkBorder
              : lightBorder,
        ),
        boxShadow: [
          if (!widget.isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // STUDENT
          // -------------------------------------------------------------------

          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF2585FF),
                      Color(0xFF155EEF),
                    ],
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                alignment:
                    Alignment.center,
                child: Text(
                  firstLetter,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 10),

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
                                TextOverflow
                                    .ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        const Icon(
                          Icons.verified_rounded,
                          color: green,
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Verified selection',
                      style: TextStyle(
                        color: green,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // -------------------------------------------------------------------
          // SELECTION
          // -------------------------------------------------------------------

          Text(
            'SELECTED',
            style: TextStyle(
              color: mutedColor,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            post,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -.3,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            exam,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: blue,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 9),

          // -------------------------------------------------------------------
          // TESTIMONIAL
          // -------------------------------------------------------------------

          if (quote.isNotEmpty)
            Expanded(
              child: Text(
                '“$quote”',
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 10,
                  height: 1.35,
                  fontStyle:
                      FontStyle.italic,
                ),
              ),
            )
          else
            const Spacer(),

          const SizedBox(height: 7),

          // -------------------------------------------------------------------
          // COACHING
          // -------------------------------------------------------------------

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF0B1220)
                  : const Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  color: mutedColor,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    coachingName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w700,
                    ),
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
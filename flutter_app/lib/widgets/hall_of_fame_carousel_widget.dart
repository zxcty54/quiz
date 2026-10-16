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

  Timer? _autoScrollTimer;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchHallOfFame();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
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

      _startAutoCycle();
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

  void _startAutoCycle() {
    _autoScrollTimer?.cancel();

    if (_hallOfFameList.length <= 1) return;

    _autoScrollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || _hallOfFameList.isEmpty) return;

        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _hallOfFameList.length;
        });
      },
    );
  }

  // Rail me kisi topper ko tap karne par wahi upar hero me aa jata hai —
  // uske naam ke saath usi ki apni lines (testimonial) dikhti hain.
  void _selectStudent(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _startAutoCycle(); // tap ke baad timer phir se shuru, turant na badle
  }

  // ===========================================================================
  // BUILD (Only Hall of Fame) — Option A: Star Selection + Rail
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _hallOfFameList.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedIndex >= _hallOfFameList.length) _selectedIndex = 0;
    final featured = _hallOfFameList[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(),
        const SizedBox(height: 12),
        _featuredCard(featured),
        if (_hallOfFameList.length > 1) ...[
          const SizedBox(height: 16),
          _railLabel(),
          const SizedBox(height: 9),
          _toppersRail(),
          const SizedBox(height: 9),
          _dots(),
        ],
      ],
    );
  }

  // ===========================================================================
  // DATA HELPERS (har student ki jaankari usi ke record se)
  // ===========================================================================

  String _studentName(Map<String, dynamic> item) {
    final raw = item['student_name']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw.toTitleCase() : 'Candidate';
  }

  String _studentPost(Map<String, dynamic> item) {
    final raw = item['post_cleared']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw.toTitleCase() : 'Selected';
  }

  String _studentExam(Map<String, dynamic> item) {
    final raw = item['target_exam']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw.toUpperCase() : 'COMPETITIVE EXAM';
  }

  String _studentCoaching(Map<String, dynamic> item) {
    final raw = item['coachings']?['name']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw.toTitleCase() : 'Mentored Coaching';
  }

  String _studentQuote(Map<String, dynamic> item) {
    final raw = item['testimonial_text']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw : 'I am proud to share my selection journey.';
  }

  dynamic _studentImage(Map<String, dynamic> item) {
    return item['profile_image_url'] ??
        item['student_image_url'] ??
        item['photo_url'];
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
  // FEATURED CARD (bada royal-blue hero — selected student, uski apni lines)
  // ===========================================================================

  Widget _featuredCard(Map<String, dynamic> item) {
    final studentName = _studentName(item);
    final isLatest = _selectedIndex == 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -30,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -55,
              left: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chip — sabse naya ya topper spotlight
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: Color(0xFFFCD34D),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isLatest ? 'SABSE NAYA SELECTION' : 'TOPPER SPOTLIGHT',
                          style: const TextStyle(
                            color: Color(0xFFFCD34D),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),

                  // Photo + naam + post
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _circularStudentPhoto(
                        studentName,
                        _studentImage(item),
                        40,
                        ringColors: const [
                          Color(0xFFF59E0B),
                          Color(0xFFFBBF24),
                        ],
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    studentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF4ADE80),
                                  size: 17,
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    _studentPost(item).toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF451A03),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Text(
                                  _studentExam(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFBFDBFE),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),

                  // Student ki apni lines — usi ke naam ke saath upar dikhti hain
                  Text(
                    '"${_studentQuote(item)}"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFDBEAFE),
                      fontSize: 12,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Footer — coaching + total selections
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PREPARED AT',
                                style: TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _studentCoaching(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_hallOfFameList.length}',
                              style: const TextStyle(
                                color: Color(0xFFFCD34D),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'SELECTIONS',
                              style: TextStyle(
                                color: Color(0xFFBFDBFE),
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
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
    );
  }

  // ===========================================================================
  // RAIL (baaki toppers — tap karne par upar hero me)
  // ===========================================================================

  Widget _railLabel() {
    return Row(
      children: [
        Text(
          'Aur Toppers',
          style: TextStyle(
            color: widget.isDarkMode
                ? Colors.white
                : const Color(0xFF0F172A),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          'Tap karo — uski lines upar aayengi',
          style: TextStyle(
            color: widget.isDarkMode
                ? Colors.white54
                : const Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _toppersRail() {
    final others = <int>[
      for (var i = 0; i < _hallOfFameList.length; i++)
        if (i != _selectedIndex) i,
    ];

    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: others.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, pos) {
          final index = others[pos];
          return _miniCard(_hallOfFameList[index], index);
        },
      ),
    );
  }

  Widget _miniCard(Map<String, dynamic> item, int index) {
    final isDark = widget.isDarkMode;

    return GestureDetector(
      onTap: () => _selectStudent(index),
      child: Container(
        width: 128,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _miniPhoto(item),
            const SizedBox(height: 8),
            Text(
              _studentName(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _studentPost(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(isDark ? 0.22 : 0.08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _studentExam(item),
                  maxLines: 1,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1E40AF),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _studentCoaching(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPhoto(Map<String, dynamic> item) {
    final imageUrl = _studentImage(item);
    final hasImage =
        imageUrl != null && imageUrl.toString().trim().isNotEmpty;

    return CircleAvatar(
      radius: 26,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF24304A)
          : const Color(0xFFE8F1FF),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl.toString(),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _photoFallback(_studentName(item), fontSize: 19),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _photoLoading();
                },
              )
            : _photoFallback(_studentName(item), fontSize: 19),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _hallOfFameList.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == _selectedIndex ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _selectedIndex
                  ? const Color(0xFFF59E0B)
                  : (widget.isDarkMode
                      ? Colors.white24
                      : const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(99),
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
    double radius, {
    List<Color> ringColors = const [Color(0xFF2563EB), Color(0xFF10B981)],
  }) {
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: ringColors,
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
    String studentName, {
    double fontSize = 28,
  }) {
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
        style: TextStyle(
          color: const Color(0xFF2563EB),
          fontSize: fontSize,
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

import 'dart:async';
import 'package:flutter/material.dart';

import '../screens/quiz_screen.dart';

/// Live promo banners — naye exam, naye mock, announcement ke liye.
///
/// Ye banners code me NAHI likhe jate. App khulte hi jo live
/// `app_config.json` (content_base repo) aata hai, uske `promo_banners`
/// hisse se bante hain. Naya banner dikhana ho to bas wahan ek entry
/// jod do — app rebuild karne ki zaroorat nahi, agle khulne par banner
/// apne aap aa jayega.
///
/// Ek banner aisa dikhta hai:
/// {
///   "show": true,
///   "type": "exam",              // exam | mock | announcement
///   "badge": "NEW EXAM",
///   "title": "BPSC 71th Notification Out",
///   "subtitle": "Form bharna shuru — last date 30 Oct",
///   "button_text": "Details",
///   "highlight": "Last date 30 Oct",
///   "visual_text": "BPSC",
///   "image_url": "https://...",  // ho to poora banner background
///   "url": "https://...",        // website khulega, YA —
///   "mock_json": "bpsc/.../set1.json",  // seedha mock khulega
///   "color1": "#1D4ED8",
///   "color2": "#7C3AED",
///   "priority": 10               // zyada = pehle
/// }
class PromoBannerCarousel extends StatefulWidget {
  final List<dynamic> banners;
  final bool isDarkMode;
  final Function(String url, String title) onTapUrl;

  const PromoBannerCarousel({
    super.key,
    required this.banners,
    required this.isDarkMode,
    required this.onTapUrl,
  });

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final AnimationController _shineCtrl;
  Timer? _autoTimer;
  int _index = 0;

  List<Map<String, dynamic>> get _visible {
    final now = DateTime.now();
    final list = <Map<String, dynamic>>[];

    for (final raw in widget.banners) {
      if (raw is! Map) continue;
      final b = Map<String, dynamic>.from(raw);
      if (b['show'] == false) continue;

      // Samay seema (optional): start_at/end_at ISO tareekh ho to
      // banner sirf usi beech dikhega — exam ki last date nikal
      // jaane par banner khud gayab.
      final start = DateTime.tryParse((b['start_at'] ?? '').toString());
      final end = DateTime.tryParse((b['end_at'] ?? '').toString());
      if (start != null && now.isBefore(start)) continue;
      if (end != null && now.isAfter(end)) continue;

      list.add(b);
    }

    int prio(Map<String, dynamic> b) => (b['priority'] as num?)?.toInt() ?? 0;
    list.sort((a, b) => prio(b).compareTo(prio(a)));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.94);
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _visible.length < 2 || !_pageCtrl.hasClients) return;
      final next = (_index + 1) % _visible.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _shineCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Color _color(dynamic hex, Color fallback) {
    try {
      final h = (hex ?? '').toString().replaceAll('#', '').trim();
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    } catch (_) {}
    return fallback;
  }

  IconData _icon(String type) {
    switch (type) {
      case 'exam':
        return Icons.school_rounded;
      case 'mock':
        return Icons.quiz_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'exam':
        return 'EXAM UPDATE';
      case 'mock':
        return 'MOCK TEST';
      default:
        return 'ANNOUNCEMENT';
    }
  }

  List<String> _chips(String type) {
    switch (type) {
      case 'exam':
        return const ['NOTIFICATION', 'CHECK NOW'];
      case 'mock':
        return const ['FULL TEST', 'CBT MODE'];
      default:
        return const ['LATEST UPDATE', 'TAP TO OPEN'];
    }
  }

  String _visualText(Map<String, dynamic> b, String type) {
    final configured = (b['visual_text'] ?? '').toString().trim();
    if (configured.isNotEmpty) return configured.toUpperCase();

    final title = (b['title'] ?? '').toString().trim();
    final words = title
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .where((w) => w.length >= 3)
        .toList();
    if (words.isNotEmpty) {
      final word = words.first.toUpperCase();
      return word.length > 7 ? word.substring(0, 7) : word;
    }
    return _typeLabel(type).split(' ').first;
  }

  void _open(Map<String, dynamic> b) {
    final mockJson = (b['mock_json'] ?? '').toString().trim();
    final url = (b['url'] ?? '').toString().trim();
    final title = (b['title'] ?? 'Mock Test').toString();

    if (mockJson.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(title: title, jsonPath: mockJson),
        ),
      );
    } else if (url.isNotEmpty) {
      widget.onTapUrl(url, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = _visible;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          SizedBox(
            height: 188,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _banner(banners[i]),
            ),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFF59E0B)
                        : (widget.isDarkMode
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _banner(Map<String, dynamic> b) {
    final type = (b['type'] ?? 'announcement').toString().toLowerCase();
    final badge = (b['badge'] ?? '').toString().trim();
    final title = (b['title'] ?? '').toString();
    final subtitle = (b['subtitle'] ?? '').toString();
    final buttonText = (b['button_text'] ?? '').toString().trim();
    final highlight = (b['highlight'] ?? '').toString().trim();
    final imageUrl = (b['image_url'] ?? '').toString().trim();
    final chips = _chips(type);

    final c1 = _color(b['color1'], const Color(0xFF1D4ED8));
    final c2 = _color(b['color2'], const Color(0xFFEC4899));

    return LayoutBuilder(
      builder: (context, constraints) {
        final showVisual = imageUrl.isEmpty && constraints.maxWidth > 330;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c1, c2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: c1.withValues(alpha: 0.38),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: c2.withValues(alpha: 0.20),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _open(b),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty) ...[
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              c1.withValues(alpha: 0.94),
                              c1.withValues(alpha: 0.62),
                              c2.withValues(alpha: 0.18),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ],
                    Positioned.fill(
                      child: CustomPaint(painter: _PromoPatternPainter()),
                    ),
                    // Halki si chamak banner ke upar se guzregi — nazar
                    // khud wahan jayegi, bina chipku lage.
                    AnimatedBuilder(
                      animation: _shineCtrl,
                      builder: (context, _) {
                        final left = -110 +
                            _shineCtrl.value * (constraints.maxWidth + 220);
                        return Positioned(
                          left: left,
                          top: -35,
                          bottom: -35,
                          width: 72,
                          child: Transform.rotate(
                            angle: -0.38,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 14, 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (badge.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC727),
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.18),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.bolt_rounded,
                                          size: 12,
                                          color: Color(0xFF111827),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          badge.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF111827),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 9),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.45,
                                    height: 1.08,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x66000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.92),
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    if (buttonText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              buttonText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: c1,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Container(
                                              width: 17,
                                              height: 17,
                                              decoration: BoxDecoration(
                                                color: c1,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (highlight.isNotEmpty) ...[
                                      if (buttonText.isNotEmpty)
                                        const SizedBox(width: 8),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444)
                                                .withValues(alpha: 0.92),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.timer_rounded,
                                                size: 11,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  highlight,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else if (buttonText.isNotEmpty &&
                                        chips.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          chips.join('  •  '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.82),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (showVisual) ...[
                            const SizedBox(width: 12),
                            _visualCard(b, type, c1),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _visualCard(Map<String, dynamic> b, String type, Color accent) {
    final visualText = _visualText(b, type);
    final chips = _chips(type);

    return SizedBox(
      width: 104,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.075,
            child: Container(
              width: 100,
              height: 142,
              padding: const EdgeInsets.fromLTRB(9, 13, 9, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.26),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon(type), color: accent, size: 27),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    visualText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Color(0x55000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _typeLabel(type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      chips.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 0,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 10, color: Color(0xFFFFC727)),
                    SizedBox(width: 3),
                    Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.52 + i * 0.16);
      canvas.drawLine(
        Offset(x, size.height + 18),
        Offset(x + 58, -18),
        linePaint,
      );
    }

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.10),
      34,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.10),
      22,
      ringPaint,
    );

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 6; col++) {
        canvas.drawCircle(
          Offset(
            size.width * 0.60 + col * 11,
            size.height * 0.78 + row * 10,
          ),
          1.35,
          dotPaint,
        );
      }
    }

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.18),
      42,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

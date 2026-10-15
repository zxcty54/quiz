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

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _pageCtrl = PageController();
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
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _visible.length < 2 || !_pageCtrl.hasClients) return;
      final next = (_index + 1) % _visible.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
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
            height: 148,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _banner(banners[i]),
            ),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF2563EB)
                        : (widget.isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(4),
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
    final type = (b['type'] ?? 'announcement').toString();
    final badge = (b['badge'] ?? '').toString().trim();
    final title = (b['title'] ?? '').toString();
    final subtitle = (b['subtitle'] ?? '').toString();
    final buttonText = (b['button_text'] ?? '').toString().trim();
    final imageUrl = (b['image_url'] ?? '').toString().trim();

    final c1 = _color(b['color1'], const Color(0xFF1D4ED8));
    final c2 = _color(b['color2'], const Color(0xFF7C3AED));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(b),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(
                  _icon(type),
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                badge.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          const SizedBox(height: 9),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (buttonText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    buttonText,
                                    style: TextStyle(
                                      color: c1,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 13, color: c1),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          imageUrl,
                          width: 84,
                          height: 108,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BiharEventsCarouselWidget extends StatefulWidget {
  final bool isDarkMode;
  final List<dynamic>? initialEvents;

  const BiharEventsCarouselWidget({
    super.key,
    required this.isDarkMode,
    this.initialEvents,
  });

  @override
  State<BiharEventsCarouselWidget> createState() =>
      _BiharEventsCarouselWidgetState();
}

class _BiharEventsCarouselWidgetState extends State<BiharEventsCarouselWidget>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String _jsonUrl =
      'https://raw.githubusercontent.com/zxcty54/content_base/refs/heads/main/biharevents.json';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadEvents();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    List<dynamic> rawList = [];

    if (widget.initialEvents != null && widget.initialEvents!.isNotEmpty) {
      rawList = widget.initialEvents!;
    } else {
      try {
        final res = await http
            .get(Uri.parse(_jsonUrl))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          String body = utf8.decode(res.bodyBytes).trim();
          if (body.startsWith('\uFEFF')) body = body.substring(1).trim();
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['events'] is List) {
            rawList = decoded['events'];
          } else if (decoded is List) {
            rawList = decoded;
          }
        }
      } catch (e) {
        debugPrint("Error fetching events json: $e");
      }
    }

    if (mounted) {
      setState(() {
        _filteredEvents = _filterCurrentMonthOnly(rawList);
        _isLoading = false;
      });
    }
  }

  // 🎯 Filter: Only LIVE & Current Month Upcoming
  List<Map<String, dynamic>> _filterCurrentMonthOnly(List<dynamic> rawList) {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final currentYear = now.year;
    final currentMonth = now.month;

    List<Map<String, dynamic>> result = [];

    for (var item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final startStr = map['start_iso']?.toString() ?? '';
      final endStr = map['end_iso']?.toString() ?? startStr;

      if (startStr.isEmpty || endStr.isEmpty) continue;

      final startDate = DateTime.tryParse(startStr);
      final endDate = DateTime.tryParse(endStr);

      if (startDate == null || endDate == null) continue;

      // Past events drop
      if (todayStr.compareTo(endStr) > 0) continue;

      final isLive = todayStr.compareTo(startStr) >= 0 && todayStr.compareTo(endStr) <= 0;

      if (isLive) {
        map['ui_status'] = 'LIVE NOW';
        map['is_live'] = true;
        result.add(map);
      } else {
        final isUpcomingThisMonth = startDate.year == currentYear &&
            startDate.month == currentMonth &&
            todayStr.compareTo(startStr) < 0;

        if (isUpcomingThisMonth) {
          map['ui_status'] = 'UPCOMING';
          map['is_live'] = false;
          result.add(map);
        }
      }
    }

    result.sort((a, b) {
      if (a['is_live'] == true && b['is_live'] == false) return -1;
      if (a['is_live'] == false && b['is_live'] == true) return 1;
      return (a['start_iso'] ?? '').compareTo(b['start_iso'] ?? '');
    });

    return result;
  }

  // Month & Day extractor for ticket notch
  Map<String, String> _extractTicketDate(Map<String, dynamic> ev) {
    final dateRange = ev['date_range']?.toString() ?? '';
    final startIso = ev['start_iso']?.toString() ?? '';

    String month = "EVENT";
    String day = "DATE";

    if (dateRange.isNotEmpty) {
      final parts = dateRange.split(' ');
      if (parts.length >= 2) {
        day = parts[0];
        month = parts[1].replaceAll(',', '');
      }
      if (dateRange.contains('-')) {
        final dashParts = dateRange.split('-');
        final firstPart = dashParts[0].trim().split(' ');
        if (firstPart.length >= 2) {
          day = firstPart[0];
          month = firstPart[1];
        }
      }
    } else if (startIso.length >= 10) {
      final dt = DateTime.tryParse(startIso);
      if (dt != null) {
        const mNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        month = mNames[dt.month - 1];
        day = "${dt.day}";
      }
    }

    return {"month": month.toUpperCase(), "day": day};
  }

  void _handleCardTap(BuildContext context, Map<String, dynamic> event) {
    final bool isLive = event['is_live'] == true;

    if (!isLive) {
      final tDate = _extractTicketDate(event);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFF1E293B),
          content: Row(
            children: [
              const Icon(Icons.lock_clock_rounded,
                  color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yeh notes ${tDate["day"]} ${tDate["month"]} ko event LIVE hone par open honge!',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _openNotesSheet(context, event);
  }

  void _openNotesSheet(BuildContext context, Map<String, dynamic> event) {
    final isDark = widget.isDarkMode;
    final edu = event['educational_content'] as Map<String, dynamic>? ?? {};
    final history = edu['history'] as Map<String, dynamic>? ?? {};
    final geo = edu['geography_and_circuit'] as Map<String, dynamic>? ?? {};
    final culture = edu['culture_and_tradition'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1917) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB45309).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '● LIVE HERITAGE CAPSULE',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  event['date_range'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event['title'] ?? '',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${event['district'] ?? ''} • ${event['administrative_division'] ?? 'Bihar'} Division',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 6,
              children: ((edu['target_exams'] as List?) ?? []).map((exam) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF292524) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    exam.toString(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.amber.shade300 : const Color(0xFF92400E),
                    ),
                  ),
                );
              }).toList(),
            ),
            Divider(
              height: 28,
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),

            _buildSectionHeader(Icons.history_edu_rounded, 'History & Dynasties'),
            const SizedBox(height: 8),
            _buildInfoCard([
              'Dynasties: ${(history['dynasties'] as List?)?.join(', ') ?? 'N/A'}',
              'Key Figures: ${(history['prominent_personalities'] as List?)?.join(', ') ?? 'N/A'}',
              'Historical Note: ${history['historical_narrative'] ?? 'N/A'}',
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader(Icons.map_rounded, 'Geography & Circuit'),
            const SizedBox(height: 8),
            _buildInfoCard([
              'River / Basin: ${geo['region'] ?? 'N/A'}',
              'Tourism Circuit: ${geo['tourism_circuit'] ?? 'N/A'}',
              'Connectivity: ${geo['connectivity'] ?? 'N/A'}',
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader(Icons.festival_rounded, 'Culture, Folklore & Prasad'),
            const SizedBox(height: 8),
            _buildInfoCard([
              'Local Folklore: ${culture['local_folklore'] ?? 'N/A'}',
              'Rituals: ${culture['rituals'] ?? 'N/A'}',
              'Traditional Prasad: ${culture['special_offering'] ?? 'N/A'}',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB45309)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<String> items) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF292524) : const Color(0xFFFDF8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF3E8E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF44403C),
            ),
          ),
        )).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _filteredEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🚩 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'Events & Cultural Affairs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'EXAM GK TRACKER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Heritage Cards
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filteredEvents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final ev = _filteredEvents[index];
              final bool isLive = ev['is_live'] == true;
              final ticketDate = _extractTicketDate(ev);

              final edu = ev['educational_content'] as Map<String, dynamic>? ?? {};
              final history = edu['history'] as Map<String, dynamic>? ?? {};
              final geo = edu['geography_and_circuit'] as Map<String, dynamic>? ?? {};

              // Exam hooks
              final dynastyList = (history['dynasties'] as List?) ?? [];
              final firstDynasty = dynastyList.isNotEmpty ? dynastyList.first.toString().split('(').first.trim() : null;
              final region = geo['region']?.toString();

              Widget cardBody(double pulseAlpha) {
                return Container(
                  width: 295,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isLive
                          ? const Color(0xFFB45309).withValues(alpha: pulseAlpha)
                          : (isDark ? Colors.white10 : const Color(0xFFE7E5E4)),
                      width: isLive ? 1.6 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isLive
                            ? const Color(0xFFB45309).withValues(alpha: pulseAlpha * 0.25)
                            : Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: isLive ? 14 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle Cultural Temple Arch Motif
                      Positioned(
                        right: -15,
                        top: -15,
                        child: Icon(
                          Icons.account_balance_rounded,
                          size: 110,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : const Color(0xFFB45309).withValues(alpha: 0.03),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🎟️ 1. Left Heritage Ticket Notch
                            Container(
                              width: 58,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isLive
                                    ? const Color(0xFFB45309)
                                    : (isDark ? const Color(0xFF292524) : const Color(0xFFF5F5F4)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLive
                                      ? const Color(0xFFB45309)
                                      : (isDark ? Colors.white12 : const Color(0xFFE7E5E4)),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    ticketDate['month']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isLive ? Colors.white70 : (isDark ? Colors.white60 : const Color(0xFF78716C)),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ticketDate['day']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isLive ? Colors.white : (isDark ? Colors.white : const Color(0xFF1C1917)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLive ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isLive ? 'LIVE' : 'UPCOMING',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        color: isLive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF57534E)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 📜 2. Right Info & Exam Hook Area
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Location & District
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.place_rounded,
                                        size: 13,
                                        color: isDark ? Colors.amber.shade400 : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          '${ev['district'] ?? 'Bihar'} • ${ev['administrative_division'] ?? ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Event Title
                                  Text(
                                    ev['title'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF1C1917),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const Spacer(),

                                  // 🏛️ Exam Micro-Tags
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      if (firstDynasty != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF292524) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '🏛️ $firstDynasty',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      if (region != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1C2826) : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '🌊 ${region.split('(').first.trim()}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),

                                  // Action Footer Strip
                                  Row(
                                    children: isLive
                                        ? [
                                            const Text(
                                              'Unlock Exam Notes',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF16A34A),
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(Icons.arrow_forward_rounded,
                                                size: 13, color: Color(0xFF16A34A)),
                                          ]
                                        : [
                                            Icon(Icons.lock_rounded,
                                                size: 12,
                                                color: isDark ? Colors.white38 : const Color(0xFFA8A29E)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Available ${ticketDate["day"]} ${ticketDate["month"]}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white54 : const Color(0xFF78716C),
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
                );
              }

              return InkWell(
                onTap: () => _handleCardTap(context, ev),
                borderRadius: BorderRadius.circular(18),
                child: isLive
                    ? AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, _) => cardBody(_pulseAnimation.value),
                      )
                    : cardBody(1.0),
              );
            },
          ),
        ),
      ],
    );
  }
}

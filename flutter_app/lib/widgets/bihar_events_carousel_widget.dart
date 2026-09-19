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

    // 🔴 Subtle Pulse Animation for LIVE cards
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
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

  // 🎯 STRICT FILTER: Only LIVE & Current Month's Upcoming
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

      // 1. Past events drop
      if (todayStr.compareTo(endStr) > 0) {
        continue;
      }

      final isLive = todayStr.compareTo(startStr) >= 0 && todayStr.compareTo(endStr) <= 0;

      if (isLive) {
        map['ui_status'] = 'LIVE NOW';
        map['is_live'] = true;
        result.add(map);
      } else {
        // 2. Upcoming strictly in current month & year
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

    // Live pehle, fir date-wise sorted
    result.sort((a, b) {
      if (a['is_live'] == true && b['is_live'] == false) return -1;
      if (a['is_live'] == false && b['is_live'] == true) return 1;
      return (a['start_iso'] ?? '').compareTo(b['start_iso'] ?? '');
    });

    return result;
  }

  String _getStartDayMonth(String? dateRange, String? startIso) {
    if (dateRange != null && dateRange.contains('-')) {
      return dateRange.split('-').first.trim();
    }
    if (startIso != null && startIso.length >= 10) {
      final dt = DateTime.tryParse(startIso);
      if (dt != null) {
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return "${dt.day} ${months[dt.month - 1]}";
      }
    }
    return dateRange ?? '';
  }

  void _handleCardTap(BuildContext context, Map<String, dynamic> event) {
    final bool isLive = event['is_live'] == true;

    if (!isLive) {
      final availableDate = _getStartDayMonth(event['date_range'], event['start_iso']);
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
                  color: Colors.amberAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yeh notes $availableDate ko event LIVE hone par open honge!',
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
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '● LIVE EVENT EXAM NOTES',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Text(
                    event['date_range'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                      fontWeight: FontWeight.w800,
                    ),
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
              _getLocationSubtitle(event),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    exam.toString(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
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

            _buildSectionHeader(Icons.map_rounded, 'Geography & Circuits'),
            const SizedBox(height: 8),
            _buildInfoCard([
              'River / Basin: ${geo['region'] ?? 'N/A'}',
              'Tourism Circuit: ${geo['tourism_circuit'] ?? 'N/A'}',
              'Connectivity: ${geo['connectivity'] ?? 'N/A'}',
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader(Icons.festival_rounded, 'Culture, Folklore & Offerings'),
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
        Icon(icon, size: 18, color: const Color(0xFFEA580C)),
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
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
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
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        )).toList(),
      ),
    );
  }

  String _getLocationSubtitle(Map<String, dynamic> ev) {
    if (ev['district'] != null && ev['district'].toString().trim().isNotEmpty) {
      final div = ev['administrative_division'] != null
          ? ' • ${ev['administrative_division']}'
          : '';
      return '${ev['district']}$div';
    }
    if (ev['country'] != null && ev['country'].toString().trim().isNotEmpty) {
      return '${ev['country']} • Global Event';
    }
    return 'State & Cultural Affairs';
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🌐 ', style: TextStyle(fontSize: 16)),
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
                  color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'EXAM GK TRACKER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filteredEvents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final ev = _filteredEvents[index];
              final bool isLive = ev['is_live'] == true;
              final availableDate = _getStartDayMonth(ev['date_range'], ev['start_iso']);

              Widget cardContent(double pulseAlpha) {
                return Container(
                  width: 268,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isLive
                          ? const Color(0xFFDC2626).withValues(alpha: pulseAlpha)
                          : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      width: isLive ? 1.8 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isLive
                            ? const Color(0xFFDC2626).withValues(alpha: pulseAlpha * 0.25)
                            : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: isLive ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Status Tag & Prominent Date Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLive ? '● LIVE NOW' : 'UPCOMING',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),

                          // 📅 Prominent Date Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 4.5),
                                Text(
                                  ev['date_range'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Title
                      Text(
                        ev['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Location / Region
                      Text(
                        _getLocationSubtitle(ev),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),

                      // Action row: Live vs Unlock on Date
                      Row(
                        children: isLive
                            ? const [
                                Text(
                                  'Unlock Exam Notes',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 13, color: Color(0xFF16A34A)),
                              ]
                            : [
                                Icon(Icons.lock_clock_rounded,
                                    size: 13,
                                    color: isDark ? Colors.amber.shade400 : const Color(0xFFD97706)),
                                const SizedBox(width: 4.5),
                                Text(
                                  'Available on $availableDate',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                      ),
                    ],
                  ),
                );
              }

              // Apply pulse animation to LIVE card
              return InkWell(
                onTap: () => _handleCardTap(context, ev),
                borderRadius: BorderRadius.circular(18),
                child: isLive
                    ? AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, _) => cardContent(_pulseAnimation.value),
                      )
                    : cardContent(1.0),
              );
            },
          ),
        ),
      ],
    );
  }
}

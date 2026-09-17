import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LatestJobsWidget extends StatefulWidget {
  final bool isDarkMode;

  const LatestJobsWidget({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<LatestJobsWidget> createState() => LatestJobsWidgetState();
}

class LatestJobsWidgetState extends State<LatestJobsWidget> {
  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color navy = Color(0xFF0F172A);
  static const Color green = Color(0xFF059669);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFDC2626);
  static const Color purple = Color(0xFF7C3AED);

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _allJobs = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

  String _selectedCategory = 'all';

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    fetchLatestJobs();
  }

  // ---------------------------------------------------------------------------
  // LIVE JSON FETCH
  // ---------------------------------------------------------------------------

  Future<void> fetchLatestJobs({bool refresh = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _isRefreshing = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final List<String> endpoints = [
      'https://raw.githubusercontent.com/zxcty54/content_base/main/sarkarijob.json?t=$timestamp',
      'https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/sarkarijob.json?t=$timestamp',
      'https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/sarkarijob.json?t=$timestamp',
      'https://raw.githack.com/zxcty54/content_base/main/sarkarijob.json?t=$timestamp',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(
              Uri.parse(endpoint),
              headers: const {
                'Accept': 'application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) {
          continue;
        }

        String body = utf8.decode(response.bodyBytes).trim();

        // Remove UTF-8 BOM.
        if (body.startsWith('\uFEFF')) {
          body = body.substring(1).trim();
        }

        // Remove accidental Markdown code fences.
        body = body
            .replaceFirst(
              RegExp(r'^```json\s*', caseSensitive: false),
              '',
            )
            .replaceFirst(
              RegExp(r'^```\s*'),
              '',
            )
            .replaceFirst(
              RegExp(r'\s*```$'),
              '',
            )
            .trim();

        // Avoid trying to decode HTML error pages.
        if (body.startsWith('<')) {
          continue;
        }

        final decoded = jsonDecode(body);

        List<dynamic> rawJobs;

        if (decoded is Map && decoded['latest_jobs'] is List) {
          rawJobs = decoded['latest_jobs'] as List;
        } else if (decoded is List) {
          rawJobs = decoded;
        } else {
          rawJobs = [];
        }

        final parsedJobs = rawJobs
            .whereType<Map>()
            .map(
              (job) => Map<String, dynamic>.from(job),
            )
            .toList();

        if (!mounted) return;

        setState(() {
          _allJobs = parsedJobs;
          _isLoading = false;
          _isRefreshing = false;
        });

        return;
      } catch (_) {
        // Try the next mirror.
        continue;
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredJobs {
    if (_selectedCategory == 'all') {
      return _allJobs;
    }

    return _allJobs.where((job) {
      final bool isBihar = _isBiharJob(job);

      if (_selectedCategory == 'bihar') {
        return isBihar;
      }

      if (_selectedCategory == 'central') {
        return !isBihar;
      }

      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // BIHAR DETECTION
  // ---------------------------------------------------------------------------

  bool _isBiharJob(Map<String, dynamic> job) {
    final String jobType =
        (job['job_type'] ?? '').toString().toLowerCase();

    final String title =
        (job['title'] ?? '').toString().toLowerCase();

    final String organization =
        (job['organization'] ?? '').toString().toLowerCase();

    final String state =
        (job['state'] ?? '').toString().toLowerCase();

    final String location =
        (job['location'] ?? '').toString().toLowerCase();

    final combined = [
      jobType,
      title,
      organization,
      state,
      location,
    ].join(' ');

    return combined.contains('bihar') ||
        combined.contains('patna') ||
        combined.contains('bpsc') ||
        combined.contains('bssc') ||
        combined.contains('bpssc') ||
        combined.contains('csbc') ||
        combined.contains('shs bihar') ||
        combined.contains('bihar police');
  }

  // ---------------------------------------------------------------------------
  // SAFE STRING HELPER
  // ---------------------------------------------------------------------------

  String _value(
    Map<String, dynamic> job,
    String key,
  ) {
    return (job[key] ?? '').toString().trim();
  }

  // ---------------------------------------------------------------------------
  // DATE / DEADLINE
  // ---------------------------------------------------------------------------

  DateTime? _parseDate(String value) {
    final text = value.trim();

    if (text.isEmpty) return null;

    // yyyy-mm-dd / yyyy/mm/dd
    final iso = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    ).firstMatch(text);

    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    // dd-mm-yyyy / dd/mm/yyyy
    final dmy = RegExp(
      r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})',
    ).firstMatch(text);

    if (dmy != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }

    // dd Month yyyy
    final monthPattern = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(text);

    if (monthPattern != null) {
      const months = {
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
      };

      final month =
          months[monthPattern.group(2)!.toLowerCase()];

      if (month != null) {
        return DateTime(
          int.parse(monthPattern.group(3)!),
          month,
          int.parse(monthPattern.group(1)!),
        );
      }
    }

    return null;
  }

  int? _daysRemaining(String lastDate) {
    final date = _parseDate(lastDate);

    if (date == null) return null;

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final deadline = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return deadline.difference(today).inDays;
  }

  String _deadlineLabel(String lastDate) {
    final days = _daysRemaining(lastDate);

    if (days == null) {
      return lastDate.isEmpty ? 'Date unavailable' : lastDate;
    }

    if (days < 0) {
      return 'Expired';
    }

    if (days == 0) {
      return 'Closes today';
    }

    if (days == 1) {
      return '1 day left';
    }

    if (days <= 7) {
      return '$days days left';
    }

    return lastDate;
  }

  bool _isUrgent(String lastDate) {
    final days = _daysRemaining(lastDate);

    return days != null && days >= 0 && days <= 7;
  }

  bool _isExpired(String lastDate) {
    final days = _daysRemaining(lastDate);

    return days != null && days < 0;
  }

  // ---------------------------------------------------------------------------
  // URL
  // ---------------------------------------------------------------------------

  Future<void> _openLink(String link) async {
    final value = link.trim();

    if (value.isEmpty) return;

    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final Color pageBg = widget.isDarkMode
        ? const Color(0xFF0B1120)
        : const Color(0xFFF4F7FB);

    final Color textColor = widget.isDarkMode
        ? Colors.white
        : navy;

    final Color subText = widget.isDarkMode
        ? Colors.white60
        : const Color(0xFF64748B);

    if (_isLoading) {
      return _loadingView(pageBg);
    }

    if (_allJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedJobs =
        _filteredJobs.where((job) {
          final lastDate = _value(job, 'last_date');

          // Hide only jobs whose date can confidently be parsed as expired.
          return !_isExpired(lastDate);
        }).take(2).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF111C2F)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF26354D)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: widget.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(.045),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(textColor, subText),

          const SizedBox(height: 16),

          _buildFilters(),

          const SizedBox(height: 14),

          if (displayedJobs.isEmpty)
            _emptyCategoryView(textColor, subText)
          else
            ...displayedJobs.map(
              (job) => _buildJobCard(
                job,
                textColor,
                subText,
              ),
            ),

          const SizedBox(height: 2),

          _buildViewAllButton(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  Widget _loadingView(Color bg) {
    return Container(
      height: 145,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 23,
          height: 23,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
    Color textColor,
    Color subText,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            color: primaryBlue,
            size: 22,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latest Job Alerts',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_allJobs.length} active opportunities',
                style: TextStyle(
                  fontSize: 11.5,
                  color: subText,
                ),
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: _isRefreshing
              ? null
              : () => fetchLatestJobs(refresh: true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: green.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRefreshing)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: green,
                    ),
                  )
                else
                  const Icon(
                    Icons.circle,
                    size: 6,
                    color: green,
                  ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: green,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    final biharCount =
        _allJobs.where(_isBiharJob).length;

    final centralCount =
        _allJobs.length - biharCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            keyName: 'all',
            label: 'All',
            count: _allJobs.length,
          ),
          const SizedBox(width: 8),
          _filterChip(
            keyName: 'bihar',
            label: 'Bihar Govt',
            count: biharCount,
          ),
          const SizedBox(width: 8),
          _filterChip(
            keyName: 'central',
            label: 'Central / Bank',
            count: centralCount,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String keyName,
    required String label,
    required int count,
  }) {
    final bool active =
        _selectedCategory == keyName;

    return GestureDetector(
      onTap: () {
        if (_selectedCategory == keyName) return;

        setState(() {
          _selectedCategory = keyName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: active
              ? primaryBlue
              : widget.isDarkMode
                  ? const Color(0xFF1B2940)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: active
                ? Colors.white
                : widget.isDarkMode
                    ? Colors.white70
                    : const Color(0xFF475569),
            fontSize: 10.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // JOB CARD
  // ---------------------------------------------------------------------------

  Widget _buildJobCard(
    Map<String, dynamic> job,
    Color textColor,
    Color subText,
  ) {
    final String title =
        _value(job, 'title').isEmpty
            ? 'Job Notification'
            : _value(job, 'title');

    final String organization =
        _value(job, 'organization');

    final String vacancies =
        _value(job, 'total_vacancies');

    final String qualification =
        _value(job, 'qualification');

    final String fee =
        _value(job, 'application_fee');

    final String lastDate =
        _value(job, 'last_date');

    final String applyUrl =
        _value(job, 'apply_url').isNotEmpty
            ? _value(job, 'apply_url')
            : _value(job, 'link').isNotEmpty
                ? _value(job, 'link')
                : _value(job, 'url');

    final bool bihar = _isBiharJob(job);
    final bool urgent = _isUrgent(lastDate);

    final String? explicitStatus =
        _value(job, 'status').isEmpty
            ? null
            : _value(job, 'status');

    final bool isNew =
        explicitStatus?.toLowerCase() == 'new' ||
        explicitStatus?.toLowerCase() == 'new job';

    final String deadline =
        _deadlineLabel(lastDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF172338)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF2B3B54)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BADGES
          Row(
            children: [
              _badge(
                bihar ? 'BIHAR GOVT' : 'CENTRAL GOVT',
                bihar ? orange : primaryBlue,
              ),

              const Spacer(),

              if (isNew)
                _badge('NEW', green)
              else if (urgent)
                _badge(
                  deadline == 'Closes today'
                      ? 'URGENT'
                      : deadline.toUpperCase(),
                  red,
                ),
            ],
          ),

          const SizedBox(height: 9),

          // TITLE
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -.1,
            ),
          ),

          if (organization.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              organization,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // STATS
          Row(
            children: [
              if (vacancies.isNotEmpty)
                Expanded(
                  child: _statBox(
                    icon: Icons.people_alt_outlined,
                    label: 'Vacancies',
                    value: vacancies,
                    color: green,
                  ),
                ),

              if (vacancies.isNotEmpty &&
                  qualification.isNotEmpty)
                const SizedBox(width: 7),

              if (qualification.isNotEmpty)
                Expanded(
                  child: _statBox(
                    icon: Icons.school_outlined,
                    label: 'Eligibility',
                    value: qualification,
                    color: primaryBlue,
                  ),
                ),
            ],
          ),

          if (fee.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 14,
                  color: subText,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Application Fee: $fee',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: subText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 11),

          // DEADLINE
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: urgent
                  ? red.withOpacity(.07)
                  : widget.isDarkMode
                      ? Colors.white.withOpacity(.04)
                      : Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: urgent ? red : subText,
                ),
                const SizedBox(width: 6),

                Flexible(
                  child: Text(
                    lastDate.isEmpty
                        ? 'Last Date: Not available'
                        : 'Last Date: $lastDate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: urgent ? red : textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if (deadline != lastDate &&
                    deadline != 'Expired' &&
                    lastDate.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    deadline,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: urgent ? red : green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: applyUrl.isEmpty
                  ? null
                  : () => _openLink(applyUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    widget.isDarkMode
                        ? Colors.white12
                        : Colors.grey.shade300,
                disabledForegroundColor:
                    widget.isDarkMode
                        ? Colors.white38
                        : Colors.grey.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    applyUrl.isEmpty
                        ? 'Notification Link Unavailable'
                        : 'View Notification',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (applyUrl.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE
  // ---------------------------------------------------------------------------

  Widget _badge(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .35,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAT BOX
  // ---------------------------------------------------------------------------

  Widget _statBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white54
                        : const Color(0xFF64748B),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY CATEGORY
  // ---------------------------------------------------------------------------

  Widget _emptyCategoryView(
    Color textColor,
    Color subText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 25,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 30,
              color: subText.withOpacity(.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No jobs found in this category',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW ALL BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildViewAllButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _showAllJobs,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: BorderSide(
            color: primaryBlue.withOpacity(.25),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Text(
              'View All Jobs',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            SizedBox(width: 5),
            Icon(
              Icons.arrow_forward_rounded,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ALL JOBS BOTTOM SHEET
  // ---------------------------------------------------------------------------

  void _showAllJobs() {
    final Color sheetBg = widget.isDarkMode
        ? const Color(0xFF0B1120)
        : Colors.white;

    final Color textColor = widget.isDarkMode
        ? Colors.white
        : navy;

    final Color subText = widget.isDarkMode
        ? Colors.white60
        : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: .90,
          maxChildSize: .96,
          minChildSize: .55,
          expand: false,
          builder: (
            context,
            scrollController,
          ) {
            final jobs = _filteredJobs.where((job) {
              final lastDate =
                  _value(job, 'last_date');

              return !_isExpired(lastDate);
            }).toList();

            return Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    14,
                    10,
                    12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: primaryBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Job Alerts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${jobs.length} opportunities',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: subText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: widget.isDarkMode
                      ? Colors.white10
                      : Colors.black12,
                ),

                Expanded(
                  child: jobs.isEmpty
                      ? Center(
                          child: Text(
                            'No active jobs available.',
                            style: TextStyle(
                              color: subText,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller:
                              scrollController,
                          padding:
                              const EdgeInsets.all(16),
                          itemCount: jobs.length,
                          itemBuilder:
                              (context, index) {
                            return _buildJobCard(
                              jobs[index],
                              textColor,
                              subText,
                            );
                          },
                        ),
                ),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      10,
                    ),
                    child: Text(
                      'Information is collected from official public notifications. MockTester is not a government entity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: textColor
                            .withOpacity(.4),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
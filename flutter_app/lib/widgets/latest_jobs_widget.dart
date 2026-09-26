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

class LatestJobsWidgetState extends State<LatestJobsWidget>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // THEME COLORS
  // ---------------------------------------------------------------------------
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color navy = Color(0xFF0F172A);
  static const Color green = Color(0xFF10B981);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> _allJobs = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedCategory = 'all';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    fetchLatestJobs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LIVE JSON FETCH (Multi-endpoint fallback)
  // ---------------------------------------------------------------------------
  Future<void> fetchLatestJobs({bool refresh = false}) async {
    if (refresh) {
      if (mounted) setState(() => _isRefreshing = true);
    } else {
      if (mounted) setState(() => _isLoading = true);
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
              },
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) continue;

        String body = utf8.decode(response.bodyBytes).trim();
        if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

        body = body
            .replaceFirst(RegExp(r'^```json\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^```\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim();

        if (body.startsWith('<')) continue;

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
            .map((job) => Map<String, dynamic>.from(job))
            .toList();

        if (!mounted) return;

        setState(() {
          _allJobs = parsedJobs;
          _isLoading = false;
          _isRefreshing = false;
        });

        return;
      } catch (_) {
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
  // FILTERING LOGIC
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> get _activeJobs {
    return _allJobs.where((job) {
      final lastDate = _value(job, 'last_date');
      return !_isExpired(lastDate);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredJobs {
    final activeList = _activeJobs;
    if (_selectedCategory == 'all') return activeList;

    return activeList.where((job) {
      final bool isBihar = _isBiharJob(job);
      if (_selectedCategory == 'bihar') return isBihar;
      if (_selectedCategory == 'central') return !isBihar;
      return true;
    }).toList();
  }

  bool _isBiharJob(Map<String, dynamic> job) {
    final String jobType = (job['job_type'] ?? '').toString().toLowerCase();
    final String title = (job['title'] ?? '').toString().toLowerCase();
    final String organization = (job['organization'] ?? '').toString().toLowerCase();
    final String state = (job['state'] ?? '').toString().toLowerCase();
    final String location = (job['location'] ?? '').toString().toLowerCase();

    final combined = [jobType, title, organization, state, location].join(' ');

    return combined.contains('bihar') ||
        combined.contains('patna') ||
        combined.contains('bpsc') ||
        combined.contains('bssc') ||
        combined.contains('bpssc') ||
        combined.contains('csbc') ||
        combined.contains('shs bihar') ||
        combined.contains('bihar police');
  }

  String _value(Map<String, dynamic> job, String key) {
    return (job[key] ?? '').toString().trim();
  }

  // ---------------------------------------------------------------------------
  // DATE PARSER & DEADLINE CALCULATION
  // ---------------------------------------------------------------------------
  DateTime? _parseDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final iso = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(text);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(text);
    if (dmy != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }

    final monthPattern = RegExp(
      r'^(\d{1,2})[\s\-\/]+([A-Za-z]+)[\s\-\/]+(\d{4})',
      caseSensitive: false,
    ).firstMatch(text);

    if (monthPattern != null) {
      const months = {
        'jan': 1, 'january': 1,
        'feb': 2, 'february': 2,
        'mar': 3, 'march': 3,
        'apr': 4, 'april': 4,
        'may': 5,
        'jun': 6, 'june': 6,
        'jul': 7, 'july': 7,
        'aug': 8, 'august': 8,
        'sep': 9, 'september': 9,
        'oct': 10, 'october': 10,
        'nov': 11, 'november': 11,
        'dec': 12, 'december': 12,
      };

      final month = months[monthPattern.group(2)!.toLowerCase()];
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
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(date.year, date.month, date.day);

    return deadline.difference(today).inDays;
  }

  String _deadlineLabel(String lastDate) {
    final days = _daysRemaining(lastDate);
    if (days == null) return lastDate.isEmpty ? 'Date N/A' : lastDate;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Closes Today';
    if (days == 1) return '1 Day Left';
    if (days <= 7) return '$days Days Left';
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
  // URL OPEN HANDLER
  // ---------------------------------------------------------------------------
  Future<void> _openLink(String link) async {
    final value = link.trim();
    if (value.isEmpty) return;

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showUrlError();
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _showUrlError();
    } catch (_) {
      _showUrlError();
    }
  }

  void _showUrlError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Text('⚠️ Link open nahi ho saka.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color textColor = isDark ? Colors.white : navy;
    final Color subText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (_isLoading) return _loadingView(isDark ? const Color(0xFF1E293B) : Colors.white);
    if (_allJobs.isEmpty) return const SizedBox.shrink();

    final displayedJobs = _filteredJobs;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Accurate active vacancies count)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildHeader(textColor, subText, _activeJobs.length),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
          ),

          const SizedBox(height: 12),

          // Active Jobs List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                if (displayedJobs.isEmpty)
                  _emptyCategoryView(textColor, subText)
                else
                  ...displayedJobs.map(
                    (job) => _buildJobCard(
                      job,
                      textColor,
                      subText,
                      isDark: isDark,
                      isCompact: true,
                    ),
                  ),
                const SizedBox(height: 4),
                _buildViewAllButton(isDark),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingView(Color bg) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subText, int activeCount) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.campaign_rounded, color: primaryBlue, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Latest Job Alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$activeCount active vacancies available',
                style: TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _isRefreshing ? null : () => fetchLatestJobs(refresh: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: green.withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: green.withOpacity(.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRefreshing)
                  const SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: green),
                  )
                else
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: green.withOpacity(_pulseAnimation.value),
                          boxShadow: const [
                            BoxShadow(color: green, blurRadius: 4, spreadRadius: 0.5),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: green,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final activeList = _activeJobs;
    final biharCount = activeList.where(_isBiharJob).length;
    final centralCount = activeList.length - biharCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChip(keyName: 'all', label: '🔥 All Alerts', count: activeList.length),
          const SizedBox(width: 6),
          _filterChip(keyName: 'bihar', label: '🏛️ Bihar Govt', count: biharCount),
          const SizedBox(width: 6),
          _filterChip(keyName: 'central', label: '🇮🇳 Central Govt', count: centralCount),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String keyName,
    required String label,
    required int count,
  }) {
    final bool active = _selectedCategory == keyName;

    return InkWell(
      onTap: () {
        if (_selectedCategory == keyName) return;
        setState(() => _selectedCategory = keyName);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: active
              ? primaryBlue
              : widget.isDarkMode
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? primaryBlue
                : widget.isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: active
                ? Colors.white
                : widget.isDarkMode
                    ? Colors.white70
                    : const Color(0xFF475569),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POLISHED JOB CARD
  // ---------------------------------------------------------------------------
  Widget _buildJobCard(
    Map<String, dynamic> job,
    Color textColor,
    Color subText, {
    required bool isDark,
    bool isCompact = false,
  }) {
    final String title = _value(job, 'title').isEmpty ? 'Job Notification' : _value(job, 'title');
    final String organization = _value(job, 'organization');
    final String vacancies = _value(job, 'total_vacancies');
    final String qualification = _value(job, 'qualification');
    final String fee = _value(job, 'application_fee');
    final String lastDate = _value(job, 'last_date');

    final String applyUrl = _value(job, 'apply_url').isNotEmpty
        ? _value(job, 'apply_url')
        : _value(job, 'link').isNotEmpty
            ? _value(job, 'link')
            : _value(job, 'url');

    final bool bihar = _isBiharJob(job);
    final bool urgent = _isUrgent(lastDate);
    final String? explicitStatus = _value(job, 'status').isEmpty ? null : _value(job, 'status');
    final bool isNew = explicitStatus?.toLowerCase() == 'new' || explicitStatus?.toLowerCase() == 'new job';
    final String deadline = _deadlineLabel(lastDate);

    final itemBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final itemBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: itemBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: urgent ? red.withOpacity(0.4) : itemBorder,
            width: urgent ? 1.2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: applyUrl.isEmpty ? null : () => _openLink(applyUrl),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Row
                Row(
                  children: [
                    _badge(bihar ? '🏛️ BIHAR' : '🇮🇳 CENTRAL', bihar ? orange : primaryBlue),
                    const Spacer(),
                    if (urgent)
                      _badge('⏰ $deadline', red, isSolid: true)
                    else if (isNew)
                      _badge('✨ NEW', green, isSolid: true),
                  ],
                ),

                const SizedBox(height: 8),

                // Job Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),

                if (organization.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    organization,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],

                const SizedBox(height: 9),

                // Vacancy & Qualification Row
                Row(
                  children: [
                    if (vacancies.isNotEmpty)
                      Expanded(
                        child: _statBox(
                          icon: Icons.people_outline_rounded,
                          label: 'Vacancies',
                          value: vacancies,
                          color: const Color(0xFF059669),
                          isDark: isDark,
                        ),
                      ),
                    if (vacancies.isNotEmpty && qualification.isNotEmpty) const SizedBox(width: 8),
                    if (qualification.isNotEmpty)
                      Expanded(
                        child: _statBox(
                          icon: Icons.school_outlined,
                          label: 'Eligibility',
                          value: qualification,
                          color: primaryBlue,
                          isDark: isDark,
                        ),
                      ),
                  ],
                ),

                if (!isCompact && fee.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(Icons.receipt_outlined, size: 14, color: subText),
                      const SizedBox(width: 4),
                      Text(
                        'Application Fee: $fee',
                        style: TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // Bottom Date + Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: urgent ? red : subText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          lastDate.isEmpty ? 'Date N/A' : 'Last: $lastDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: urgent ? red : subText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Clean View Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded, size: 11, color: primaryBlue),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, {bool isSolid = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isSolid ? color : color.withOpacity(.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSolid ? Colors.white : color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
    );
  }

  Widget _statBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : navy,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCategoryView(Color textColor, Color subText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 28, color: subText.withOpacity(.5)),
            const SizedBox(height: 6),
            Text(
              'No active jobs in this category',
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _showAllJobs,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: BorderSide(color: primaryBlue.withOpacity(.3)),
          backgroundColor: primaryBlue.withOpacity(.04),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Explore All Opportunities', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded, size: 14),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ALL JOBS MODAL SHEET (Interactive Category Switch)
  // ---------------------------------------------------------------------------
  void _showAllJobs() {
    final Color sheetBg = widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : navy;
    final Color subText = widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeJobsList = _activeJobs;
            final modalFilteredJobs = _selectedCategory == 'all'
                ? activeJobsList
                : activeJobsList.where((job) {
                    final bool isBihar = _isBiharJob(job);
                    if (_selectedCategory == 'bihar') return isBihar;
                    if (_selectedCategory == 'central') return !isBihar;
                    return true;
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: .90,
              maxChildSize: .96,
              minChildSize: .55,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_rounded, color: primaryBlue, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All Job Opportunities',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                                ),
                                Text(
                                  '${modalFilteredJobs.length} active notifications',
                                  style: TextStyle(fontSize: 11, color: subText),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: widget.isDarkMode ? Colors.white10 : Colors.black12),
                    Expanded(
                      child: modalFilteredJobs.isEmpty
                          ? Center(
                              child: Text('No active jobs available.', style: TextStyle(color: subText, fontSize: 12)),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: modalFilteredJobs.length,
                              itemBuilder: (context, index) {
                                return _buildJobCard(
                                  modalFilteredJobs[index],
                                  textColor,
                                  subText,
                                  isDark: widget.isDarkMode,
                                  isCompact: false,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

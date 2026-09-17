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
  // COLORS & THEME
  // ---------------------------------------------------------------------------

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color navy = Color(0xFF0F172A);
  static const Color green = Color(0xFF10B981);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // STATE & ANIMATION
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
  // LIVE JSON FETCH
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
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) continue;

        String body = utf8.decode(response.bodyBytes).trim();

        if (body.startsWith('\uFEFF')) {
          body = body.substring(1).trim();
        }

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
  // FILTERING & DETECTION
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredJobs {
    if (_selectedCategory == 'all') return _allJobs;

    return _allJobs.where((job) {
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
  // DATE PARSER & PROMINENT DEADLINE
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
  // URL LAUNCH
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
        content: const Text('⚠️ Notification link open nahi ho saka.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final Color pageBg = widget.isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF4F7FB);
    final Color textColor = widget.isDarkMode ? Colors.white : navy;
    final Color subText = widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B);

    if (_isLoading) return _loadingView(pageBg);
    if (_allJobs.isEmpty) return const SizedBox.shrink();

    final displayedJobs = _filteredJobs.where((job) {
      final lastDate = _value(job, 'last_date');
      return !_isExpired(lastDate);
    }).take(2).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF111C2F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF26354D) : const Color(0xFFDBEAFE),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF2563EB).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildHeader(textColor, subText),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                if (displayedJobs.isEmpty)
                  _emptyCategoryView(textColor, subText)
                else
                  ...displayedJobs.map(
                    (job) => _buildJobCard(job, textColor, subText, isCompact: true),
                  ),
                const SizedBox(height: 2),
                _buildViewAllButton(),
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
      height: 125,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subText) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 42 * _pulseAnimation.value,
                  height: 42 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryBlue.withOpacity(0.18 * (1 - _pulseAnimation.value + 0.3)),
                  ),
                );
              },
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.campaign_rounded, color: primaryBlue, size: 20),
            ),
          ],
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
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: red,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1.5),
              Text(
                '${_allJobs.length} active vacancies updated today',
                style: TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _isRefreshing ? null : () => fetchLatestJobs(refresh: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4.5),
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
                    width: 9,
                    height: 9,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: green),
                  )
                else
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: green,
                            boxShadow: [
                              BoxShadow(color: green, blurRadius: 4, spreadRadius: 1.5),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 5.5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: green,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
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
  // FILTERS (Safer "Central Govt" Label)
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    final biharCount = _allJobs.where(_isBiharJob).length;
    final centralCount = _allJobs.length - biharCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChip(keyName: 'all', label: '🔥 All Alerts', count: _allJobs.length),
          const SizedBox(width: 8),
          _filterChip(keyName: 'bihar', label: '🏛️ Bihar Govt', count: biharCount),
          const SizedBox(width: 8),
          // 🎯 Fix 1: Safer "Central Govt" Label
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

    return GestureDetector(
      onTap: () {
        if (_selectedCategory == keyName) return;
        setState(() => _selectedCategory = keyName);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: active
              ? primaryBlue
              : widget.isDarkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? primaryBlue : Colors.transparent),
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
  // JOB CARD (Prominent Deadline + View Details Action)
  // ---------------------------------------------------------------------------

  Widget _buildJobCard(
    Map<String, dynamic> job,
    Color textColor,
    Color subText, {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF172338) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: urgent
              ? red.withOpacity(0.4)
              : widget.isDarkMode
                  ? const Color(0xFF2B3B54)
                  : const Color(0xFFE2E8F0),
          width: urgent ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges
          Row(
            children: [
              _badge(bihar ? 'BIHAR GOVT' : 'CENTRAL GOVT', bihar ? orange : primaryBlue),
              const Spacer(),
              if (urgent)
                _badge('🚨 $deadline', red, isSolid: true)
              else if (isNew)
                _badge('✨ NEW OPENING', green, isSolid: true),
            ],
          ),

          const SizedBox(height: 7),

          // Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 13.8,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),

          if (organization.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              organization,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subText, fontSize: 10.8, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 8),

          // Stats
          Row(
            children: [
              if (vacancies.isNotEmpty)
                Expanded(
                  child: _statBox(
                    icon: Icons.groups_rounded,
                    label: 'Total Posts',
                    value: vacancies,
                    color: green,
                  ),
                ),
              if (vacancies.isNotEmpty && qualification.isNotEmpty) const SizedBox(width: 6),
              if (qualification.isNotEmpty)
                Expanded(
                  child: _statBox(
                    icon: Icons.school_rounded,
                    label: 'Eligibility',
                    value: qualification,
                    color: primaryBlue,
                  ),
                ),
            ],
          ),

          if (!isCompact && fee.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 14, color: subText),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Fee: $fee',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 9),

          // 🎯 Fix 2 & 3: Prominent Last Date + "View Details" CTA
          Row(
            children: [
              // Prominent Deadline Container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: urgent
                        ? (widget.isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                        : (widget.isDarkMode ? Colors.white.withOpacity(.04) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: urgent
                          ? red.withOpacity(0.5)
                          : (widget.isDarkMode ? const Color(0xFF2B3B54) : const Color(0xFFE2E8F0)),
                      width: urgent ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: urgent ? red : subText,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          lastDate.isEmpty ? 'Date N/A' : 'Last Date: $lastDate',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.2,
                            color: urgent ? red : textColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🎯 Fix 3: Home Card par "View Details" button jo Sheet kholta hai
              if (isCompact) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showAllJobs,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryBlue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded, size: 12, color: primaryBlue),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Detailed View Inside Bottom Sheet
          if (!isCompact) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: applyUrl.isEmpty ? null : () => _openLink(applyUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Apply on Official Website', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                    SizedBox(width: 5),
                    Icon(Icons.open_in_new_rounded, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {bool isSolid = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? color : color.withOpacity(.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSolid ? Colors.white : color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
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
                    color: widget.isDarkMode ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 28, color: subText.withOpacity(.5)),
            const SizedBox(height: 6),
            Text(
              'No jobs found in this category',
              style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton() {
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
            Text('Explore All Opportunities', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded, size: 14),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ALL JOBS BOTTOM SHEET
  // ---------------------------------------------------------------------------

  void _showAllJobs() {
    final Color sheetBg = widget.isDarkMode ? const Color(0xFF0B1120) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : navy;
    final Color subText = widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: .90,
          maxChildSize: .96,
          minChildSize: .55,
          expand: false,
          builder: (context, scrollController) {
            final jobs = _filteredJobs.where((job) {
              final lastDate = _value(job, 'last_date');
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: primaryBlue, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Job Opportunities',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                            ),
                            const SizedBox(height: 2),
                            Text('${jobs.length} active notifications', style: TextStyle(fontSize: 10.5, color: subText)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: widget.isDarkMode ? Colors.white10 : Colors.black12),
                Expanded(
                  child: jobs.isEmpty
                      ? Center(
                          child: Text('No active jobs available.', style: TextStyle(color: subText, fontSize: 12)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) {
                            return _buildJobCard(jobs[index], textColor, subText, isCompact: false);
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Text(
                      'Official notifications collected from public domain portals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: textColor.withOpacity(.4)),
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

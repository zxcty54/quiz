import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LatestJobsWidget extends StatefulWidget {
  final bool isDarkMode;
  const LatestJobsWidget({super.key, required this.isDarkMode});

  @override
  State<LatestJobsWidget> createState() => LatestJobsWidgetState();
}

class LatestJobsWidgetState extends State<LatestJobsWidget> {
  List<dynamic> _allJobs = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    fetchLatestJobs();
  }

  // 📰 PUBLIC FETCH METHOD (Pull-to-refresh ke liye)
  Future<void> fetchLatestJobs() async {
    if (mounted) setState(() => _isLoading = true);
    
    // Timestamp parameter ensures cache bypass on refresh
    final String url =
        "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/sarkarijob.json?t=${DateTime.now().millisecondsSinceEpoch}";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (mounted) {
          setState(() {
            if (data is Map && data.containsKey('latest_jobs')) {
              _allJobs = data['latest_jobs'] as List;
            } else if (data is List) {
              _allJobs = data;
            } else {
              _allJobs = [];
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. SMART MULTI-FIELD FILTERING LOGIC
  List<dynamic> get _filteredJobs {
    if (_selectedCategory == 'all') return _allJobs;

    return _allJobs.where((job) {
      if (job is! Map) return false;

      final String jobType = (job['job_type'] ?? '').toString().toLowerCase();
      final String title = (job['title'] ?? '').toString().toLowerCase();
      final String org = (job['organization'] ?? '').toString().toLowerCase();

      final bool isBiharJob = jobType.contains('bihar') ||
          title.contains('bihar') ||
          title.contains('patna') ||
          title.contains('bpsc') ||
          title.contains('bssc') ||
          title.contains('bpssc') ||
          title.contains('shs') ||
          org.contains('bihar') ||
          org.contains('patna');

      if (_selectedCategory == 'bihar') {
        return isBiharJob;
      } else if (_selectedCategory == 'central') {
        return !isBiharJob || jobType.contains('central') || jobType.contains('bank');
      }
      return true;
    }).toList();
  }

  Future<void> _openLink(String link) async {
    if (link.isEmpty) return;
    final Uri uri = Uri.parse(link);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2),
        ),
      );
    }

    if (_allJobs.isEmpty) return const SizedBox.shrink();

    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final displayedJobs = _filteredJobs;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_allJobs.length} Active',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'All (${_allJobs.length})'),
                const SizedBox(width: 8),
                _buildCategoryChip('bihar', 'Bihar Govt'),
                const SizedBox(width: 8),
                _buildCategoryChip('central', 'Central / Bank'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 340,
            child: displayedJobs.isEmpty
                ? const Center(
                    child: Text(
                      'Is category mein koi notification nahi mila.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayedJobs.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final job = displayedJobs[index];
                      return _buildDetailedJobCard(job, textColor);
                    },
                  ),
          ),

          const SizedBox(height: 8),

          InkWell(
            onTap: _showAllJobsBottomSheet,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View All Jobs',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String catKey, String label) {
    final bool isSelected = _selectedCategory == catKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = catKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (widget.isDarkMode ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedJobCard(Map<String, dynamic> job, Color textColor) {
    final String title = job['title'] ?? 'Job Notification';
    final String organization = job['organization'] ?? '';
    final String vacancies = job['total_vacancies'] ?? '';
    final String qualification = job['qualification'] ?? '';
    final String fee = job['application_fee'] ?? '';
    final String lastDate = job['last_date'] ?? '';
    final String applyUrl = job['apply_url'] ?? job['link'] ?? '';
    final String jobType = (job['job_type'] ?? '').toString().toLowerCase();

    final bool isBihar = jobType.contains('bihar') ||
        title.toLowerCase().contains('bihar') ||
        title.toLowerCase().contains('patna') ||
        organization.toLowerCase().contains('bihar');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBihar ? 'BIHAR GOVT' : 'CENTRAL GOVT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isBihar ? Colors.orange.shade800 : const Color(0xFF2563EB),
                ),
              ),
              if (vacancies.isNotEmpty)
                Text(
                  vacancies,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              if (organization.isNotEmpty) ...[
                Text(
                  organization,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                if (qualification.isNotEmpty)
                  Text(
                    ' • ',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white30 : Colors.grey.shade400,
                    ),
                  ),
              ],
              if (qualification.isNotEmpty)
                Expanded(
                  child: Text(
                    qualification,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),

          if (fee.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '💳 Fee: $fee',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (lastDate.isNotEmpty)
                Text(
                  'Last Date: $lastDate',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const SizedBox.shrink(),

              InkWell(
                onTap: () => _openLink(applyUrl),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_outward_rounded, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAllJobsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Notifications (${_allJobs.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _allJobs.length,
                      itemBuilder: (context, index) {
                        return _buildDetailedJobCard(_allJobs[index], textColor);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

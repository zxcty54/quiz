import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LatestJobsWidget extends StatefulWidget {
  final bool isDarkMode;
  const LatestJobsWidget({super.key, required this.isDarkMode});

  @override
  State<LatestJobsWidget> createState() => _LatestJobsWidgetState();
}

class _LatestJobsWidgetState extends State<LatestJobsWidget> {
  List<dynamic> _allJobs = [];
  bool _isLoading = true;
  String _selectedCategory = 'all'; // 'all', 'bihar', 'central'

  @override
  void initState() {
    super.initState();
    _fetchLatestJobs();
  }

  // 📰 FETCH LIVE JOBS FROM GITHUB CDN (sarkarijob.json)
  Future<void> _fetchLatestJobs() async {
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

  // 🔍 CATEGORY FILTERING LOGIC
  List<dynamic> get _filteredJobs {
    if (_selectedCategory == 'all') return _allJobs;
    return _allJobs.where((job) {
      final jobType = (job['job_type'] ?? '').toString().toLowerCase();
      if (_selectedCategory == 'bihar') {
        return jobType.contains('bihar');
      } else if (_selectedCategory == 'central') {
        return jobType.contains('central') || jobType.contains('bank');
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
        height: 120,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2)),
      );
    }

    if (_allJobs.isEmpty) return const SizedBox.shrink();

    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final displayedJobs = _filteredJobs;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sarkari Job Alerts',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
                ),
                child: Text(
                  '${_allJobs.length} Active',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. CATEGORY FILTER CHIPS (ALL / BIHAR / CENTRAL)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'All (${_allJobs.length})'),
                const SizedBox(width: 6),
                _buildCategoryChip('bihar', '📍 Bihar Govt'),
                const SizedBox(width: 6),
                _buildCategoryChip('central', '🏛️ Central / Bank'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. INCREASED HEIGHT SCROLLABLE JOBS LIST (320px Window)
          SizedBox(
            height: 320,
            child: displayedJobs.isEmpty
                ? const Center(
                    child: Text(
                      'No active notifications in this category.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayedJobs.length,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final job = displayedJobs[index];
                      return _buildDetailedJobCard(job, textColor);
                    },
                  ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // 4. VIEW ALL BUTTON
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: _showAllJobsBottomSheet,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All Jobs in Full Screen',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String catKey, String label) {
    final bool isSelected = _selectedCategory == catKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected
            ? Colors.white
            : (widget.isDarkMode ? Colors.white70 : const Color(0xFF475569)),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategory = catKey;
          });
        }
      },
    );
  }

  // 📌 DETAILED JOB CARD WITH "APPLY NOW" BUTTON & ALL JSON FIELDS
  Widget _buildDetailedJobCard(Map<String, dynamic> job, Color textColor) {
    final String title = job['title'] ?? 'Job Notification';
    final String organization = job['organization'] ?? '';
    final String postName = job['post_name'] ?? '';
    final String vacancies = job['total_vacancies'] ?? '';
    final String qualification = job['qualification'] ?? '';
    final String fee = job['application_fee'] ?? '';
    final String startDate = job['start_date'] ?? '';
    final String lastDate = job['last_date'] ?? '';
    final String applyUrl = job['apply_url'] ?? job['link'] ?? '';
    final String jobType = (job['job_type'] ?? '').toString().toLowerCase();
    final bool isBihar = jobType.contains('bihar');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Tag & Last Date Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBihar ? Colors.amber.shade50 : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(isBihar ? '📍 ' : '🏛️ ', style: const TextStyle(fontSize: 10)),
                    Text(
                      job['job_type'] ?? 'Sarkari Job',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isBihar ? Colors.amber.shade900 : const Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
              ),
              if (lastDate.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Colors.redAccent),
                    const SizedBox(width: 3),
                    Text(
                      'Last Date: $lastDate',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Title
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Organization & Post Name Details
          if (organization.isNotEmpty || postName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                '🏢 ${organization.isNotEmpty ? organization : postName}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Vacancy & Qualification Badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (vacancies.isNotEmpty)
                _buildInfoBadge('🎯 $vacancies', Colors.green.shade50, Colors.green.shade700),
              if (qualification.isNotEmpty)
                _buildInfoBadge('🎓 $qualification', const Color(0xFFF1F5F9), const Color(0xFF334155)),
              if (startDate.isNotEmpty)
                _buildInfoBadge('📅 Start: $startDate', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
            ],
          ),

          // Fee Information
          if (fee.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '💳 Fee: $fee',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: widget.isDarkMode ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // APPLY NOW BUTTON ROW
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openLink(applyUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Apply Now ➔',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.white10 : bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: widget.isDarkMode ? Colors.white90 : textColor,
        ),
      ),
    );
  }

  // 📱 FULL BOTTOM SHEET FOR ALL JOBS
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📢 All Job Notifications (${_allJobs.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'creator_mock_builder_screen.dart';
import 'creator_profile_screen.dart';

// 🚀 Modular Sheet Imports
import '../widgets/student_intelligence_sheet.dart';
import '../widgets/batch_manager_modal.dart';
import '../widgets/coaching_editor_sheets.dart';
import '../widgets/content_publisher_modal.dart';

class CreatorDashboardScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorDashboardScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  Map<String, dynamic>? _coachingData;
  List<dynamic> _batches = [];
  bool _isLoading = true;

  int _totalViews = 0;
  int _totalMockAttempts = 0;
  int _totalBatchStudents = 0;

  List<dynamic> _allRawSubmissions = [];
  List<dynamic> _allBatchTests = [];

  @override
  void initState() {
    super.initState();
    _loadCompleteAnalytics();
  }

  Future<void> _loadCompleteAnalytics() async {
    try {
      final client = Supabase.instance.client;
      final handle = widget.creatorHandle.trim();

      dynamic coachingRes = await client
          .from('coachings')
          .select()
          .ilike('owner_name', handle)
          .maybeSingle();

      coachingRes ??= await client
          .from('coachings')
          .select()
          .ilike('creator_handle', handle)
          .maybeSingle();

      List<dynamic> batchesRes = [];
      List<dynamic> batchTestsRes = [];
      List<dynamic> submissionsRes = [];
      int batchTestAttempts = 0;
      final Set<String> uniqueStudentKeys = {};

      if (coachingRes != null) {
        final coachingId = coachingRes['id'];

        batchesRes = await client
            .from('batches')
            .select('*')
            .eq('coaching_id', coachingId)
            .order('created_at', ascending: false);

        if (batchesRes.isNotEmpty) {
          final List<String> batchIds =
              batchesRes.map((b) => b['id'].toString()).toList();

          try {
            batchTestsRes = await client
                .from('batch_tests')
                .select('*')
                .inFilter('batch_id', batchIds)
                .order('created_at', ascending: false);

            for (var t in batchTestsRes) {
              batchTestAttempts += (t['attempts_count'] as int? ?? 0);
            }
          } catch (_) {}

          try {
            submissionsRes = await client
                .from('batch_submissions')
                .select('*')
                .inFilter('batch_id', batchIds)
                .order('created_at', ascending: false);

            for (var s in submissionsRes) {
              final rawId = (s['student_identifier'] ?? s['student_name'] ?? 'student').toString();
              uniqueStudentKeys.add(rawId);
            }
          } catch (_) {}
        }
      }

      // Views & Public mocks
      final postsRes = await client.from('community_posts').select('views_count').eq('creator_id', handle);
      int views = 0;
      for (var p in (postsRes as List? ?? [])) {
        views += (p['views_count'] as int? ?? 0);
      }

      final mocksRes = await client.from('creator_mocks').select('id, attempts_count').eq('creator_id', handle);
      int publicAttempts = 0;
      for (var m in (mocksRes as List? ?? [])) {
        publicAttempts += (m['attempts_count'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _coachingData = coachingRes;
          _batches = batchesRes;
          _allBatchTests = batchTestsRes;
          _allRawSubmissions = submissionsRes;
          _totalViews = views;
          _totalMockAttempts = publicAttempts + batchTestAttempts;
          _totalBatchStudents = uniqueStudentKeys.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🎯 Open Modular Performance Sheet
  void _openStudentIntelligenceSheet() {
    if (_batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aapke paas abhi koi active batch nahi hai.'), backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StudentIntelligenceSheet(
        batches: _batches,
        rawSubmissions: _allRawSubmissions,
        batchTests: _allBatchTests,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  // 🏫 Open Modular Batch Manager
  void _openBatchManagerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => BatchManagerModal(
        batches: _batches,
        coachingId: _coachingData?['id'],
        isDarkMode: widget.isDarkMode,
        onRefresh: _loadCompleteAnalytics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(backgroundColor: bgSurface, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Institute Studio & Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadCompleteAnalytics();
            },
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatorProfileScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_coachingData?['name'] ?? 'Coaching Hub', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('@${widget.creatorHandle} • ${_coachingData?['city'] ?? "Bihar"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Students', '$_totalBatchStudents', Icons.groups_outlined),
                      _buildMetricItem('Batches', '${_batches.length}', Icons.class_outlined),
                      _buildMetricItem('Attempts', '$_totalMockAttempts', Icons.bolt_rounded),
                      _buildMetricItem('Views', '$_totalViews', Icons.remove_red_eye_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildActionCard(
              title: 'Student Performance Intelligence 📊',
              subtitle: 'Batch-wise / Overall analytics, test breakdown and question paper view.',
              icon: Icons.insights_rounded,
              color: const Color(0xFF2563EB),
              onTap: _openStudentIntelligenceSheet,
            ),
            const SizedBox(height: 14),

            const Text('Modify Institute & Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Modify Banner / Poster 🖼️',
              subtitle: 'Change billboard photo without affecting address or details.',
              icon: Icons.photo_library_outlined,
              color: const Color(0xFF2563EB),
              onTap: () => CoachingEditorSheets.openBannerModifierSheet(
                context: context,
                coachingId: _coachingData?['id'],
                currentUrl: _coachingData?['banner_url'],
                creatorHandle: widget.creatorHandle,
                isDarkMode: isDark,
                onSaved: _loadCompleteAnalytics,
              ),
            ),

            _buildActionCard(
              title: 'Edit Location & Details 📍',
              subtitle: 'Update district, education hub, landmark address or helpline number.',
              icon: Icons.edit_location_alt_outlined,
              color: const Color(0xFF16A34A),
              onTap: () => CoachingEditorSheets.openDetailsModifierSheet(
                context: context,
                coachingData: _coachingData,
                creatorHandle: widget.creatorHandle,
                isDarkMode: isDark,
                onSaved: _loadCompleteAnalytics,
              ),
            ),

            _buildActionCard(
              title: 'Manage Batches & Codes 🏫',
              subtitle: 'Add new batch, toggle LIVE / UPCOMING / HIDE, copy secret code.',
              icon: Icons.vpn_key_outlined,
              color: const Color(0xFFEA580C),
              onTap: _openBatchManagerModal,
            ),
            const SizedBox(height: 16),

            const Text('Publish Content & Tests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Create CBT Mock Test ⚡',
              subtitle: 'Build timed CBT tests for public feed or private classroom batches.',
              icon: Icons.assignment_add,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreatorMockBuilderScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark)),
              ).then((_) => _loadCompleteAnalytics()),
            ),

            _buildActionCard(
              title: 'Share PDF Notes & Handouts 📚',
              subtitle: 'Post Google Drive, Telegram or download links for student notes.',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFF059669),
              onTap: () => ContentPublisherModal.openPublishSheet(
                context: context,
                type: 'pdf',
                creatorHandle: widget.creatorHandle,
                coachingName: _coachingData?['name'],
                profileName: null,
                isDarkMode: isDark,
                onPublished: _loadCompleteAnalytics,
              ),
            ),

            _buildActionCard(
              title: 'Publish Daily Rapid Quiz 🎯',
              subtitle: 'Create 4-option instant polls with solution on community feed.',
              icon: Icons.poll_outlined,
              color: const Color(0xFF2563EB),
              onTap: () => ContentPublisherModal.openPublishSheet(
                context: context,
                type: 'quiz',
                creatorHandle: widget.creatorHandle,
                coachingName: _coachingData?['name'],
                profileName: null,
                isDarkMode: isDark,
                onPublished: _loadCompleteAnalytics,
              ),
            ),

            _buildActionCard(
              title: 'Post Notice & Announcement 📢',
              subtitle: 'Share batch timing, examination updates, or results celebrations.',
              icon: Icons.campaign_outlined,
              color: const Color(0xFFD97706),
              onTap: () => ContentPublisherModal.openPublishSheet(
                context: context,
                type: 'notice',
                creatorHandle: widget.creatorHandle,
                coachingName: _coachingData?['name'],
                profileName: null,
                isDarkMode: isDark,
                onPublished: _loadCompleteAnalytics,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

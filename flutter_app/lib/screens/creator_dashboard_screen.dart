import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_telegram_alert.dart';
import 'creator_mock_builder_screen.dart';
import 'creator_profile_screen.dart';

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
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _coachingData;
  List<dynamic> _posts = [];
  List<dynamic> _mocks = [];
  List<dynamic> _batches = [];
  bool _isLoading = true;

  int _totalViews = 0;
  int _totalUpvotes = 0;
  int _totalBookmarks = 0;
  int _totalShares = 0;
  int _totalMockAttempts = 0;
  int _totalBatchStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadCompleteAnalytics();
  }

  Future<void> _loadCompleteAnalytics() async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch Profile & Coaching Details
      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      final coachingRes = await client
          .from('coachings')
          .select()
          .eq('owner_name', widget.creatorHandle)
          .maybeSingle();

      // 2. Fetch Batches & Submissions
      List<dynamic> batchesRes = [];
      int batchStudentsCount = 0;
      if (coachingRes != null) {
        batchesRes = await client
            .from('batches')
            .select('*, batch_tests(id, test_title)')
            .eq('coaching_id', coachingRes['id'])
            .order('created_at', ascending: false);

        final submissions = await client
            .from('batch_submissions')
            .select('student_identifier')
            .inFilter('batch_id', batchesRes.map((b) => b['id']).toList());

        final uniqueStudents = <String>{};
        for (var s in (submissions as List? ?? [])) {
          if (s['student_identifier'] != null) uniqueStudents.add(s['student_identifier']);
        }
        batchStudentsCount = uniqueStudents.length;
      }

      final postsRes = await client
          .from('community_posts')
          .select('*, post_comments(id)')
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      final mocksRes = await client
          .from('creator_mocks')
          .select()
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      int views = 0;
      int upvotes = 0;
      int bookmarks = 0;
      int shares = 0;

      for (var p in (postsRes as List? ?? [])) {
        views += (p['views_count'] as int? ?? 0);
        upvotes += (p['upvotes'] as int? ?? 0);
        bookmarks += (p['bookmarks_count'] as int? ?? 0);
        shares += (p['shares_count'] as int? ?? 0);
      }

      int attempts = 0;
      for (var m in (mocksRes as List? ?? [])) {
        attempts += (m['attempts_count'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _coachingData = coachingRes;
          _batches = batchesRes;
          _posts = postsRes ?? [];
          _mocks = mocksRes ?? [];
          _totalViews = views;
          _totalUpvotes = upvotes;
          _totalBookmarks = bookmarks;
          _totalShares = shares;
          _totalMockAttempts = attempts;
          _totalBatchStudents = batchStudentsCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics load error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🏫 Modal to Create New Coaching Batch
  void _openCreateBatchModal() {
    final batchNameCtrl = TextEditingController();
    final batchCodeCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🏫 Create Class Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: batchNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Batch Name (e.g. BSSC CGL 2026 Target)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: batchCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Unique Join Code (e.g. PATNA100)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final bName = batchNameCtrl.text.trim();
                          final bCode = batchCodeCtrl.text.trim().toUpperCase();

                          if (bName.isEmpty || bCode.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all details!')),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);

                          try {
                            String? coachingId = _coachingData?['id'];

                            if (coachingId == null) {
                              final newCoaching = await Supabase.instance.client.from('coachings').insert({
                                'name': _profile?['name'] ?? widget.creatorHandle,
                                'owner_name': widget.creatorHandle,
                              }).select().single();
                              coachingId = newCoaching['id'];
                            }

                            await Supabase.instance.client.from('batches').insert({
                              'coaching_id': coachingId,
                              'batch_name': bName,
                              'batch_code': bCode,
                            });

                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadCompleteAnalytics();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Batch "$bName" created with Code: $bCode! 🚀')),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Batch Code 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Modal to Customize Institute Page (Banner & Details)
  void _openInstituteCustomizerModal() {
    final nameCtrl = TextEditingController(text: _coachingData?['name'] ?? _profile?['name'] ?? '');
    final bannerCtrl = TextEditingController(text: _coachingData?['banner_url'] ?? '');
    final cityCtrl = TextEditingController(text: _coachingData?['city'] ?? 'Patna');
    final contactCtrl = TextEditingController(text: _coachingData?['contact_number'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🎨 Institute Branding & Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Coaching / Institute Name', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bannerCtrl,
                  decoration: const InputDecoration(labelText: 'Banner Poster URL (16:9 Image Link)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: 'City / Town', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        decoration: const InputDecoration(labelText: 'Contact / WhatsApp', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              if (_coachingData != null) {
                                await Supabase.instance.client.from('coachings').update({
                                  'name': nameCtrl.text.trim(),
                                  'banner_url': bannerCtrl.text.trim(),
                                  'city': cityCtrl.text.trim(),
                                  'contact_number': contactCtrl.text.trim(),
                                }).eq('id', _coachingData!['id']);
                              } else {
                                await Supabase.instance.client.from('coachings').insert({
                                  'name': nameCtrl.text.trim(),
                                  'owner_name': widget.creatorHandle,
                                  'banner_url': bannerCtrl.text.trim(),
                                  'city': cityCtrl.text.trim(),
                                  'contact_number': contactCtrl.text.trim(),
                                });
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Institute details updated! 🚀'), backgroundColor: Color(0xFF16A34A)),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Publish Branding 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Creator Creation Modal (Daily Quiz & PDF Notes Only)
  void _openCreationModal(String type) {
    final textCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final opCtrl1 = TextEditingController();
    final opCtrl2 = TextEditingController();
    final opCtrl3 = TextEditingController();
    final opCtrl4 = TextEditingController();
    int correctIdx = 0;
    bool isPoll = type == 'quiz';
    bool isPublishing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPoll ? '⚡ Publish Daily Rapid Quiz' : '📚 Share PDF Notes & Handouts',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  maxLines: isPoll ? 2 : 3,
                  decoration: InputDecoration(
                    hintText: isPoll
                        ? 'Type Quiz Question text here...'
                        : 'Explain topic or notes headline...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // ⚡ 1. Daily Quiz Options Setup
                if (isPoll) ...[
                  const Text('Options & Correct Answer (Tap letter to set correct):',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ...List.generate(4, (idx) {
                    final controllers = [opCtrl1, opCtrl2, opCtrl3, opCtrl4];
                    final isCorrect = correctIdx == idx;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => correctIdx = idx),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCorrect ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                              child: Text(
                                String.fromCharCode(65 + idx),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCorrect ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers[idx],
                              decoration: InputDecoration(
                                hintText: 'Option ${String.fromCharCode(65 + idx)}',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Explanation (Optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                // 📚 2. PDF Handouts Link Setup
                if (type == 'note') ...[
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Google Drive / Telegram PDF Link (https://...)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isPublishing
                        ? null
                        : () async {
                            final text = textCtrl.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter content text!')),
                              );
                              return;
                            }

                            if (isPoll &&
                                (opCtrl1.text.trim().isEmpty || opCtrl2.text.trim().isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please provide at least Option A and Option B!')),
                              );
                              return;
                            }

                            setModalState(() => isPublishing = true);

                            String content = text;
                            if (type == 'note' && linkCtrl.text.trim().isNotEmpty) {
                              content += '\n\n${linkCtrl.text.trim()}';
                            }

                            Map<String, dynamic>? pollJson;
                            if (isPoll) {
                              final rawOptions = [
                                opCtrl1.text.trim(),
                                opCtrl2.text.trim(),
                                opCtrl3.text.trim(),
                                opCtrl4.text.trim(),
                              ].where((o) => o.isNotEmpty).toList();

                              pollJson = {
                                'options': rawOptions,
                                'correct_idx': correctIdx < rawOptions.length ? correctIdx : 0,
                                'votes': List.filled(rawOptions.length, 0),
                                'exp': expCtrl.text.trim().isNotEmpty
                                    ? expCtrl.text.trim()
                                    : 'Explained by @${widget.creatorHandle}',
                              };
                            }

                            try {
                              String targetTag = isPoll ? 'Daily Quiz ⚡' : 'Current Affairs 📰';
                              final authorName = _profile?['name'] ?? widget.creatorHandle;

                              final inserted = await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': widget.creatorHandle,
                                'author_name': authorName,
                                'content': content,
                                'tag': targetTag,
                                'poll_data': pollJson,
                                'views_count': 1,
                                'is_approved': false,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

                              AdminTelegramAlert.sendForInteractiveApproval(
                                postId: inserted['id'] ?? 0,
                                authorName: authorName,
                                authorHandle: widget.creatorHandle,
                                tag: targetTag,
                                content: content,
                                hasPoll: isPoll,
                              ).catchError((_) => false);

                              if (ctx.mounted) Navigator.pop(ctx);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⏳ Post submitted! Awaiting Telegram approval.'),
                                    backgroundColor: Color(0xFF2563EB),
                                  ),
                                );
                                _loadCompleteAnalytics();
                              }
                            } catch (err) {
                              setModalState(() => isPublishing = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Publish error: $err')),
                                );
                              }
                            }
                          },
                    child: isPublishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit for Review 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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
        title: const Text('Coaching Studio & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'View Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatorProfileScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📊 1. Performance Overview Card (Batch & Public Metrics)
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_coachingData?['name'] ?? _profile?['name'] ?? 'Coaching Hub', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('INSTITUTE', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  Text('@${widget.creatorHandle} • ${_coachingData?['city'] ?? _profile?['subject_specialty'] ?? 'Exam Mentor'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Students', '$_totalBatchStudents', Icons.groups_outlined),
                      _buildMetricItem('Batches', '${_batches.length}', Icons.class_outlined),
                      _buildMetricItem('CBT Attempts', '$_totalMockAttempts', Icons.bolt_rounded),
                      _buildMetricItem('Public Views', '$_totalViews', Icons.remove_red_eye_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🏫 2. Coaching & Batch Management Hub
            const Text('Coaching & Batch Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Create & Manage Batches 🏫',
              subtitle: 'Generate unique batch codes (e.g. BSSC2026) for your students.',
              icon: Icons.add_business_outlined,
              color: const Color(0xFF0D9488),
              onTap: _openCreateBatchModal,
            ),

            _buildActionCard(
              title: 'Customize Institute Page & Posters 🎨',
              subtitle: 'Upload coaching banner poster, city, and contact details.',
              icon: Icons.photo_library_outlined,
              color: const Color(0xFFEA580C),
              onTap: _openInstituteCustomizerModal,
            ),
            const SizedBox(height: 12),

            // 🚀 3. Studio Creation Tools
            const Text('CBT Mock & Content Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'CBT Mock Test Builder ⚡',
              subtitle: 'Create timed tests for private batches or public marketing feed.',
              icon: Icons.assignment_add,
              color: const Color(0xFF2563EB),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorMockBuilderScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark),
                ),
              ).then((_) => _loadCompleteAnalytics()),
            ),

            _buildActionCard(
              title: 'Interactive Daily Quiz Card 🎯',
              subtitle: 'Post instant 4-option poll with solution directly to feed.',
              icon: Icons.poll_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => _openCreationModal('quiz'),
            ),

            _buildActionCard(
              title: 'Publish PDF Notes & Mindmaps 📚',
              subtitle: 'Link Google Drive or Telegram notes without server upload load.',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFF059669),
              onTap: () => _openCreationModal('note'),
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
      padding: const EdgeInsets.only(bottom: 12),
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
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11.5, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

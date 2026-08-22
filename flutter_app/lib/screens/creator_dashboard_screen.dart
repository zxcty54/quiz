import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  List<dynamic> _posts = [];
  List<dynamic> _mocks = [];
  bool _isLoading = true;

  int _totalViews = 0;
  int _totalUpvotes = 0;
  int _totalBookmarks = 0;
  int _totalShares = 0;
  int _totalMockAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadCompleteAnalytics();
  }

  Future<void> _loadCompleteAnalytics() async {
    try {
      final client = Supabase.instance.client;

      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      final postsRes = await client
          .from('community_posts')
          .select('*, post_comments(id)')
          .eq('creator_id', widget.creatorHandle)
          .order('views_count', ascending: false);

      final mocksRes = await client
          .from('creator_mocks')
          .select()
          .eq('creator_id', widget.creatorHandle)
          .order('attempts_count', ascending: false);

      int views = 0;
      int upvotes = 0;
      int bookmarks = 0;
      int shares = 0;

      for (var p in (postsRes as List)) {
        views += (p['views_count'] as int? ?? 0);
        upvotes += (p['upvotes'] as int? ?? 0);
        bookmarks += (p['bookmarks_count'] as int? ?? 0);
        shares += (p['shares_count'] as int? ?? 0);
      }

      int attempts = 0;
      for (var m in (mocksRes as List)) {
        attempts += (m['attempts_count'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _posts = postsRes;
          _mocks = mocksRes;
          _totalViews = views;
          _totalUpvotes = upvotes;
          _totalBookmarks = bookmarks;
          _totalShares = shares;
          _totalMockAttempts = attempts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Broadcast Modal (Daily Quiz, PDF Handouts, Strategy Alerts)
  void _openBroadcastModal(String type) {
    final textCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final opCtrl1 = TextEditingController();
    final opCtrl2 = TextEditingController();
    final opCtrl3 = TextEditingController();
    final opCtrl4 = TextEditingController();
    int correctIdx = 0;
    bool isPoll = type == 'quiz';

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
                    Text(
                      isPoll
                          ? '⚡ Publish Daily Rapid Quiz'
                          : (type == 'note' ? '📚 Share PDF Notes / Handout' : '📢 Broadcast Exam Alert'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  maxLines: isPoll ? 2 : 3,
                  decoration: InputDecoration(
                    hintText: isPoll ? 'Type Question text here...' : (type == 'note' ? 'Explain topic or notes headline...' : 'Type official alert or cut-off gossip...'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                if (isPoll) ...[
                  ...List.generate(4, (idx) {
                    final controllers = [opCtrl1, opCtrl2, opCtrl3, opCtrl4];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => correctIdx = idx),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: correctIdx == idx ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                              child: Text(String.fromCharCode(65 + idx), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers[idx],
                              decoration: InputDecoration(hintText: 'Option ${String.fromCharCode(65 + idx)}', isDense: true, border: const OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                if (type == 'note')
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Google Drive / Telegram PDF Link',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    onPressed: () async {
                      final text = textCtrl.text.trim();
                      if (text.isEmpty) return;

                      String content = text;
                      if (type == 'note' && linkCtrl.text.trim().isNotEmpty) {
                        content += '\n\n📄 Study Material: ${linkCtrl.text.trim()}';
                      }

                      Map<String, dynamic>? pollJson;
                      if (isPoll) {
                        pollJson = {
                          'options': [opCtrl1.text.trim(), opCtrl2.text.trim(), opCtrl3.text.trim(), opCtrl4.text.trim()],
                          'correct_idx': correctIdx,
                          'votes': [0, 0, 0, 0],
                          'exp': 'Prepared by @${widget.creatorHandle}',
                        };
                      }

                      Navigator.pop(ctx);
                      await Supabase.instance.client.from('community_posts').insert({
                        'creator_id': widget.creatorHandle,
                        'content': content,
                        'tag': isPoll ? 'Daily Quiz ⚡' : (type == 'note' ? 'Current Affairs 📰' : 'Exam Gossip 🔥'),
                        'poll_data': pollJson,
                        'views_count': 1,
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🚀 Broadcast published to community!'), backgroundColor: Color(0xFF16A34A)),
                        );
                        _loadCompleteAnalytics();
                      }
                    },
                    child: const Text('Publish to Community 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('Creator Studio & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            // 📊 1. Performance Overview Card
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
                      Text(_profile?['name'] ?? 'Mentor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('PRO CREATOR', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  Text('@${widget.creatorHandle} • ${_profile?['subject_specialty'] ?? 'Exam Mentor'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Followers', '${_profile?['followers_count'] ?? 0}', Icons.people_alt_outlined),
                      _buildMetricItem('Total Views', '$_totalViews', Icons.remove_red_eye_outlined),
                      _buildMetricItem('Test Attempts', '$_totalMockAttempts', Icons.bolt_rounded),
                      _buildMetricItem('Revision Saves', '$_totalBookmarks', Icons.bookmark_border_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🚀 2. Creator Studio Creation Tools
            const Text('Creator Studio Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'CBT Mock Test Builder ⚡',
              subtitle: 'Create multi-question timed CBT tests with AI Magic paste.',
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
              onTap: () => _openBroadcastModal('quiz'),
            ),

            _buildActionCard(
              title: 'Publish PDF Notes & Mindmaps 📚',
              subtitle: 'Link Google Drive or Telegram notes without server upload load.',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFF059669),
              onTap: () => _openBroadcastModal('note'),
            ),

            _buildActionCard(
              title: 'Broadcast Exam Alert / Strategy 📢',
              subtitle: 'Send official notifications, syllabus guides, or cut-off gossip.',
              icon: Icons.campaign_outlined,
              color: const Color(0xFFD97706),
              onTap: () => _openBroadcastModal('alert'),
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

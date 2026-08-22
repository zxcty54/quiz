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
  List<dynamic> _mocks = [];
  int _totalAttempts = 0;
  int _totalPosts = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreatorStudioData();
  }

  Future<void> _loadCreatorStudioData() async {
    try {
      final client = Supabase.instance.client;

      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      final mocksRes = await client
          .from('creator_mocks')
          .select()
          .eq('creator_id', widget.creatorHandle);

      final postsRes = await client
          .from('community_posts')
          .select('id')
          .eq('creator_id', widget.creatorHandle);

      int attempts = 0;
      for (var m in (mocksRes as List)) {
        attempts += (m['attempts_count'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _mocks = mocksRes;
          _totalAttempts = attempts;
          _totalPosts = (postsRes as List).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Quick Flash Alert / Study Note broadcast modal
  void _openBroadcastModal(String type) {
    final textCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    String tag = type == 'note' ? 'Current Affairs 📰' : 'Exam Gossip 🔥';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type == 'note' ? '📚 Share Handout / PDF Link' : '📢 Broadcast Exam Alert',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 10),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: type == 'note' ? 'Explain topic or notes headline...' : 'Type official alert / cut-off gossip...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (type == 'note')
              TextField(
                controller: linkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Google Drive / Telegram PDF Link (Optional)',
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
                  if (linkCtrl.text.trim().isNotEmpty) {
                    content += '\n\n📄 Study Material: ${linkCtrl.text.trim()}';
                  }

                  Navigator.pop(ctx);
                  await Supabase.instance.client.from('community_posts').insert({
                    'creator_id': widget.creatorHandle,
                    'content': content,
                    'tag': tag,
                    'views_count': 1,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🚀 Broadcast published to community!'), backgroundColor: Color(0xFF16A34A)),
                    );
                    _loadCreatorStudioData();
                  }
                },
                child: const Text('Publish Now 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
            tooltip: 'View Portfolio',
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
            // 📊 1. Live Performance Overview
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
                      _buildMetricItem('Test Attempts', '$_totalAttempts', Icons.bolt_rounded),
                      _buildMetricItem('Published', '${_mocks.length}', Icons.quiz_outlined),
                      _buildMetricItem('Discussions', '$_totalPosts', Icons.forum_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🚀 2. Creator Toolkit Actions
            const Text('Creator Studio Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Action 1: CBT Mock Builder (AI + Manual)
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
              ).then((_) => _loadCreatorStudioData()),
            ),

            // Action 2: Daily Rapid 1-Question Drill
            _buildActionCard(
              title: 'Interactive Daily Quiz Card 🎯',
              subtitle: 'Post instant 4-option poll with explanation directly to feed.',
              icon: Icons.poll_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => _openBroadcastModal('quiz'),
            ),

            // Action 3: Share Study Notes / PDF Drive Resolver
            _buildActionCard(
              title: 'Publish PDF Notes & Mindmaps 📚',
              subtitle: 'Link Google Drive or Telegram notes without server upload load.',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFF059669),
              onTap: () => _openBroadcastModal('note'),
            ),

            // Action 4: Broadcast Alert / Strategy
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorProfileScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<dynamic> _mocks = [];
  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _isCreator = false;
  bool _isFollowing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _fetchCreatorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCreatorData() async {
    try {
      final client = Supabase.instance.client;

      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      if (profileRes != null) {
        _isCreator = true;
        _profile = profileRes;

        final mocksRes = await client
            .from('creator_mocks')
            .select()
            .eq('creator_id', widget.creatorHandle)
            .order('created_at', ascending: false);

        _mocks = mocksRes;
      } else {
        // Fallback for regular Aspirant / Student
        _isCreator = false;
        _profile = {
          'name': widget.creatorHandle == 'user' ? 'Aspirant Candidate' : widget.creatorHandle,
          'handle_id': widget.creatorHandle,
          'subject_specialty': 'Competitive Exam Aspirant',
          'followers_count': 0,
        };
      }

      final postsRes = await client
          .from('community_posts')
          .select()
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      _posts = postsRes;
      _tabController = TabController(length: _isCreator ? 2 : 1, vsync: this);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleFollow() {
    HapticFeedback.selectionClick();
    if (_profile == null || !_isCreator) return;

    final currentFollowers = _profile!['followers_count'] ?? 0;
    final newFollowers = _isFollowing ? (currentFollowers - 1).clamp(0, 999999) : currentFollowers + 1;

    setState(() {
      _isFollowing = !_isFollowing;
      _profile!['followers_count'] = newFollowers;
    });

    Supabase.instance.client
        .from('creator_profiles')
        .update({'followers_count': newFollowers})
        .eq('handle_id', widget.creatorHandle)
        .then((_) {});
  }

  void _openTelegram(String? urlOrHandle) async {
    if (urlOrHandle == null || urlOrHandle.isEmpty) return;
    String cleanUrl = urlOrHandle.startsWith('http') ? urlOrHandle : 'https://t.me/$urlOrHandle';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startMockTest(Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions in this test!')));
      return;
    }

    List<Question> parsedQuestions = [];
    for (var item in rawList) {
      if (item is Map) {
        parsedQuestions.add(Question.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    if (parsedQuestions.isEmpty) return;

    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': (mock['attempts_count'] ?? 0) + 1})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Mock Test',
          questions: parsedQuestions,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isCreator ? (_profile!['name'] ?? 'Mentor Profile') : 'Candidate Profile',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0.5,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Card(
                color: cardBg,
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: _isCreator ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            child: Text(
                              (_profile!['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _profile!['name'] ?? '',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // 🏷️ Distinct Role Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _isCreator ? const Color(0xFF2563EB).withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _isCreator ? 'CREATOR' : 'ASPIRANT',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: _isCreator ? const Color(0xFF2563EB) : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '@${widget.creatorHandle}',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _profile!['subject_specialty'] ?? 'Exam Expert',
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Stats Row + Follow Button
                      if (_isCreator) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_profile!['followers_count'] ?? 0}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 4),
                                Text('Followers', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                const SizedBox(width: 14),
                                Text(
                                  '${_mocks.length}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 4),
                                Text('Mocks', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)) : const Color(0xFF2563EB),
                                foregroundColor: _isFollowing ? (isDark ? Colors.white : Colors.black87) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                elevation: 0,
                              ),
                              onPressed: _toggleFollow,
                              child: Text(_isFollowing ? 'Following' : 'Follow +', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                        if (_profile!['telegram_handle'] != null && _profile!['telegram_handle'].toString().isNotEmpty) ...[
                          const Divider(height: 20),
                          InkWell(
                            onTap: () => _openTelegram(_profile!['telegram_handle']),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.telegram, color: Color(0xFF0088CC), size: 20),
                                SizedBox(width: 6),
                                Text('Join Telegram Channel', style: TextStyle(color: Color(0xFF0088CC), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Icon(Icons.forum_outlined, size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Text('${_posts.length} Community Discussions / Doubts', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isCreator)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF2563EB),
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(text: 'Mock Tests (${_mocks.length})'),
                    Tab(text: 'Posts & Gossip (${_posts.length})'),
                  ],
                ),
                color: cardBg,
              ),
            ),
        ],
        body: _isCreator
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildMocksTab(cardBg),
                  _buildPostsTab(cardBg),
                ],
              )
            : _buildPostsTab(cardBg),
      ),
    );
  }

  Widget _buildMocksTab(Color cardBg) {
    if (_mocks.isEmpty) {
      return const Center(child: Text('No mock tests published yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _mocks.length,
      itemBuilder: (context, idx) {
        final m = _mocks[idx];
        final List qList = m['questions_json'] ?? [];
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(m['subject'] ?? 'General', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Text('${m['attempts_count'] ?? 0} Attempts', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m['title'] ?? 'Mock Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${qList.length} Questions • ${m['duration_mins'] ?? 10} Mins', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _startMockTest(m),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Start Mock Test ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(Color cardBg) {
    if (_posts.isEmpty) {
      return const Center(child: Text('No community posts shared yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (context, idx) {
        final p = _posts[idx];
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(p['tag'] ?? 'Gossip', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(p['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${p['upvotes'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 14),
                    Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${p['views_count'] ?? 120}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.color});
  final TabBar _tabBar;
  final Color color;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

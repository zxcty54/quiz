import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';
import 'creator_profile_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final bool isDarkMode;
  const CommunityFeedScreen({super.key, required this.isDarkMode});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;
  String _activeFilter = 'All';
  final Map<int, int> _userVoteState = {}; // post_id -> 1 (up), -1 (down), 0 (none)

  final List<String> _filters = ['All', 'Exam Gossip 🔥', 'Current Affairs 📰', 'Doubts ❓', 'Mock Tests ⚡'];

  @override
  void initState() {
    super.initState();
    _fetchFeedPosts();
  }

  Future<void> _fetchFeedPosts() async {
    setState(() => _isLoading = true);
    try {
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60)).toIso8601String();

      final res = await Supabase.instance.client
          .from('community_posts')
          .select('*, creator_profiles!inner(name, handle_id, subject_specialty, telegram_handle, followers_count, is_blocked), creator_mocks(*)')
          .eq('creator_profiles.is_blocked', false)
          .gte('created_at', sixtyDaysAgo)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleVote(int index, bool isUpvote) {
    HapticFeedback.lightImpact();
    final post = _posts[index];
    final int postId = post['id'];
    int currentVote = _userVoteState[postId] ?? 0;
    int upDelta = 0;
    int downDelta = 0;

    setState(() {
      if (isUpvote) {
        if (currentVote == 1) {
          _userVoteState[postId] = 0;
          upDelta = -1;
        } else {
          if (currentVote == -1) downDelta = -1;
          _userVoteState[postId] = 1;
          upDelta = 1;
        }
      } else {
        if (currentVote == -1) {
          _userVoteState[postId] = 0;
          downDelta = -1;
        } else {
          if (currentVote == 1) upDelta = -1;
          _userVoteState[postId] = -1;
          downDelta = 1;
        }
      }

      post['upvotes'] = (post['upvotes'] ?? 0) + upDelta;
      post['downvotes'] = (post['downvotes'] ?? 0) + downDelta;
    });

    Supabase.instance.client
        .from('community_posts')
        .update({
          'upvotes': post['upvotes'],
          'downvotes': post['downvotes'],
        })
        .eq('id', postId)
        .then((_) {});
  }

  void _launchAttachedMock(Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) return;

    List<Question> qList = [];
    for (var item in rawList) {
      if (item is Map) {
        qList.add(Question.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    if (qList.isEmpty) return;

    // Increment Mock attempt count
    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': (mock['attempts_count'] ?? 0) + 1})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Community Mock Drill',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  void _openCommentsSheet(int postId, String postTitle) {
    final commentCtrl = TextEditingController();
    int? replyingToCommentId;
    String? replyingToName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('💬 Discussion & Replies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: Supabase.instance.client
                        .from('post_comments')
                        .select()
                        .eq('post_id', postId)
                        .order('created_at', ascending: true),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const Center(child: Text('No comments yet. Start the discussion!'));
                      }
                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, cIdx) {
                          final c = comments[cIdx];
                          final bool isReply = c['parent_comment_id'] != null;

                          return Container(
                            margin: EdgeInsets.only(left: isReply ? 28.0 : 0.0, bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isReply ? (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9)) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isReply ? const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3)) : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c['user_name'] ?? 'Aspirant', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 6),
                                    if (c['is_creator'] == true)
                                      const Icon(Icons.verified, color: Colors.blue, size: 14),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          replyingToCommentId = c['id'];
                                          replyingToName = c['user_name'] ?? 'Aspirant';
                                        });
                                      },
                                      child: const Text('Reply', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c['content'] ?? '', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (replyingToCommentId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: Colors.blue.withOpacity(0.1),
                    child: Row(
                      children: [
                        Text('Replying to @$replyingToName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () => setSheetState(() {
                            replyingToCommentId = null;
                            replyingToName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        decoration: InputDecoration(
                          hintText: replyingToName != null ? 'Reply to @$replyingToName...' : 'Add a helpful reply...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                      onPressed: () async {
                        if (commentCtrl.text.trim().isEmpty) return;
                        await Supabase.instance.client.from('post_comments').insert({
                          'post_id': postId,
                          'user_handle': 'user',
                          'user_name': 'Aspirant',
                          'content': commentCtrl.text.trim(),
                          'parent_comment_id': replyingToCommentId,
                        });
                        commentCtrl.clear();
                        setSheetState(() {
                          replyingToCommentId = null;
                          replyingToName = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCreatePostModal() {
    final contentCtrl = TextEditingController();
    String selectedTag = 'Exam Gossip 🔥';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✍️ Create Post / Gossip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedTag,
                isExpanded: true,
                items: ['Exam Gossip 🔥', 'Current Affairs 📰', 'Doubts ❓', 'Strategy 💡']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedTag = val ?? selectedTag),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Share exam updates, cut-off discussion, notes or doubts...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (contentCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await Supabase.instance.client.from('community_posts').insert({
                      'creator_id': 'test',
                      'content': contentCtrl.text.trim(),
                      'tag': selectedTag,
                      'views_count': 1,
                    });
                    _fetchFeedPosts();
                  },
                  child: const Text('Post to Community 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final filteredList = _activeFilter == 'All'
        ? _posts
        : _posts.where((p) => p['tag'].toString().contains(_activeFilter.split(' ').first)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchFeedPosts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreatePostModal,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? const Center(child: Text('No posts yet in this section.\nBe the first to share!'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: filteredList.length,
                            itemBuilder: (context, idx) {
                              final item = filteredList[idx];
                              final creator = item['creator_profiles'] ?? {};
                              final attachedMock = item['creator_mocks'];
                              final postId = item['id'];
                              final userVote = _userVoteState[postId] ?? 0;
                              final int score = (item['upvotes'] ?? 0) - (item['downvotes'] ?? 0);
                              final String? imgUrl = item['image_url'];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: cardBg,
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 👤 Creator Header Bar with Tap to Profile
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreatorProfileScreen(
                                              creatorHandle: creator['handle_id'] ?? '',
                                              isDarkMode: isDark,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: const Color(0xFF2563EB),
                                              child: Text(
                                                (creator['name'] ?? 'U')[0].toUpperCase(),
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        creator['name'] ?? 'Aspirant',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '@${creator['handle_id'] ?? 'user'}',
                                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '${creator['followers_count'] ?? 0} Followers • ${creator['subject_specialty'] ?? 'Mentor'}',
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item['tag'] ?? 'General',
                                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        item['content'] ?? '',
                                        style: const TextStyle(fontSize: 14, height: 1.4),
                                      ),
                                      if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imgUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 180,
                                            loadingBuilder: (ctx, child, progress) => progress == null
                                                ? child
                                                : Container(height: 180, color: Colors.grey.withOpacity(0.1), child: const Center(child: CircularProgressIndicator())),
                                            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      if (attachedMock != null) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.quiz_rounded, color: Color(0xFF2563EB), size: 28),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(attachedMock['title'] ?? 'Mock Drill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                    Text('${(attachedMock['questions_json'] as List?)?.length ?? 0} Qs • ${attachedMock['duration_mins']} Mins', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2563EB),
                                                  foregroundColor: Colors.white,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                onPressed: () => _launchAttachedMock(attachedMock),
                                                child: const Text('Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_upward_rounded,
                                                    size: 18,
                                                    color: userVote == 1 ? const Color(0xFFFF4500) : Colors.grey,
                                                  ),
                                                  onPressed: () => _handleVote(idx, true),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                Text(
                                                  '$score',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: userVote == 1
                                                        ? const Color(0xFFFF4500)
                                                        : (userVote == -1 ? const Color(0xFF7193FF) : null),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_downward_rounded,
                                                    size: 18,
                                                    color: userVote == -1 ? const Color(0xFF7193FF) : Colors.grey,
                                                  ),
                                                  onPressed: () => _handleVote(idx, false),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          InkWell(
                                            onTap: () => _openCommentsSheet(postId, item['content'] ?? ''),
                                            borderRadius: BorderRadius.circular(16),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey),
                                                  SizedBox(width: 4),
                                                  Text('Reply', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.remove_red_eye_outlined, size: 15, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('${item['views_count'] ?? 120}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                            ],
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                                            onPressed: () {},
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  final Map<int, int> _userVoteState = {};

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

      // 🚨 Fix: Left join 'creator_profiles(...)' instead of '!inner' so Aspirants' posts also load!
      final res = await Supabase.instance.client
          .from('community_posts')
          .select('*, creator_profiles(name, handle_id, subject_specialty, telegram_handle, followers_count, is_blocked), creator_mocks(*)')
          .gte('created_at', sixtyDaysAgo)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Feed Fetch Error: $e");
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

  void _showReportDialog(int postId) {
    String selectedReason = 'Spam or Misleading';
    final reasons = [
      'Spam or Misleading',
      'Abusive or Harassing Content',
      'Inappropriate / Adult Content',
      'Copyright Infringement'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('🚨 Report Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this post?', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setDlgState(() => selectedReason = val ?? selectedReason),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await Supabase.instance.client.from('post_reports').insert({
                  'post_id': postId,
                  'reason': selectedReason,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you. Post reported and sent for review.')),
                  );
                }
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCommentsSheet(int postId, String postTitle) {
    final commentCtrl = TextEditingController();
    int? replyingToCommentId;
    String? replyingToName;
    int refreshKey = 0;
    bool isSubmitting = false;

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
                    key: ValueKey('comments_${postId}_$refreshKey'),
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
                        return const Center(child: Text('No comments yet. Be the first to reply!'));
                      }
                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, cIdx) {
                          final c = comments[cIdx];
                          final bool isReply = c['parent_comment_id'] != null;

                          return Container(
                            margin: EdgeInsets.only(left: isReply ? 24.0 : 0.0, bottom: 8),
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
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) async {
                          final text = commentCtrl.text.trim();
                          if (text.isEmpty || isSubmitting) return;
                          setSheetState(() => isSubmitting = true);
                          try {
                            await Supabase.instance.client.from('post_comments').insert({
                              'post_id': postId,
                              'user_handle': 'user',
                              'user_name': 'Aspirant',
                              'content': text,
                              'parent_comment_id': replyingToCommentId,
                            });
                            commentCtrl.clear();
                            setSheetState(() {
                              replyingToCommentId = null;
                              replyingToName = null;
                              refreshKey++;
                              isSubmitting = false;
                            });
                          } catch (e) {
                            debugPrint("Comment Error: $e");
                            setSheetState(() => isSubmitting = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: replyingToName != null ? 'Reply to @$replyingToName...' : 'Add a helpful reply...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final text = commentCtrl.text.trim();
                              if (text.isEmpty) return;
                              setSheetState(() => isSubmitting = true);
                              try {
                                await Supabase.instance.client.from('post_comments').insert({
                                  'post_id': postId,
                                  'user_handle': 'user',
                                  'user_name': 'Aspirant',
                                  'content': text,
                                  'parent_comment_id': replyingToCommentId,
                                });
                                commentCtrl.clear();
                                setSheetState(() {
                                  replyingToCommentId = null;
                                  replyingToName = null;
                                  refreshKey++;
                                  isSubmitting = false;
                                });
                              } catch (e) {
                                debugPrint("Comment Error: $e");
                                setSheetState(() => isSubmitting = false);
                              }
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
    String selectedTag = 'Doubts ❓';
    File? selectedImage;
    bool isUploading = false;
    final picker = ImagePicker();

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
                    const Text('✍️ Create Post / Ask Doubt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(
                    labelText: 'Category Tag',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: ['Doubts ❓', 'Exam Gossip 🔥', 'Current Affairs 📰', 'Strategy 💡']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedTag = val ?? selectedTag),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Share exam updates, question doubt, cut-off gossip...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                if (selectedImage != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          selectedImage!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Add Screenshot', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (pickedFile != null) {
                          setModalState(() => selectedImage = File(pickedFile.path));
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                      tooltip: 'Take Photo',
                      onPressed: () async {
                        final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                        if (pickedFile != null) {
                          setModalState(() => selectedImage = File(pickedFile.path));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'By posting, you agree to our Community Guidelines. Spam, harassment, or abusive content will result in an immediate account ban.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey, height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isUploading
                        ? null
                        : () async {
                            final text = contentCtrl.text.trim();
                            if (text.isEmpty && selectedImage == null) return;

                            setModalState(() => isUploading = true);
                            String? uploadedImageUrl;

                            try {
                              if (selectedImage != null) {
                                final bytes = await selectedImage!.readAsBytes();
                                final fileExt = selectedImage!.path.split('.').last;
                                final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                                await Supabase.instance.client.storage
                                    .from('post_images')
                                    .uploadBinary(
                                      fileName,
                                      bytes,
                                      fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
                                    );
                                uploadedImageUrl = Supabase.instance.client.storage.from('post_images').getPublicUrl(fileName);
                              }

                              await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': 'user',
                                'content': text,
                                'tag': selectedTag,
                                'image_url': uploadedImageUrl,
                                'views_count': 1,
                              });

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _fetchFeedPosts();
                              }
                            } catch (e) {
                              debugPrint("Post Upload Error: $e");
                              setModalState(() => isUploading = false);
                            }
                          },
                    child: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Post to Community 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;

    final filteredList = _activeFilter == 'All'
        ? _posts
        : _posts.where((p) => p['tag'].toString().contains(_activeFilter.split(' ').first)).toList();

    return Scaffold(
      backgroundColor: bgSurface,
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
          const Divider(height: 1, thickness: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? const Center(child: Text('No posts yet in this section.\nBe the first to share!'))
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                            itemBuilder: (context, idx) {
                              final item = filteredList[idx];
                              final creator = item['creator_profiles'] ?? {};
                              final attachedMock = item['creator_mocks'];
                              final postId = item['id'];
                              final userVote = _userVoteState[postId] ?? 0;
                              final int score = (item['upvotes'] ?? 0) - (item['downvotes'] ?? 0);
                              final String? imgUrl = item['image_url'];

                              return Container(
                                color: bgSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreatorProfileScreen(
                                                creatorHandle: (creator['handle_id'] ?? item['creator_id'] ?? 'user').toString(),
                                                isDarkMode: isDark,
                                              ),
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: (creator['name'] != null) ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                            child: Text(
                                              ((creator['name'] ?? 'U')[0]).toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CreatorProfileScreen(
                                                  creatorHandle: (creator['handle_id'] ?? item['creator_id'] ?? 'user').toString(),
                                                  isDarkMode: isDark,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      creator['name'] ?? 'Aspirant Candidate',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    if (creator['name'] != null)
                                                      const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '@${creator['handle_id'] ?? item['creator_id'] ?? 'user'}',
                                                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  (creator['name'] != null)
                                                      ? '${creator['followers_count'] ?? 0} Followers • ${creator['subject_specialty'] ?? 'Mentor'}'
                                                      : 'Aspirant • ${item['views_count'] ?? 120} views',
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item['tag'] ?? 'General',
                                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey[500]),
                                          onSelected: (val) {
                                            if (val == 'report') _showReportDialog(postId);
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'report',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.flag_outlined, color: Colors.redAccent, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Report Post', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    Text(
                                      item['content'] ?? '',
                                      style: const TextStyle(fontSize: 14.5, height: 1.45),
                                    ),

                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: 200,
                                          errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],

                                    if (attachedMock != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.quiz_rounded, color: Color(0xFF2563EB), size: 26),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(attachedMock['title'] ?? 'Mock Drill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                                  Text('${(attachedMock['questions_json'] as List?)?.length ?? 0} Questions • ${attachedMock['duration_mins']} Mins', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: () => _launchAttachedMock(attachedMock),
                                              child: const Text('Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.arrow_upward_rounded,
                                                  size: 16,
                                                  color: userVote == 1 ? const Color(0xFFFF4500) : Colors.grey[600],
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
                                                  size: 16,
                                                  color: userVote == -1 ? const Color(0xFF7193FF) : Colors.grey[600],
                                                ),
                                                onPressed: () => _handleVote(idx, false),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        InkWell(
                                          onTap: () => _openCommentsSheet(postId, item['content'] ?? ''),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey),
                                                SizedBox(width: 6),
                                                Text('Reply', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

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

import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../services/admin_telegram_alert.dart';
import '../utils/security_content_guard.dart';
import 'creator_profile_screen.dart';
import 'sectional_cbt_screen.dart';

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
  String _customUserName = 'Aspirant';
  String _currentLoggedInHandle = 'user';

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final Set<int> _likedPostIds = {};
  final Map<int, int> _userPollSelections = {};
  final Set<int> _savedPostIds = {};

  final List<String> _filters = [
    'All',
    'Daily Quiz ⚡',
    'Doubts ❓',
    'BPSC 70th 🎯',
    'BSSC CGL 📚',
    'Exam Gossip 🔥',
    'Current Affairs 📰',
    'Saved 📌'
  ];

  static const Color _ink = Color(0xFF322D66);
  static const Color _inkLight = Color(0xFFB3ACEE);
  static const Color _onInk = Color(0xFFF3F1FF);
  static const Color _paperBg = Color(0xFFFAF6ED);
  static const Color _paperCard = Color(0xFFFFFDF8);
  static const Color _paperBorder = Color(0xFFE7DFCC);
  static const Color _inkDarkBg = Color(0xFF16141F);
  static const Color _inkDarkCard = Color(0xFF201D2C);
  static const Color _inkDarkBorder = Color(0xFF322C46);

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _fetchFeedPosts();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final liked = prefs.getStringList('local_liked_post_ids') ?? [];
    final name = prefs.getString('custom_aspirant_name') ?? 'Aspirant';
    final handle = prefs.getString('logged_in_creator_handle') ?? 'user';

    if (mounted) {
      setState(() {
        _likedPostIds.addAll(liked.map((e) => int.tryParse(e) ?? 0));
        _customUserName = name;
        _currentLoggedInHandle = handle;
      });
    }

    // Existing 'user_saved_posts' table se account-level bookmarks fetch karein
    try {
      final savedRes = await Supabase.instance.client
          .from('user_saved_posts')
          .select('post_id')
          .eq('user_handle', _currentLoggedInHandle);

      if (savedRes != null && mounted) {
        setState(() {
          _savedPostIds.clear();
          for (var row in savedRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _savedPostIds.add(pid);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _editMyNameDialog() async {
    final nameCtrl = TextEditingController(text: _customUserName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? _inkDarkCard : _paperCard,
        title: Text(
          '👤 Edit Your Name',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDarkMode ? _onInk : _ink),
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter your name / alias',
            labelText: 'Display Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: _onInk),
            onPressed: () async {
              final val = nameCtrl.text.trim();
              if (val.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('custom_aspirant_name', val);
              setState(() => _customUserName = val);
              Navigator.pop(ctx);
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchFeedPosts() async {
    setState(() => _isLoading = true);
    try {
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60)).toIso8601String();

      final res = await Supabase.instance.client
          .from('community_posts')
          .select('*, creator_profiles(name, handle_id, subject_specialty, telegram_handle, followers_count, is_blocked), creator_mocks(*)')
          .gte('created_at', sixtyDaysAgo)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = res ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Feed Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sharePost(Map<String, dynamic> post) async {
    HapticFeedback.lightImpact();
    final postId = post['id'];
    final content = post['content'] ?? 'Check out this question on MockTester!';
    final author = post['author_name'] ?? 'Aspirant';

    final shareText = '''
📝 *MockTester Study Drill*
👤 *Shared by:* $author

$content

⚡ Solve this & practice 10,000+ BPSC/BSSC CBT Mock Questions:
📲 Download Free: https://play.google.com/store/apps/details?id=com.mocktester.online
''';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Post copied! Share on WhatsApp / Telegram.'),
        backgroundColor: _ink,
      ),
    );

    try {
      final currentShares = (post['shares_count'] ?? 0) + 1;
      setState(() => post['shares_count'] = currentShares);
      await Supabase.instance.client.from('community_posts').update({'shares_count': currentShares}).eq('id', postId);
    } catch (_) {}
  }

  // Existing 'user_saved_posts' table ke sath sync
  void _toggleBookmark(int postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    final bool isSaving = !_savedPostIds.contains(postId);

    setState(() {
      if (isSaving) {
        _savedPostIds.add(postId);
        post['bookmarks_count'] = (post['bookmarks_count'] ?? 0) + 1;
      } else {
        _savedPostIds.remove(postId);
        post['bookmarks_count'] = ((post['bookmarks_count'] ?? 1) - 1).clamp(0, 99999);
      }
    });

    try {
      if (isSaving) {
        await Supabase.instance.client.from('user_saved_posts').insert({
          'user_handle': _currentLoggedInHandle,
          'post_id': postId,
        });
      } else {
        await Supabase.instance.client
            .from('user_saved_posts')
            .delete()
            .eq('user_handle', _currentLoggedInHandle)
            .eq('post_id', postId);
      }

      await Supabase.instance.client
          .from('community_posts')
          .update({'bookmarks_count': post['bookmarks_count']})
          .eq('id', postId);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaving ? '📌 Saved to Revision Notebook!' : 'Removed from Saved!'),
          duration: const Duration(seconds: 1),
          backgroundColor: _ink,
        ),
      );
    }
  }

  void _handleLike(int index) async {
    HapticFeedback.lightImpact();
    final post = _posts[index];
    final int postId = post['id'];
    final bool isCurrentlyLiked = _likedPostIds.contains(postId);

    setState(() {
      if (isCurrentlyLiked) {
        _likedPostIds.remove(postId);
        post['upvotes'] = ((post['upvotes'] ?? 1) - 1).clamp(0, 999999);
      } else {
        _likedPostIds.add(postId);
        post['upvotes'] = (post['upvotes'] ?? 0) + 1;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('local_liked_post_ids', _likedPostIds.map((e) => e.toString()).toList());

    Supabase.instance.client
        .from('community_posts')
        .update({'upvotes': post['upvotes']})
        .eq('id', postId)
        .then((_) {});
  }

  void _submitPollVote(int postId, int optionIdx, Map<String, dynamic> pollData) {
    if (_userPollSelections.containsKey(postId)) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _userPollSelections[postId] = optionIdx;
      List votes = pollData['votes'] ?? [0, 0, 0, 0];
      if (optionIdx < votes.length) {
        votes[optionIdx] = (votes[optionIdx] as int) + 1;
      }
      pollData['votes'] = votes;
    });

    Supabase.instance.client
        .from('community_posts')
        .update({'poll_data': pollData})
        .eq('id', postId)
        .then((_) {});
  }

  // Real Mock Launch: Attempts count section_cbt_screen me submit hone par update hota hai
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Community Mock Drill',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
          mockId: mock['id'],
        ),
      ),
    );
  }

  void _openPostAnalyticsSheet(Map<String, dynamic> post) {
    final int views = post['views_count'] ?? 120;
    final int upvotes = post['upvotes'] ?? 0;
    final int bookmarks = post['bookmarks_count'] ?? 0;
    final int shares = post['shares_count'] ?? 0;
    final attachedMock = post['creator_mocks'];
    final int attempts = attachedMock?['attempts_count'] ?? 0;

    final int totalInteractions = upvotes + bookmarks + shares + attempts;
    final double engagementScore = views > 0 ? ((totalInteractions / views) * 100) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? _inkDarkCard : _paperCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.insights_rounded, color: _ink, size: 20),
                    SizedBox(width: 8),
                    Text('Post Performance Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text('Live interaction breakdown for this post:', style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            const SizedBox(height: 14),

            Row(
              children: [
                _buildMiniMetricCard('Views / Seen 👁️', '$views', 'Total Impressions', Colors.blue),
                const SizedBox(width: 8),
                _buildMiniMetricCard('Saves 📌', '$bookmarks', 'Added to Notebooks', Colors.amber.shade800),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniMetricCard('Applauds / Likes 👍', '$upvotes', 'Positive Aspirant Votes', Colors.green),
                const SizedBox(width: 8),
                _buildMiniMetricCard('Shares 🔗', '$shares', 'Shared External Link', Colors.indigo),
              ],
            ),

            if (attachedMock != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF1E1A33) : const Color(0xFFF4F2FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _ink.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mock Drill Activity: $attempts Test Submissions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text('Completed evaluation sheets synced', style: TextStyle(color: Colors.grey[500], fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Engagement Quality Score:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('${engagementScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetricCard(String label, String value, String desc, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? _inkDarkBg : _paperBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDarkMode ? _inkDarkBorder : _paperBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(desc, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // Existing 'post_comments' table ke sath nested reply system
  void _openCommentsSheet(int postId, String postAuthorId) {
    final commentCtrl = TextEditingController();
    int? replyingToCommentId;
    String? replyingToName;
    int refreshKey = 0;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? _inkDarkCard : _paperCard,
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
                    Text('💬 Discussion & Solution Replies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDarkMode ? _onInk : _ink)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Divider(color: widget.isDarkMode ? _inkDarkBorder : _paperBorder),
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
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const Center(child: Text('No replies yet. Be the first to solve!'));
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
                              color: isReply ? (widget.isDarkMode ? const Color(0xFF262140) : const Color(0xFFF4F2FC)) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isReply ? const Border(left: BorderSide(color: _ink, width: 3)) : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c['user_name'] ?? 'Aspirant', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 6),
                                    if (c['is_creator'] == true)
                                      const Icon(Icons.verified, color: _ink, size: 14),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          replyingToCommentId = c['id'];
                                          replyingToName = c['user_name'] ?? 'Aspirant';
                                        });
                                      },
                                      child: const Text('Reply', style: TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildRichTextContent(c['comment_text'] ?? c['content'] ?? '', fontSize: 13),
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
                    color: _ink.withOpacity(0.1),
                    child: Row(
                      children: [
                        Text('Replying to @$replyingToName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _ink)),
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
                Divider(color: widget.isDarkMode ? _inkDarkBorder : _paperBorder),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: replyingToName != null ? 'Reply to @$replyingToName...' : 'Add solution or reply as $_customUserName...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: _ink),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final text = commentCtrl.text.trim();
                              if (text.isEmpty) return;

                              final validationError = SecurityContentGuard.validateContent(text);
                              if (validationError != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              try {
                                await Supabase.instance.client.from('post_comments').insert({
                                  'post_id': postId,
                                  'user_handle': _currentLoggedInHandle,
                                  'user_name': _customUserName,
                                  'comment_text': text,
                                  'parent_comment_id': replyingToCommentId,
                                  'is_creator': _currentLoggedInHandle != 'user',
                                });

                                commentCtrl.clear();
                                setSheetState(() {
                                  replyingToCommentId = null;
                                  replyingToName = null;
                                  refreshKey++;
                                  isSubmitting = false;
                                });
                              } catch (e) {
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
      backgroundColor: widget.isDarkMode ? _inkDarkCard : _paperCard,
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
                    Text('✍️ Post as $_customUserName', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: widget.isDarkMode ? _onInk : _ink)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()),
                  items: _filters.where((f) => f != 'All' && f != 'Saved 📌').map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setModalState(() => selectedTag = val ?? selectedTag),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Share exam updates, question screenshot, or doubt...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedImage != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(selectedImage!, width: double.infinity, height: 150, fit: BoxFit.cover),
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
                      label: const Text('Add Screenshot'),
                      onPressed: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                        if (picked != null) setModalState(() => selectedImage = File(picked.path));
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: _ink),
                      onPressed: () async {
                        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
                        if (picked != null) setModalState(() => selectedImage = File(picked.path));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: _onInk),
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
                                    .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true));
                                uploadedImageUrl = Supabase.instance.client.storage.from('post_images').getPublicUrl(fileName);
                              }

                              final insertedPost = await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': _currentLoggedInHandle,
                                'author_name': _customUserName,
                                'content': text,
                                'tag': selectedTag,
                                'image_url': uploadedImageUrl,
                                'views_count': 1,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

                              AdminTelegramAlert.notifyNewPost(
                                postId: insertedPost['id'] ?? 0,
                                authorName: _customUserName,
                                authorHandle: 'candidate',
                                tag: selectedTag,
                                content: text,
                                imageUrl: uploadedImageUrl,
                              );

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _fetchFeedPosts();
                              }
                            } catch (e) {
                              debugPrint("Upload Error: $e");
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

  Widget _buildRichTextContent(String text, {double fontSize = 14.5}) {
    final RegExp exp = RegExp(r'((https?:\/\/|www\.)[^\s]+)|(#[a-zA-Z0-9_]+)|(@[a-zA-Z0-9_]+)');
    final matches = exp.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.45,
          color: widget.isDarkMode ? _onInk : const Color(0xFF1E293B),
        ),
      );
    }

    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final matchText = match.group(0)!;

      if (matchText.startsWith('http') || matchText.startsWith('www.')) {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: _ink, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                    Uri.parse(matchText.startsWith('http') ? matchText : 'https://$matchText'),
                    mode: LaunchMode.externalApplication,
                  ),
          ),
        );
      } else if (matchText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => setState(() => _activeFilter = matchText),
          ),
        );
      } else if (matchText.startsWith('@')) {
        final handle = matchText.substring(1);
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatorProfileScreen(creatorHandle: handle, isDarkMode: widget.isDarkMode),
                  ),
                );
              },
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          height: 1.45,
          color: widget.isDarkMode ? _onInk : const Color(0xFF0F172A),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildDocumentLinkResolver(String content, bool isDark) {
    final match = RegExp(r'https?:\/\/[^\s]+').firstMatch(content);
    if (match == null) return const SizedBox.shrink();

    final link = match.group(0)!;
    String label = 'Open Study Material / Handout';
    IconData docIcon = Icons.link_rounded;

    if (link.contains('drive.google.com')) {
      label = 'Google Drive PDF Notes';
      docIcon = Icons.picture_as_pdf_rounded;
    } else if (link.contains('t.me')) {
      label = 'Telegram Channel Asset / File';
      docIcon = Icons.telegram;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? _inkDarkBg : _paperBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ink.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(docIcon, color: _ink, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: _onInk,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
            child: const Text('Open ↗', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractivePollCard(int postId, Map<String, dynamic> pollData, bool isDark) {
    final List options = pollData['options'] ?? [];
    final int correctIdx = pollData['correct_idx'] ?? 0;
    final List votes = pollData['votes'] ?? List.filled(options.length, 0);
    final String explanation = pollData['exp'] ?? '';
    final bool hasVoted = _userPollSelections.containsKey(postId);
    final int? selectedIdx = _userPollSelections[postId];

    int totalVotes = 0;
    for (var v in votes) {
      totalVotes += (v is int) ? v : (int.tryParse(v.toString()) ?? 0);
    }
    if (totalVotes == 0) totalVotes = 1;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _inkDarkBg : _paperBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ink.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text('Live Daily Quiz • Tap to Solve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(options.length, (idx) {
            final optText = options[idx];
            final int optVotes = (idx < votes.length) ? (votes[idx] as int) : 0;
            final double percent = (optVotes / totalVotes) * 100;
            final bool isSelected = selectedIdx == idx;
            final bool isCorrect = correctIdx == idx;

            Color tileColor = isDark ? _inkDarkCard : _paperCard;
            if (hasVoted) {
              if (isCorrect) {
                tileColor = const Color(0xFF16A34A).withOpacity(0.2);
              } else if (isSelected) {
                tileColor = Colors.redAccent.withOpacity(0.2);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _submitPollVote(postId, idx, pollData),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(8),
                    border: hasVoted && isCorrect ? Border.all(color: const Color(0xFF16A34A), width: 1.5) : Border.all(color: isDark ? _inkDarkBorder : _paperBorder),
                  ),
                  child: Row(
                    children: [
                      Text(String.fromCharCode(65 + idx), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(optText, style: const TextStyle(fontSize: 13.5))),
                      if (hasVoted)
                        Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (hasVoted && explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _ink.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: _ink),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Explanation: $explanation', style: const TextStyle(fontSize: 12, height: 1.35))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? _inkDarkBg : _paperBg;
    final cardSurface = isDark ? _inkDarkCard : _paperCard;
    final cardBorder = isDark ? _inkDarkBorder : _paperBorder;
    final dividerColor = isDark ? _inkDarkBorder : _paperBorder;

    final filteredList = _activeFilter == 'All'
        ? _posts
        : (_activeFilter == 'Saved 📌'
            ? _posts.where((p) => _savedPostIds.contains(p['id'])).toList()
            : _posts.where((p) {
                final tag = (p['tag'] ?? '').toString().toLowerCase();
                final target = _activeFilter.split(' ').first.toLowerCase();
                final mockData = p['creator_mocks'] as Map?;
                final mockTitle = (mockData?['title'] ?? '').toString().toLowerCase();
                final mockSubject = (mockData?['subject'] ?? '').toString().toLowerCase();
                return tag.contains(target) || mockTitle.contains(target) || mockSubject.contains(target);
              }).toList());

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Community Feed',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? _onInk : _ink),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.badge_outlined, color: isDark ? _inkLight : _ink),
            tooltip: 'Change My Display Name',
            onPressed: _editMyNameDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? _inkLight : _ink),
            onPressed: _fetchFeedPosts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _ink,
        foregroundColor: _onInk,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Post / Doubt', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    selectedColor: _ink,
                    backgroundColor: isDark ? _inkDarkCard : _paperCard,
                    labelStyle: TextStyle(color: isSelected ? _onInk : (isDark ? _inkLight : const Color(0xFF5C5540))),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                      side: BorderSide(color: isSelected ? _ink : cardBorder),
                    ),
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? const Center(child: Text('No posts yet in this section.\nBe the first to share!'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = filteredList[idx];
                              final creator = item['creator_profiles'] ?? {};
                              final attachedMock = item['creator_mocks'];
                              final postId = item['id'];
                              final bool isLiked = _likedPostIds.contains(postId);
                              final int likesCount = item['upvotes'] ?? 0;
                              final String? imgUrl = item['image_url'];
                              final Map<String, dynamic>? pollData = item['poll_data'];
                              final bool isSaved = _savedPostIds.contains(postId);
                              final int commentsCount = item['comments_count'] ?? 0;

                              final bool isVerifiedCreator = creator['name'] != null && (item['creator_id'] != 'user');
                              final String authorHandle = (creator['handle_id'] ?? item['creator_id'] ?? 'user').toString();
                              final String authorDisplayName = isVerifiedCreator
                                  ? (creator['name'] ?? 'Verified Mentor')
                                  : (item['author_name'] ?? 'Aspirant');

                              return Container(
                                decoration: BoxDecoration(
                                  color: cardSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cardBorder, width: 1),
                                  boxShadow: isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: _ink.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreatorProfileScreen(
                                              creatorHandle: authorHandle,
                                              isDarkMode: isDark,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: isVerifiedCreator ? _ink : (isDark ? _inkDarkBorder : const Color(0xFFBFB8A0)),
                                            child: Text(
                                              isVerifiedCreator ? ((creator['name'] ?? 'M')[0]).toUpperCase() : 'A',
                                              style: TextStyle(color: _onInk, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      authorDisplayName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    if (isVerifiedCreator)
                                                      const Icon(Icons.verified, size: 14, color: _ink),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '@$authorHandle',
                                                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  isVerifiedCreator
                                                      ? '🎓 ${creator['subject_specialty'] ?? 'Exam Mentor'} • ${creator['followers_count'] ?? 0} Followers'
                                                      : 'Aspirant • Active Community Member',
                                                  style: TextStyle(
                                                    color: isVerifiedCreator ? _ink : Colors.grey[600],
                                                    fontSize: 10.5,
                                                    fontWeight: isVerifiedCreator ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _ink.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(item['tag'] ?? 'General', style: const TextStyle(color: _ink, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildRichTextContent(item['content'] ?? ''),

                                    _buildDocumentLinkResolver(item['content'] ?? '', isDark),

                                    if (pollData != null)
                                      _buildInteractivePollCard(postId, pollData, isDark),

                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxHeight: 320),
                                          child: Image.network(
                                            imgUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ],

                                    if (attachedMock != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1A33) : const Color(0xFFF4F2FC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: isDark ? const Color(0xFF38315E) : const Color(0xFFDCD7F5)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.quiz_rounded, color: _ink, size: 26),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(attachedMock['title'] ?? 'Mock Drill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                                  Text(
                                                    '${(attachedMock['questions_json'] as List?)?.length ?? 0} Qs • ${attachedMock['duration_mins']} Mins • ⚡ ${attachedMock['attempts_count'] ?? 0} Attempts',
                                                    style: TextStyle(color: isDark ? _inkLight : const Color(0xFF5C5540), fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _ink,
                                                foregroundColor: _onInk,
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
                                        // 👍 Like Button (Single Action, Positive Only)
                                        InkWell(
                                          onTap: () => _handleLike(idx),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? _inkDarkBg : _paperBg,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isLiked ? _ink : (isDark ? _inkDarkBorder : _paperBorder)),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                                                  size: 15,
                                                  color: isLiked ? _ink : Colors.grey[600],
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '$likesCount',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: isLiked ? _ink : (isDark ? _onInk : const Color(0xFF1E293B)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // 💬 Reply / Comments Button
                                        InkWell(
                                          onTap: () => _openCommentsSheet(postId, item['creator_id'] ?? 'user'),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? _inkDarkBg : _paperBg,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isDark ? _inkDarkBorder : _paperBorder),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$commentsCount',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? _onInk : _ink,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // 📊 Stats Action Sheet
                                        InkWell(
                                          onTap: () => _openPostAnalyticsSheet(item),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: isDark ? _inkDarkBg : _paperBg,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: _ink.withOpacity(0.2)),
                                            ),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.insights_rounded, size: 13, color: _ink),
                                                SizedBox(width: 4),
                                                Text('Stats', style: TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        Row(
                                          children: [
                                            const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text('${item['views_count'] ?? 120}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(width: 8),

                                        // 📌 Bookmark (user_saved_posts se linked)
                                        InkWell(
                                          onTap: () => _toggleBookmark(postId, item),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Row(
                                            children: [
                                              Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 16, color: isSaved ? _ink : Colors.grey),
                                              const SizedBox(width: 2),
                                              Text('${item['bookmarks_count'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),

                                        // 🔗 Share Link
                                        InkWell(
                                          onTap: () => _sharePost(item),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                                                const SizedBox(width: 3),
                                                Text('${item['shares_count'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
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

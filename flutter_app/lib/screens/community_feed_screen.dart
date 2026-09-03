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
    'Mock Tests ⚡',
    'Study Material 📚',
    'Daily Quiz ⚡',
    'Doubts ❓',
    'Announcement 📢',
    'Saved 📌'
  ];

  // AAPKA ORIGINAL UNIFIED COLOR PALETTE
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('custom_aspirant_name') ?? 'Aspirant';
    final handle = prefs.getString('logged_in_creator_handle') ?? 'user';

    if (mounted) {
      setState(() {
        _customUserName = name;
        _currentLoggedInHandle = handle;
      });
    }

    // 1. Fetch Saved Posts
    try {
      final savedRes = await Supabase.instance.client
          .from('user_saved_posts')
          .select('post_id')
          .eq('user_handle', _currentLoggedInHandle);

      if (mounted) {
        setState(() {
          _savedPostIds.clear();
          for (var row in savedRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _savedPostIds.add(pid);
          }
        });
      }
    } catch (_) {}

    // 2. Fetch User Likes
    try {
      final likesRes = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('user_handle', _currentLoggedInHandle);

      if (mounted) {
        setState(() {
          _likedPostIds.clear();
          for (var row in likesRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _likedPostIds.add(pid);
          }
        });
      }
    } catch (_) {}

    // 3. Fetch User Poll Votes
    try {
      final votesRes = await Supabase.instance.client
          .from('poll_votes')
          .select('post_id, option_index')
          .eq('user_handle', _currentLoggedInHandle);

      if (mounted) {
        setState(() {
          _userPollSelections.clear();
          for (var row in votesRes) {
            final pid = int.tryParse(row['post_id'].toString());
            final opt = int.tryParse(row['option_index'].toString());
            if (pid != null && opt != null) {
              _userPollSelections[pid] = opt;
            }
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

              if (_currentLoggedInHandle != 'user') {
                try {
                  await Supabase.instance.client
                      .from('creator_profiles')
                      .update({'name': val})
                      .eq('handle_id', _currentLoggedInHandle);
                } catch (_) {}
              }

              if (mounted) setState(() => _customUserName = val);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
  }

  // 🛡️ ONLY FETCH APPROVED POSTS
  Future<void> _fetchFeedPosts() async {
    setState(() => _isLoading = true);
    try {
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60)).toIso8601String();

      final res = await Supabase.instance.client
          .from('community_posts')
          .select('*, creator_profiles(name, handle_id, subject_specialty, followers_count, is_blocked), creator_mocks(*)')
          .eq('is_approved', true) // Only live moderated posts
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

  void _navigateToCreator(String handle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorProfileScreen(
          creatorHandle: handle,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
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

⚡ Solve this & practice 10,000+ CBT Mock Questions:
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

      await Supabase.instance.client.rpc('increment_post_metric', params: {
        'post_id_param': postId,
        'metric_field': 'shares_count',
        'amount': 1,
      });
    } catch (_) {}
  }

  void _toggleBookmark(int postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    final bool isSaving = !_savedPostIds.contains(postId);
    final int delta = isSaving ? 1 : -1;

    setState(() {
      if (isSaving) {
        _savedPostIds.add(postId);
      } else {
        _savedPostIds.remove(postId);
      }
      post['bookmarks_count'] = ((post['bookmarks_count'] ?? 0) + delta).clamp(0, 999999);
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

      await Supabase.instance.client.rpc('increment_post_metric', params: {
        'post_id_param': postId,
        'metric_field': 'bookmarks_count',
        'amount': delta,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSaving ? '📌 Saved to Notebook!' : 'Removed from Saved!'),
            duration: const Duration(seconds: 1),
            backgroundColor: _ink,
          ),
        );
      }
    } catch (e) {
      debugPrint("Bookmark Error: $e");
      if (mounted) {
        setState(() {
          if (isSaving) {
            _savedPostIds.remove(postId);
          } else {
            _savedPostIds.add(postId);
          }
          post['bookmarks_count'] = ((post['bookmarks_count'] ?? 0) - delta).clamp(0, 999999);
        });
      }
    }
  }

  void _handleLike(int index) async {
    HapticFeedback.lightImpact();
    final post = _posts[index];
    final int postId = post['id'];
    final bool isCurrentlyLiked = _likedPostIds.contains(postId);
    final int delta = isCurrentlyLiked ? -1 : 1;

    setState(() {
      if (isCurrentlyLiked) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
      post['upvotes'] = ((post['upvotes'] ?? 0) + delta).clamp(0, 999999);
    });

    try {
      final res = await Supabase.instance.client.rpc('toggle_post_like', params: {
        'target_post_id': postId,
        'aspirant_handle': _currentLoggedInHandle,
      });

      final bool likedConfirmed = res == true;
      if (mounted && likedConfirmed != !isCurrentlyLiked) {
        setState(() {
          if (likedConfirmed) {
            _likedPostIds.add(postId);
          } else {
            _likedPostIds.remove(postId);
          }
        });
      }
    } catch (e) {
      debugPrint("Like RPC Error: $e");
      if (mounted) {
        setState(() {
          if (isCurrentlyLiked) {
            _likedPostIds.add(postId);
          } else {
            _likedPostIds.remove(postId);
          }
          post['upvotes'] = ((post['upvotes'] ?? 0) - delta).clamp(0, 999999);
        });
      }
    }
  }

  void _submitPollVote(int postId, int optionIdx, Map<String, dynamic> pollData) async {
    if (_userPollSelections.containsKey(postId)) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _userPollSelections[postId] = optionIdx;
      List votes = List.from(pollData['votes'] ?? [0, 0, 0, 0]);
      if (optionIdx < votes.length) {
        votes[optionIdx] = (votes[optionIdx] as int) + 1;
      }
      pollData['votes'] = votes;
    });

    try {
      final res = await Supabase.instance.client.rpc('submit_poll_vote_safe', params: {
        'target_post_id': postId,
        'aspirant_handle': _currentLoggedInHandle,
        'opt_idx': optionIdx,
      });

      if (res != true && mounted) {
        setState(() {
          _userPollSelections.remove(postId);
          List votes = List.from(pollData['votes'] ?? [0, 0, 0, 0]);
          if (optionIdx < votes.length) {
            votes[optionIdx] = ((votes[optionIdx] as int) - 1).clamp(0, 999999);
          }
          pollData['votes'] = votes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already voted in this quiz!')),
        );
      }
    } catch (e) {
      debugPrint("Poll RPC Error: $e");
      if (mounted) {
        setState(() {
          _userPollSelections.remove(postId);
          List votes = List.from(pollData['votes'] ?? [0, 0, 0, 0]);
          if (optionIdx < votes.length) {
            votes[optionIdx] = ((votes[optionIdx] as int) - 1).clamp(0, 999999);
          }
          pollData['votes'] = votes;
        });
      }
    }
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

    // Increment attempts count
    final updatedAttempts = (mock['attempts_count'] ?? 0) + 1;
    setState(() => mock['attempts_count'] = updatedAttempts);
    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': updatedAttempts})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Free Open Mock Drill',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
          mockId: mock['id'],
        ),
      ),
    );
  }

  void _openCommentsSheet(int postId, Map<String, dynamic> post) {
    final commentCtrl = TextEditingController();
    int? replyingToCommentId;
    String? replyingToName;
    bool isSubmitting = false;
    List<Map<String, dynamic>> comments = [];
    bool isLoadingComments = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? _inkDarkCard : _paperCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (isLoadingComments) {
            Supabase.instance.client
                .from('post_comments')
                .select()
                .eq('post_id', postId)
                .order('created_at', ascending: true)
                .then((data) {
              if (ctx.mounted) {
                setSheetState(() {
                  comments = List<Map<String, dynamic>>.from(data);
                  isLoadingComments = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) setSheetState(() => isLoadingComments = false);
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '💬 Discussion & Replies',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDarkMode ? _onInk : _ink),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  Divider(color: widget.isDarkMode ? _inkDarkBorder : _paperBorder),
                  Expanded(
                    child: isLoadingComments
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : comments.isEmpty
                            ? const Center(child: Text('No replies yet. Be the first to solve!'))
                            : ListView.builder(
                                itemCount: comments.length,
                                itemBuilder: (context, cIdx) {
                                  final c = comments[cIdx];
                                  final bool isReply = c['parent_comment_id'] != null;

                                  return Container(
                                    margin: EdgeInsets.only(left: isReply ? 24.0 : 0.0, bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isReply
                                          ? (widget.isDarkMode ? const Color(0xFF262140) : const Color(0xFFF4F2FC))
                                          : Colors.transparent,
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
                              ),
                  ),
                  if (replyingToCommentId != null)
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
                  Divider(color: widget.isDarkMode ? _inkDarkBorder : _paperBorder),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: replyingToName != null ? 'Reply to @$replyingToName...' : 'Add solution as $_customUserName...',
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
                                  final inserted = await Supabase.instance.client.from('post_comments').insert({
                                    'post_id': postId,
                                    'user_handle': _currentLoggedInHandle,
                                    'user_name': _customUserName,
                                    'comment_text': text,
                                    'parent_comment_id': replyingToCommentId,
                                    'is_creator': _currentLoggedInHandle != 'user',
                                  }).select().single();

                                  commentCtrl.clear();
                                  setSheetState(() {
                                    comments.add(inserted);
                                    replyingToCommentId = null;
                                    replyingToName = null;
                                    isSubmitting = false;
                                  });

                                  setState(() {
                                    post['comments_count'] = (post['comments_count'] ?? 0) + 1;
                                  });
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to post reply. Please try again.')),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 📝 CREATE POST WITH TELEGRAM APPROVAL WORKFLOW
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
                    Text('✍️ Ask Doubt / Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: widget.isDarkMode ? _onInk : _ink)),
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
                    hintText: 'Share exam questions, doubts or important study insights...',
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
                const SizedBox(height: 14),
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

                              // 🛡️ Set is_approved: false for moderation
                              final insertedPost = await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': _currentLoggedInHandle,
                                'author_name': _customUserName,
                                'content': text,
                                'tag': selectedTag,
                                'image_url': uploadedImageUrl,
                                'is_approved': false,
                                'views_count': 1,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

                              // 📡 Send Telegram interactive card with Approve & Reject buttons
                              AdminTelegramAlert.sendForInteractiveApproval(
                                postId: insertedPost['id'] ?? 0,
                                authorName: _customUserName,
                                authorHandle: _currentLoggedInHandle,
                                tag: selectedTag,
                                content: text,
                                imageUrl: uploadedImageUrl,
                              ).catchError((_) => false);

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _fetchFeedPosts();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⏳ Post submitted for review! It will appear once approved.'),
                                    backgroundColor: _ink,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint("Upload Error: $e");
                              setModalState(() => isUploading = false);
                            }
                          },
                    child: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Publish Post 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final cleaned = matchText.replaceAll('#', '').toLowerCase();
                final found = _filters.firstWhere(
                  (f) => f.toLowerCase().contains(cleaned),
                  orElse: () => 'All',
                );
                setState(() => _activeFilter = found);
              },
          ),
        );
      } else if (matchText.startsWith('@')) {
        final handle = matchText.substring(1);
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToCreator(handle),
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

  // 🎯 RESTORED: PREMIUM FREE CBT MOCK DISCOVERY CARD (WITH FUNNEL RIBBON)
  Widget _buildMockDiscoveryCard(Map<String, dynamic> mock, String authorName, String handle, bool isDark) {
    final int totalQs = (mock['questions_json'] as List?)?.length ?? 0;
    final int duration = mock['duration_mins'] ?? 15;
    final int attempts = mock['attempts_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A33) : const Color(0xFFF4F2FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ink.withOpacity(0.22), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 3),
                          Text(
                            'FREE CBT MOCK',
                            style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$attempts Aspirants Attempted',
                      style: TextStyle(fontSize: 11, color: isDark ? _inkLight : Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mock['title'] ?? 'Comprehensive Mock Drill',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalQs Concept Questions • ⏱ $duration Mins • Detailed Analytics',
                  style: TextStyle(fontSize: 11.5, color: isDark ? _inkLight : const Color(0xFF5C5540)),
                ),
                const SizedBox(height: 12),

                // Main Launch Button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: _onInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => _launchAttachedMock(mock),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_fill_rounded, size: 17),
                        SizedBox(width: 6),
                        Text('Attempt Free Mock Now 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔗 Direct Classroom Funnel Ribbon
          InkWell(
            onTap: () => _navigateToCreator(handle),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _ink.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: _ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Curated by $authorName • Explore Classroom Batches →',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📚 Dedicated Study Material Card
  Widget _buildStudyMaterialCard(String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF059669), size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Class Handout / Study Material Attached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Tap download link inside the post to access full PDF', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ink.withOpacity(0.18)),
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
                tileColor = const Color(0xFF16A34A).withOpacity(0.18);
              } else if (isSelected) {
                tileColor = Colors.redAccent.withOpacity(0.18);
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
                    border: hasVoted && isCorrect
                        ? Border.all(color: const Color(0xFF16A34A), width: 1.5)
                        : Border.all(color: isDark ? _inkDarkBorder : _paperBorder),
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
    final dividerColor = isDark ? _inkDarkBorder : _paperBorder;
    final cardSurface = isDark ? _inkDarkCard : _paperCard;

    final filteredList = _posts.where((p) {
      bool matchesCategory = true;
      if (_activeFilter == 'Saved 📌') {
        matchesCategory = _savedPostIds.contains(p['id']);
      } else if (_activeFilter != 'All') {
        final tag = (p['tag'] ?? '').toString().toLowerCase();
        final target = _activeFilter.split(' ').first.toLowerCase();
        final mockData = p['creator_mocks'] as Map?;
        final mockTitle = (mockData?['title'] ?? '').toString().toLowerCase();
        final mockSubject = (mockData?['subject'] ?? '').toString().toLowerCase();
        matchesCategory = tag.contains(target) || mockTitle.contains(target) || mockSubject.contains(target);
      }

      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;

      final q = _searchQuery.toLowerCase();
      final content = (p['content'] ?? '').toString().toLowerCase();
      final author = (p['author_name'] ?? '').toString().toLowerCase();
      final tag = (p['tag'] ?? '').toString().toLowerCase();
      final creator = (p['creator_profiles'] as Map?) ?? {};
      final creatorName = (creator['name'] ?? '').toString().toLowerCase();
      final creatorHandle = (creator['handle_id'] ?? '').toString().toLowerCase();
      final mockData = p['creator_mocks'] as Map?;
      final mockTitle = (mockData?['title'] ?? '').toString().toLowerCase();

      return content.contains(q) ||
          author.contains(q) ||
          tag.contains(q) ||
          creatorName.contains(q) ||
          creatorHandle.contains(q) ||
          mockTitle.contains(q);
    }).toList();

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
          // 🔍 Top Persistent Search Bar (Blended with Original Theme)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dividerColor, width: 1),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 13.5, color: isDark ? _onInk : _ink),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: '🔍 Search mocks, doubts, topics, mentor...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // 🏷️ Category Filter Chips Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      f,
                      style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    selected: isSelected,
                    selectedColor: _ink,
                    backgroundColor: cardSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? _onInk : (isDark ? _inkLight : const Color(0xFF5C5540)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                      side: BorderSide(color: isSelected ? _ink : dividerColor),
                    ),
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),
          Divider(height: 1, thickness: 1, color: dividerColor),

          // 📜 Flat Sheet Post Stream
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No posts matching "$_searchQuery"'
                                    : 'No posts yet in this section.\nBe the first to share!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500], fontSize: 13.5),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
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
                                color: bgSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (isVerifiedCreator) _navigateToCreator(authorHandle);
                                      },
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 19,
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
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    if (isVerifiedCreator)
                                                      const Icon(Icons.verified, size: 14, color: _ink),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '@$authorHandle',
                                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  isVerifiedCreator
                                                      ? '🎓 ${creator['subject_specialty'] ?? 'Exam Mentor'} • ${creator['followers_count'] ?? 0} Followers'
                                                      : 'Aspirant • Active Member',
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
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _ink.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(item['tag'] ?? 'General', style: const TextStyle(color: _ink, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildRichTextContent(item['content'] ?? ''),

                                    // Special Material Card if PDF
                                    if (item['tag'] == 'Study Material 📚')
                                      _buildStudyMaterialCard(item['content'] ?? '', isDark),

                                    if (pollData != null)
                                      _buildInteractivePollCard(postId, pollData, isDark),

                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],

                                    // 🎯 Discovery Mock Card with Funnel
                                    if (attachedMock != null)
                                      _buildMockDiscoveryCard(attachedMock, authorDisplayName, authorHandle, isDark),

                                    const SizedBox(height: 14),

                                    // Action Bar: Like, Comment, Views, Bookmark, Share
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _handleLike(idx),
                                          borderRadius: BorderRadius.circular(18),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                                                  size: 16,
                                                  color: isLiked ? _ink : Colors.grey[600],
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '$likesCount',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: isLiked ? _ink : (isDark ? _onInk : const Color(0xFF1E293B)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        InkWell(
                                          onTap: () => _openCommentsSheet(postId, item),
                                          borderRadius: BorderRadius.circular(18),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '$commentsCount',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: isDark ? _onInk : _ink,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        Row(
                                          children: [
                                            const Icon(Icons.remove_red_eye_outlined, size: 15, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text('${item['views_count'] ?? 100}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(width: 16),

                                        InkWell(
                                          onTap: () => _toggleBookmark(postId, item),
                                          borderRadius: BorderRadius.circular(18),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 17, color: isSaved ? _ink : Colors.grey),
                                                const SizedBox(width: 3),
                                                Text('${item['bookmarks_count'] ?? 0}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Spacer(),

                                        InkWell(
                                          onTap: () => _sharePost(item),
                                          borderRadius: BorderRadius.circular(18),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text('${item['shares_count'] ?? 0}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
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

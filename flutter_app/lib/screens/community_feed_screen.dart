import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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

      // Left Join with creator_profiles so normal aspirant posts don't get filtered out
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

  Future<void> _launchExternalUrl(String url) async {
    String cleanUrl = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(cleanUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url: $e");
    }
  }

  Widget _buildRichTextContent(String text, {double fontSize = 14.5}) {
    final RegExp exp = RegExp(r'((https?:\/\/|www\.)[^\s]+)|(#[a-zA-Z0-9_]+)|(@[a-zA-Z0-9_]+)');
    final matches = exp.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: TextStyle(fontSize: fontSize, height: 1.45));
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
            style: const TextStyle(color: Color(0xFF2563EB), decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
            recognizer: TapGestureRecognizer()..onTap = () => _launchExternalUrl(matchText),
          ),
        );
      } else if (matchText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tag: $matchText')));
              },
          ),
        );
      } else if (matchText.startsWith('@')) {
        final handle = matchText.substring(1);
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
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
          color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
        children: spans,
      ),
    );
  }

  void _sendNotification({
    required String receiverId,
    required String senderName,
    required int postId,
    required String type,
    required String message,
  }) async {
    if (receiverId.isEmpty || receiverId == 'user') return;
    try {
      await Supabase.instance.client.from('user_notifications').insert({
        'receiver_id': receiverId,
        'sender_name': senderName,
        'post_id': postId,
        'type': type,
        'message': message,
      });
    } catch (_) {}
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

          _sendNotification(
            receiverId: post['creator_id'] ?? '',
            senderName: 'An Aspirant',
            postId: postId,
            type: 'upvote',
            message: 'upvoted your community post 🚀',
          );
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

  void _showReportDialog(int postId, String postContent, String authorHandle) {
    String selectedReason = 'Spam or Misleading';
    final reasons = [
      'Spam or Misleading',
      'Abusive, Harassment or Hate Speech',
      'Adult / Inappropriate / Pornographic',
      'Fraud, Phishing or Betting Link',
      'Copyright Violation'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Report Abuse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select reason for reporting this post to admin:',
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) => setDlgState(() => selectedReason = val ?? selectedReason),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client.from('post_reports').insert({
                    'post_id': postId,
                    'reason': selectedReason,
                  });

                  final reportList = await Supabase.instance.client
                      .from('post_reports')
                      .select('id')
                      .eq('post_id', postId);

                  final int totalCount = (reportList as List).length;

                  if (totalCount >= 4) {
                    await AdminTelegramAlert.sendAbuseAlert(
                      postId: postId,
                      postContent: postContent,
                      authorHandle: authorHandle,
                      totalReports: totalCount,
                      lastReason: selectedReason,
                    );
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Thank you. Post reported to admin for review.'),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Report Error: $e");
                }
              },
              child: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openCommentsSheet(int postId, String postAuthorId) {
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
                                _buildRichTextContent(c['content'] ?? '', fontSize: 13),
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
                              'user_handle': 'user',
                              'user_name': 'Aspirant',
                              'content': text,
                              'parent_comment_id': replyingToCommentId,
                            });

                            _sendNotification(
                              receiverId: postAuthorId,
                              senderName: 'An Aspirant',
                              postId: postId,
                              type: 'reply',
                              message: 'replied: "${text.length > 30 ? '${text.substring(0, 30)}...' : text}"',
                            );

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
                        decoration: InputDecoration(
                          hintText: replyingToName != null ? 'Reply to @$replyingToName...' : 'Add a helpful reply or link...',
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
                                  'user_handle': 'user',
                                  'user_name': 'Aspirant',
                                  'content': text,
                                  'parent_comment_id': replyingToCommentId,
                                });

                                _sendNotification(
                                  receiverId: postAuthorId,
                                  senderName: 'An Aspirant',
                                  postId: postId,
                                  type: 'reply',
                                  message: 'replied: "${text.length > 30 ? '${text.substring(0, 30)}...' : text}"',
                                );

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
                    hintText: 'Share updates, #bpsc70th, @mentor or attach image...',
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
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () async {
                        try {
                          final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                          if (pickedFile != null) {
                            setModalState(() => selectedImage = File(pickedFile.path));
                          }
                        } catch (e) {
                          debugPrint("Image Pick Error: $e");
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                      tooltip: 'Take Photo',
                      onPressed: () async {
                        try {
                          final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
                          if (pickedFile != null) {
                            setModalState(() => selectedImage = File(pickedFile.path));
                          }
                        } catch (e) {
                          debugPrint("Camera Pick Error: $e");
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

                            final validationError = SecurityContentGuard.validateContent(text);
                            if (validationError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800),
                              );
                              return;
                            }

                            setModalState(() => isUploading = true);
                            String? uploadedImageUrl;

                            try {
                              if (selectedImage != null) {
                                final bytes = await selectedImage!.readAsBytes();
                                final fileExt = selectedImage!.path.split('.').last;
                                final fileName = 'doubt_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

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
                            } catch (err) {
                              debugPrint("Post Upload Failed: $err");
                              setModalState(() => isUploading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Upload Error: $err'),
                                    backgroundColor: Colors.red.shade800,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
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
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    _buildRichTextContent(item['content'] ?? ''),

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
                                        const SizedBox(width: 8),

                                        InkWell(
                                          onTap: () => _openCommentsSheet(postId, item['creator_id'] ?? 'user'),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Text('Reply', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
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
                                        const Spacer(),

                                        // 🚩 Visible UGC Report Button
                                        InkWell(
                                          onTap: () => _showReportDialog(
                                            postId,
                                            item['content'] ?? '',
                                            creator['handle_id'] ?? item['creator_id'] ?? 'user',
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.flag_outlined, size: 14, color: Colors.redAccent),
                                                SizedBox(width: 3),
                                                Text('Report', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

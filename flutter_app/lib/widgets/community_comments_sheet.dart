import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/security_content_guard.dart';

class CommunityCommentsSheet extends StatefulWidget {
  final int postId;
  final Map<String, dynamic> post;
  final String currentLoggedInHandle;
  final String customUserName;
  final bool isDarkMode;
  final Widget Function(String text, {double fontSize}) buildRichTextContent;
  final VoidCallback onCommentAdded;

  /// true = bottom sheet ke bajaye Post Detail page ke andar embedded.
  /// Comments ki saari logic wahi rehti hai; sirf wrapper/header badalta hai.
  final bool embedded;

  const CommunityCommentsSheet({
    super.key,
    required this.postId,
    required this.post,
    required this.currentLoggedInHandle,
    required this.customUserName,
    required this.isDarkMode,
    required this.buildRichTextContent,
    required this.onCommentAdded,
    this.embedded = false,
  });

  @override
  State<CommunityCommentsSheet> createState() => _CommunityCommentsSheetState();
}

class _CommunityCommentsSheetState extends State<CommunityCommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  int? _replyingToCommentId;
  String? _replyingToName;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  final Set<int> _likedCommentIds = {};
  final Set<int> _likingInProgress = {};

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _lightDivider = Color(0xFFE2E8F0);
  static const Color _darkDivider = Color(0xFF334155);

  static const List<Color> _avatarPalette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
  ];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color _avatarColor(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _avatarPalette[hash % _avatarPalette.length];
  }

  String _relativeTime(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.isNegative || diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  /// Comments ko thread ke hisab se lagao: reply hamesha apne
  /// parent comment ke turant neeche aayega, beech me dusre
  /// comments ghus kar use door nahi karenge (Reddit jaisa).
  List<Map<String, dynamic>> _threadOrdered(List<Map<String, dynamic>> input) {
    final byParent = <String, List<Map<String, dynamic>>>{};
    final ids = input.map((e) => e['id']?.toString()).whereType<String>().toSet();

    for (final c in input) {
      final parent = c['parent_comment_id']?.toString();
      final key = (parent == null || !ids.contains(parent)) ? '' : parent;
      byParent.putIfAbsent(key, () => []).add(c);
    }

    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    void visit(String parentKey) {
      for (final c in byParent[parentKey] ?? const <Map<String, dynamic>>[]) {
        final id = c['id']?.toString() ?? '';
        if (id.isNotEmpty && !seen.add(id)) continue;
        result.add(c);
        if (id.isNotEmpty) visit(id);
      }
    }

    visit('');
    // Koi comment kisi wajah se reh jaye (jaise parent delete ho gaya ho)
    // to use kho mat do — aakhir me laga do.
    for (final c in input) {
      if (!result.contains(c)) result.add(c);
    }
    return result;
  }

  Future<void> _fetchComments() async {
    try {
      final data = await Supabase.instance.client
          .from('post_comments')
          .select()
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = _threadOrdered(List<Map<String, dynamic>>.from(data));
          _isLoadingComments = false;
        });
        _fetchMyCommentLikes();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  /// Maine kin comments ko like kiya hai — dil wala rang usi se bharata hai.
  Future<void> _fetchMyCommentLikes() async {
    try {
      final ids = _comments
          .map((c) => int.tryParse(c['id']?.toString() ?? ''))
          .whereType<int>()
          .toList();
      if (ids.isEmpty) return;

      final rows = await Supabase.instance.client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_handle', widget.currentLoggedInHandle)
          .inFilter('comment_id', ids);

      if (mounted) {
        setState(() {
          _likedCommentIds
            ..clear()
            ..addAll(rows.map((r) => int.tryParse(r['comment_id'].toString())).whereType<int>());
        });
      }
    } catch (_) {
      // comment_likes table abhi na ho (SQL na chala ho) to like bina
      // rang ke chalega — app rukega nahi.
    }
  }

  /// Like dabana: pehle screen par turant badlav (optimistic),
  /// phir server se pakki ginti aa jati hai. Galti par purana haal wapas.
  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final commentId = int.tryParse(comment['id']?.toString() ?? '');
    if (commentId == null || _likingInProgress.contains(commentId)) return;

    final wasLiked = _likedCommentIds.contains(commentId);
    final oldCount = (comment['upvotes'] as num?)?.toInt() ?? 0;

    setState(() {
      _likingInProgress.add(commentId);
      if (wasLiked) {
        _likedCommentIds.remove(commentId);
        comment['upvotes'] = oldCount > 0 ? oldCount - 1 : 0;
      } else {
        _likedCommentIds.add(commentId);
        comment['upvotes'] = oldCount + 1;
      }
    });

    try {
      final res = await Supabase.instance.client.rpc(
        'toggle_comment_like',
        params: {
          'p_comment_id': commentId,
          'p_user_handle': widget.currentLoggedInHandle,
        },
      );

      if (mounted && res is Map) {
        setState(() {
          final serverLiked = res['liked'] == true;
          final serverLikes = (res['likes'] as num?)?.toInt();
          if (serverLiked) {
            _likedCommentIds.add(commentId);
          } else {
            _likedCommentIds.remove(commentId);
          }
          if (serverLikes != null) comment['upvotes'] = serverLikes;
          _likingInProgress.remove(commentId);
        });
      } else if (mounted) {
        setState(() => _likingInProgress.remove(commentId));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasLiked) {
            _likedCommentIds.add(commentId);
          } else {
            _likedCommentIds.remove(commentId);
          }
          comment['upvotes'] = oldCount;
          _likingInProgress.remove(commentId);
        });
      }
    }
  }

  void _openEditCommentModal(Map<String, dynamic> comment) {
    final currentText = (comment['comment_text'] ?? comment['content'] ?? '').toString();
    final editCtrl = TextEditingController(text: currentText);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
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
                  Text(
                    'Edit Reply',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editCtrl,
                maxLines: 3,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Edit your reply...',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final updatedText = editCtrl.text.trim();
                          if (updatedText.isEmpty) return;

                          final validationError = SecurityContentGuard.validateContent(updatedText);
                          if (validationError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            try {
                              await Supabase.instance.client
                                  .from('post_comments')
                                  .update({'comment_text': updatedText})
                                  .eq('id', comment['id'])
                                  .eq('user_handle', widget.currentLoggedInHandle);
                            } catch (_) {
                              await Supabase.instance.client
                                  .from('post_comments')
                                  .update({'content': updatedText})
                                  .eq('id', comment['id'])
                                  .eq('user_handle', widget.currentLoggedInHandle);
                            }

                            if (mounted) {
                              setState(() {
                                comment['comment_text'] = updatedText;
                                comment['content'] = updatedText;
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reply updated!'),
                                  backgroundColor: Color(0xFF16A34A),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            debugPrint("Comment edit failed: $e");
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteComment(int commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Reply?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this reply?',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
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
              await _deleteComment(commentId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await Supabase.instance.client
          .from('post_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_handle', widget.currentLoggedInHandle);

      setState(() {
        _comments.removeWhere((item) => item['id'] == commentId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Reply deleted'),
              ],
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to delete comment: $e");
    }
  }

  void _openCommentOptionsSheet(Map<String, dynamic> comment) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
        final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: _primaryBlue),
                  title: Text(
                    'Edit Reply',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditCommentModal(comment);
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  indent: 16,
                  endIndent: 16,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Delete Reply',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteComment(comment['id']);
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final validationError = SecurityContentGuard.validateContent(text);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      Map<String, dynamic> insertData = {
        'post_id': widget.postId,
        'user_handle': widget.currentLoggedInHandle,
        'user_name': widget.customUserName,
        'comment_text': text,
        'is_creator': widget.currentLoggedInHandle != 'user',
      };

      if (_replyingToCommentId != null) {
        insertData['parent_comment_id'] = _replyingToCommentId;
      }

      dynamic inserted;
      try {
        inserted = await Supabase.instance.client
            .from('post_comments')
            .insert(insertData)
            .select()
            .single();
      } catch (_) {
        insertData.remove('comment_text');
        insertData['content'] = text;
        inserted = await Supabase.instance.client
            .from('post_comments')
            .insert(insertData)
            .select()
            .single();
      }

      _commentCtrl.clear();
      setState(() {
        _comments = _threadOrdered([..._comments, inserted]);
        _replyingToCommentId = null;
        _replyingToName = null;
        _isSubmitting = false;
      });

      widget.onCommentAdded();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting reply: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final dividerColor = isDark ? _darkDivider : _lightDivider;

    final Widget commentsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                  children: [
                    const Icon(Icons.forum_outlined, size: 20, color: _primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Discussion & Replies',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Row(
              children: [
                Text(
                  'Replies',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (!_isLoadingComments) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${_comments.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        Divider(color: dividerColor),
            Expanded(
              child: _isLoadingComments
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined, size: 38, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No replies yet. Be the first to solve!',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (context, cIdx) {
                            final c = _comments[cIdx];
                            final bool isReply = c['parent_comment_id'] != null;
                            final bool isMyComment = (c['user_handle'] ?? '').toString() == widget.currentLoggedInHandle;

                            final cid = int.tryParse(c['id']?.toString() ?? '');
                            final liked = cid != null && _likedCommentIds.contains(cid);
                            final likeCount = (c['upvotes'] as num?)?.toInt() ?? 0;

                            return Container(
                              margin: EdgeInsets.only(left: isReply ? 34.0 : 0.0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: dividerColor.withValues(alpha: 0.65),
                                    width: 0.7,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar + reply thread line
                                  Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _avatarColor(
                                          '${c['user_handle'] ?? ''}${c['user_name'] ?? ''}',
                                        ),
                                        child: Text(
                                          _initials((c['user_name'] ?? 'Aspirant').toString()),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      if (isReply) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 1.6,
                                          height: 14,
                                          color: dividerColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                c['user_name'] ?? 'Aspirant',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (c['is_creator'] == true) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, color: _primaryBlue, size: 13),
                                            ],
                                            if (_relativeTime(c['created_at']).isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '· ${_relativeTime(c['created_at'])}',
                                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                              ),
                                            ],
                                            const Spacer(),
                                            if (isMyComment)
                                              InkWell(
                                                borderRadius: BorderRadius.circular(14),
                                                onTap: () => _openCommentOptionsSheet(c),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(4),
                                                  child: Icon(
                                                    Icons.more_horiz_rounded,
                                                    size: 18,
                                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        widget.buildRichTextContent(
                                          c['comment_text'] ?? c['content'] ?? '',
                                          fontSize: 13.5,
                                        ),
                                        const SizedBox(height: 7),
                                        // Action row: text ke seedhe neeche, left se.
                                        Row(
                                          children: [
                                            InkWell(
                                              borderRadius: BorderRadius.circular(14),
                                              onTap: cid == null ? null : () => _toggleCommentLike(c),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                                      size: 15,
                                                      color: liked ? _primaryBlue : Colors.grey[600],
                                                    ),
                                                    if (likeCount > 0) ...[
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$likeCount',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: liked ? _primaryBlue : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 22),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(14),
                                              onTap: () {
                                                setState(() {
                                                  _replyingToCommentId = c['id'];
                                                  _replyingToName = c['user_name'] ?? 'Aspirant';
                                                });
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.grey[600]),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      'Reply',
                                                      style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w700),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            if (_replyingToCommentId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: _primaryBlue.withOpacity(0.1),
                child: Row(
                  children: [
                    Text(
                      'Replying to @$_replyingToName',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => setState(() {
                        _replyingToCommentId = null;
                        _replyingToName = null;
                      }),
                    ),
                  ],
                ),
              ),
            Divider(color: dividerColor),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _avatarColor(widget.customUserName),
                  child: Text(
                    _initials(widget.customUserName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: dividerColor),
                    ),
                    child: TextField(
                      controller: _commentCtrl,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: _replyingToName != null ? 'Reply to @$_replyingToName...' : 'Add solution as ${widget.customUserName}...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: _primaryBlue),
                  onPressed: _isSubmitting ? null : _submitComment,
                ),
              ],
            ),
            const SizedBox(height: 10),
      ],
    );

    if (widget.embedded) return commentsContent;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: commentsContent,
      ),
    );
  }
}

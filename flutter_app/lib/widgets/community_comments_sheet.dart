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

  const CommunityCommentsSheet({
    super.key,
    required this.postId,
    required this.post,
    required this.currentLoggedInHandle,
    required this.customUserName,
    required this.isDarkMode,
    required this.buildRichTextContent,
    required this.onCommentAdded,
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

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _lightDivider = Color(0xFFE2E8F0);
  static const Color _darkDivider = Color(0xFF334155);

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

  Future<void> _fetchComments() async {
    try {
      final data = await Supabase.instance.client
          .from('post_comments')
          .select()
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data);
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComments = false);
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
        _comments.add(inserted);
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Divider(color: dividerColor),
            Expanded(
              child: _isLoadingComments
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _comments.isEmpty
                      ? const Center(child: Text('No replies yet. Be the first to solve!'))
                      : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (context, cIdx) {
                            final c = _comments[cIdx];
                            final bool isReply = c['parent_comment_id'] != null;
                            final bool isMyComment = (c['user_handle'] ?? '').toString() == widget.currentLoggedInHandle;

                            return Container(
                              margin: EdgeInsets.only(left: isReply ? 24.0 : 0.0, bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isReply
                                    ? (isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFF1F5F9))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isReply ? const Border(left: BorderSide(color: _primaryBlue, width: 3)) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c['user_name'] ?? 'Aspirant',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      if (c['is_creator'] == true)
                                        const Icon(Icons.verified, color: _primaryBlue, size: 14),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _replyingToCommentId = c['id'];
                                            _replyingToName = c['user_name'] ?? 'Aspirant';
                                          });
                                        },
                                        child: const Text(
                                          'Reply',
                                          style: TextStyle(color: _primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (isMyComment) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _openCommentOptionsSheet(c),
                                          child: Icon(
                                            Icons.more_horiz_rounded,
                                            size: 18,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  widget.buildRichTextContent(
                                    c['comment_text'] ?? c['content'] ?? '',
                                    fontSize: 13,
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
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _replyingToName != null ? 'Reply to @$_replyingToName...' : 'Add solution as ${widget.customUserName}...',
                      border: InputBorder.none,
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
        ),
      ),
    );
  }
}

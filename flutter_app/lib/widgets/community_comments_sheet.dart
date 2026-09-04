import 'package:flutter/material.dart';
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
  static const Color _lightCard = Colors.white;
  static const Color _lightDivider = Color(0xFFE2E8F0);
  static const Color _darkCard = Color(0xFF1E293B);
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
    final cardSurface = isDark ? _darkCard : _lightCard;
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
                Text(
                  '💬 Discussion & Replies',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
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
                                      Text(c['user_name'] ?? 'Aspirant', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                        child: const Text('Reply', style: TextStyle(color: _primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  widget.buildRichTextContent(c['comment_text'] ?? c['content'] ?? '', fontSize: 13),
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
                    Text('Replying to @$_replyingToName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue)),
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

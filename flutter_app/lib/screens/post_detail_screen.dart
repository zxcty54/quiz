import 'package:flutter/material.dart';

import '../widgets/community_comments_sheet.dart';
import '../widgets/community_post_card.dart';

/// Twitter/Reddit jaisi Post Detail screen.
///
/// Feed me comment dabane par bottom sheet ke bajaye ye page khulta hai:
/// upar pura post (photo/poll/mock ke saath), neeche replies aur sabse neeche
/// fixed comment likhne ki jagah. Back dabane par feed wapas aa jata hai —
/// scroll position bhi bani rehti hai kyunki feed apni jagah par hi rehta hai.
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentLoggedInHandle;
  final String customUserName;
  final bool isDarkMode;

  final bool isCurrentUserCreator;
  final bool initialLiked;
  final bool initialSaved;
  final int? initialPollIndex;

  final Function(bool isLiked) onLikeToggle;
  final Function(bool isSaved) onBookmarkToggle;
  final Function(int optionIndex) onPollVote;
  final Function(int postId)? onPostViewed;
  final VoidCallback? onPostDeleted;

  /// Feed ko batane ke liye ki is post ka data (jaise comments_count) badla hai,
  /// taaki wapas jaane par feed fresh dikhe.
  final VoidCallback? onPostChanged;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.currentLoggedInHandle,
    required this.customUserName,
    required this.isDarkMode,
    this.isCurrentUserCreator = false,
    required this.initialLiked,
    required this.initialSaved,
    required this.initialPollIndex,
    required this.onLikeToggle,
    required this.onBookmarkToggle,
    required this.onPollVote,
    this.onPostViewed,
    this.onPostDeleted,
    this.onPostChanged,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool _isLiked;
  late bool _isSaved;
  int? _pollSelection;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialLiked;
    _isSaved = widget.initialSaved;
    _pollSelection = widget.initialPollIndex;
  }

  int get _postId =>
      int.tryParse(widget.post['id']?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final divider = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Post',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Post — lambe text/photo par ye hissa apne andar scroll ho jata
            // hai, lekin screen ka hissa tay seema tak hi lega. Pehle ye
            // comments ke saath aadha-aadha baant leta tha, isliye comment
            // box beech me ruk jata tha aur neeche khali safed jagah
            // bach jati thi.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: SingleChildScrollView(
                child: CommunityPostCard(
                  post: widget.post,
                  currentLoggedInHandle: widget.currentLoggedInHandle,
                  isLiked: _isLiked,
                  isSaved: _isSaved,
                  selectedPollIndex: _pollSelection,
                  isDarkMode: isDark,
                  // Replies pehle se dikhai de rahe hain, isliye comment
                  // button detail page par chhupa diya gaya hai.
                  showCommentAction: false,
                  onOpenComments: () {},
                  onPostViewed: widget.onPostViewed,
                  onLikeToggle: (liked) {
                    setState(() => _isLiked = liked);
                    widget.onLikeToggle(liked);
                  },
                  onBookmarkToggle: (saved) {
                    setState(() => _isSaved = saved);
                    widget.onBookmarkToggle(saved);
                  },
                  onPollVote: (optIdx) {
                    setState(() => _pollSelection = optIdx);
                    widget.onPollVote(optIdx);
                  },
                  onPostDeleted: () {
                    widget.onPostDeleted?.call();
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: divider),

            // Replies + fixed comment composer (wahi purana comments code,
            // ab sheet ke wrapper ke bagair).
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: CommunityCommentsSheet(
                  postId: _postId,
                  post: widget.post,
                  currentLoggedInHandle: widget.currentLoggedInHandle,
                  customUserName: widget.customUserName,
                  isDarkMode: isDark,
                  embedded: true,
                  isCurrentUserCreator: widget.isCurrentUserCreator,
                  buildRichTextContent: (text, {fontSize = 14.5}) =>
                      Text(text, style: TextStyle(fontSize: fontSize)),
                  onCommentAdded: () {
                    setState(() {
                      widget.post['comments_count'] =
                          (widget.post['comments_count'] ?? 0) + 1;
                    });
                    widget.onPostChanged?.call();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

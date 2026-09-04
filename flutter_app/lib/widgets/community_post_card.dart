import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../screens/creator_profile_screen.dart';
import '../screens/sectional_cbt_screen.dart';

class CommunityPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentLoggedInHandle;
  final bool isLiked;
  final bool isSaved;
  final int? selectedPollIndex;
  final bool isDarkMode;
  final VoidCallback onOpenComments;
  final Function(bool isLiked) onLikeToggle;
  final Function(bool isSaved) onBookmarkToggle;
  final Function(int optionIndex) onPollVote;

  const CommunityPostCard({
    super.key,
    required this.post,
    required this.currentLoggedInHandle,
    required this.isLiked,
    required this.isSaved,
    required this.selectedPollIndex,
    required this.isDarkMode,
    required this.onOpenComments,
    required this.onLikeToggle,
    required this.onBookmarkToggle,
    required this.onPollVote,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  static const Color _primaryBlue = Color(0xFF2563EB);

  late bool _liked;
  late bool _saved;
  late int _likesCount;
  late int _bookmarksCount;
  int? _pollSelection;

  @override
  void initState() {
    super.initState();
    _liked = widget.isLiked;
    _saved = widget.isSaved;
    _likesCount = widget.post['upvotes'] ?? 0;
    _bookmarksCount = widget.post['bookmarks_count'] ?? 0;
    _pollSelection = widget.selectedPollIndex;
  }

  @override
  void didUpdateWidget(covariant CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked) _liked = widget.isLiked;
    if (oldWidget.isSaved != widget.isSaved) _saved = widget.isSaved;
    if (oldWidget.selectedPollIndex != widget.selectedPollIndex) {
      _pollSelection = widget.selectedPollIndex;
    }
  }

  void _handleLike() async {
    HapticFeedback.lightImpact();
    final bool newLiked = !_liked;
    final int delta = newLiked ? 1 : -1;

    setState(() {
      _liked = newLiked;
      _likesCount = (_likesCount + delta).clamp(0, 999999);
      widget.post['upvotes'] = _likesCount;
    });

    widget.onLikeToggle(newLiked);

    try {
      if (newLiked) {
        await Supabase.instance.client.from('post_likes').insert({
          'post_id': widget.post['id'],
          'user_handle': widget.currentLoggedInHandle,
        });
      } else {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_handle', widget.currentLoggedInHandle);
      }

      await Supabase.instance.client
          .from('community_posts')
          .update({'upvotes': _likesCount})
          .eq('id', widget.post['id']);
    } catch (_) {}
  }

  void _handleBookmark() async {
    HapticFeedback.mediumImpact();
    final bool newSaved = !_saved;
    final int delta = newSaved ? 1 : -1;

    setState(() {
      _saved = newSaved;
      _bookmarksCount = (_bookmarksCount + delta).clamp(0, 999999);
      widget.post['bookmarks_count'] = _bookmarksCount;
    });

    widget.onBookmarkToggle(newSaved);

    try {
      if (newSaved) {
        await Supabase.instance.client.from('user_saved_posts').insert({
          'user_handle': widget.currentLoggedInHandle,
          'post_id': widget.post['id'],
        });
      } else {
        await Supabase.instance.client
            .from('user_saved_posts')
            .delete()
            .eq('user_handle', widget.currentLoggedInHandle)
            .eq('post_id', widget.post['id']);
      }

      await Supabase.instance.client
          .from('community_posts')
          .update({'bookmarks_count': _bookmarksCount})
          .eq('id', widget.post['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newSaved ? '📌 Saved to Notebook!' : 'Removed from Saved!'),
            duration: const Duration(seconds: 1),
            backgroundColor: _primaryBlue,
          ),
        );
      }
    } catch (_) {}
  }

  void _submitPollVote(int optionIdx, Map<String, dynamic> pollData) async {
    if (_pollSelection != null) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _pollSelection = optionIdx;
      List votes = List.from(pollData['votes'] ?? [0, 0, 0, 0]);
      if (optionIdx < votes.length) {
        votes[optionIdx] = (votes[optionIdx] as int) + 1;
      }
      pollData['votes'] = votes;
    });

    widget.onPollVote(optionIdx);

    try {
      await Supabase.instance.client.from('poll_votes').insert({
        'post_id': widget.post['id'],
        'user_handle': widget.currentLoggedInHandle,
        'option_index': optionIdx,
      });

      await Supabase.instance.client
          .from('community_posts')
          .update({'poll_data': pollData})
          .eq('id', widget.post['id']);
    } catch (_) {}
  }

  void _sharePost() async {
    HapticFeedback.lightImpact();
    final postId = widget.post['id'];
    final content = widget.post['content'] ?? 'Check out this question on MockTester!';
    final author = widget.post['author_name'] ?? 'Aspirant';

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
        backgroundColor: _primaryBlue,
      ),
    );

    try {
      final currentShares = (widget.post['shares_count'] ?? 0) + 1;
      setState(() => widget.post['shares_count'] = currentShares);

      await Supabase.instance.client
          .from('community_posts')
          .update({'shares_count': currentShares})
          .eq('id', postId);
    } catch (_) {}
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
        ),
      ),
    );
  }

  Widget _buildRichTextContent(String text) {
    final RegExp exp = RegExp(r'((https?:\/\/|www\.)[^\s]+)|(#[a-zA-Z0-9_]+)|(@[a-zA-Z0-9_]+)');
    final matches = exp.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: widget.isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
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
            style: const TextStyle(color: _primaryBlue, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                    Uri.parse(matchText.startsWith('http') ? matchText : 'https://$matchText'),
                    mode: LaunchMode.externalApplication,
                  ),
          ),
        );
      } else if (matchText.startsWith('@')) {
        final handle = matchText.substring(1);
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatorProfileScreen(
                      creatorHandle: handle,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
              },
          ),
        );
      } else {
        spans.add(TextSpan(text: matchText, style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: widget.isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildInteractivePollCard(Map<String, dynamic> pollData) {
    final List options = pollData['options'] ?? [];
    final int correctIdx = pollData['correct_idx'] ?? 0;
    final List votes = pollData['votes'] ?? List.filled(options.length, 0);
    final String explanation = pollData['exp'] ?? '';
    final bool hasVoted = _pollSelection != null;

    int totalVotes = 0;
    for (var v in votes) {
      totalVotes += (v is int) ? v : (int.tryParse(v.toString()) ?? 0);
    }
    if (totalVotes == 0) totalVotes = 1;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryBlue.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text('Live Daily Quiz • Tap to Solve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(options.length, (idx) {
            final optText = options[idx];
            final int optVotes = (idx < votes.length) ? (votes[idx] as int) : 0;
            final double percent = (optVotes / totalVotes) * 100;
            final bool isSelected = _pollSelection == idx;
            final bool isCorrect = correctIdx == idx;

            Color tileColor = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
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
                onTap: () => _submitPollVote(idx, pollData),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(8),
                    border: hasVoted && isCorrect
                        ? Border.all(color: const Color(0xFF16A34A), width: 1.5)
                        : Border.all(color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
              decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: _primaryBlue),
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

  Widget _buildMockDiscoveryCard(Map<String, dynamic> mock, String authorName, String handle) {
    final int totalQs = (mock['questions_json'] as List?)?.length ?? 0;
    final int duration = mock['duration_mins'] ?? 15;
    final int attempts = mock['attempts_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.isDarkMode ? const Color(0xFF1E40AF) : const Color(0xFFDBEAFE), width: 1.1),
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
                      style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.grey[400] : const Color(0xFF64748B)),
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
                  style: TextStyle(fontSize: 11.5, color: widget.isDarkMode ? Colors.grey[300] : const Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
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
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorProfileScreen(creatorHandle: handle, isDarkMode: widget.isDarkMode),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFDBEAFE).withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: _primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Curated by $authorName • Explore Classroom Batches →',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryBlue),
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

  @override
  Widget build(BuildContext context) {
    final creator = widget.post['creator_profiles'] ?? {};
    final attachedMock = widget.post['creator_mocks'];
    final bool isVerifiedCreator = creator['name'] != null && (widget.post['creator_id'] != 'user');
    final String authorHandle = (creator['handle_id'] ?? widget.post['creator_id'] ?? 'user').toString();
    final String authorDisplayName = isVerifiedCreator
        ? (creator['name'] ?? 'Verified Mentor')
        : (widget.post['author_name'] ?? 'Aspirant');
    final String? imgUrl = widget.post['image_url'];
    final Map<String, dynamic>? pollData = widget.post['poll_data'];
    final int commentsCount = widget.post['comments_count'] ?? 0;
    final cardSurface = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      color: cardSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (isVerifiedCreator) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatorProfileScreen(creatorHandle: authorHandle, isDarkMode: widget.isDarkMode),
                  ),
                );
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: isVerifiedCreator ? _primaryBlue : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFF64748B)),
                  child: Text(
                    isVerifiedCreator ? ((creator['name'] ?? 'M')[0]).toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(authorDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 4),
                          if (isVerifiedCreator) const Icon(Icons.verified, size: 14, color: _primaryBlue),
                          const SizedBox(width: 6),
                          Text('@$authorHandle', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                      Text(
                        isVerifiedCreator
                            ? '🎓 ${creator['subject_specialty'] ?? 'Exam Mentor'} • ${creator['followers_count'] ?? 0} Followers'
                            : 'Aspirant • Active Member',
                        style: TextStyle(
                          color: isVerifiedCreator ? _primaryBlue : Colors.grey[600],
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
                    color: _primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(widget.post['tag'] ?? 'General', style: const TextStyle(color: _primaryBlue, fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          _buildRichTextContent(widget.post['content'] ?? ''),

          if (pollData != null) _buildInteractivePollCard(pollData),

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

          if (attachedMock != null) _buildMockDiscoveryCard(attachedMock, authorDisplayName, authorHandle),

          const SizedBox(height: 14),

          // Actions Row
          Row(
            children: [
              InkWell(
                onTap: _handleLike,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16, color: _liked ? _primaryBlue : Colors.grey[600]),
                      const SizedBox(width: 5),
                      Text('$_likesCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _liked ? _primaryBlue : (widget.isDarkMode ? Colors.white : const Color(0xFF1E293B)))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              InkWell(
                onTap: widget.onOpenComments,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text('$commentsCount', style: TextStyle(fontSize: 12.5, color: widget.isDarkMode ? Colors.white : _primaryBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${widget.post['views_count'] ?? 100}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 16),

              InkWell(
                onTap: _handleBookmark,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 17, color: _saved ? _primaryBlue : Colors.grey),
                      const SizedBox(width: 3),
                      Text('$_bookmarksCount', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              InkWell(
                onTap: _sharePost,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${widget.post['shares_count'] ?? 0}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

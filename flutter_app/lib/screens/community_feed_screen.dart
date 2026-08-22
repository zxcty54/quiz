import 'dart:convert';
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
  final Map<int, int> _userVoteState = {};
  final Map<int, int> _userPollSelections = {}; // post_id -> selected_option_idx
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

  @override
  void initState() {
    super.initState();
    _loadSavedCache();
    _fetchFeedPosts();
  }

  Future<void> _loadSavedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('local_saved_post_ids') ?? [];
    _savedPostIds.addAll(saved.map((e) => int.tryParse(e) ?? 0));
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
          _posts = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Feed Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleBookmark(int postId) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_savedPostIds.contains(postId)) {
        _savedPostIds.remove(postId);
      } else {
        _savedPostIds.add(postId);
      }
    });

    await prefs.setStringList('local_saved_post_ids', _savedPostIds.map((e) => e.toString()).toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_savedPostIds.contains(postId) ? '📌 Saved to Revision Notebook!' : 'Removed from Saved!'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
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
            recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(matchText.startsWith('http') ? matchText : 'https://$matchText'), mode: LaunchMode.externalApplication),
          ),
        );
      } else if (matchText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => setState(() => _activeFilter = matchText),
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
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text('Live Daily Quiz • Tap to Solve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(options.length, (idx) {
            final optText = options[idx];
            final int optVotes = (idx < votes.length) ? (votes[idx] as int) : 0;
            final double percent = (optVotes / totalVotes) * 100;
            final bool isSelected = selectedIdx == idx;
            final bool isCorrect = correctIdx == idx;

            Color tileColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
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
                    border: hasVoted && isCorrect ? Border.all(color: const Color(0xFF16A34A), width: 1.5) : null,
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
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF2563EB)),
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

  void _openCreatePostModal() {
    final contentCtrl = TextEditingController();
    String selectedTag = 'Doubts ❓';
    File? selectedImage;
    bool isUploading = false;
    bool isPollMode = false;
    final opControllers = [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()];
    final expCtrl = TextEditingController();
    int correctPollIdx = 0;
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
                    Text(isPollMode ? '⚡ Create Interactive Daily Quiz' : '✍️ Create Community Post', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(labelText: 'Exam / Subject Tag', isDense: true, border: OutlineInputBorder()),
                  items: _filters.where((f) => f != 'All' && f != 'Saved 📌').map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setModalState(() => selectedTag = val ?? selectedTag),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: contentCtrl,
                  maxLines: isPollMode ? 2 : 4,
                  decoration: InputDecoration(
                    hintText: isPollMode ? 'Type Question headline...' : 'Share updates, #bpsc70th, @mentor or ask doubt...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                if (isPollMode) ...[
                  ...List.generate(4, (idx) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setModalState(() => correctPollIdx = idx),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: correctPollIdx == idx ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                                child: Text(String.fromCharCode(65 + idx), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: opControllers[idx],
                                decoration: InputDecoration(hintText: 'Option ${String.fromCharCode(65 + idx)}', isDense: true, border: const OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                      )),
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(labelText: 'Short Solution / Explanation', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                ],

                if (selectedImage != null && !isPollMode) ...[
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
                      icon: Icon(isPollMode ? Icons.chat : Icons.poll_outlined, size: 18),
                      label: Text(isPollMode ? 'Normal Post' : '+ Add 4-Option Quiz'),
                      onPressed: () => setModalState(() => isPollMode = !isPollMode),
                    ),
                    const SizedBox(width: 8),
                    if (!isPollMode)
                      IconButton(
                        icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                        onPressed: () async {
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
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
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    onPressed: isUploading
                        ? null
                        : () async {
                            final text = contentCtrl.text.trim();
                            if (text.isEmpty && selectedImage == null && !isPollMode) return;

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

                              Map<String, dynamic>? pollJson;
                              if (isPollMode) {
                                pollJson = {
                                  'options': opControllers.map((c) => c.text.trim().isEmpty ? 'Option' : c.text.trim()).toList(),
                                  'correct_idx': correctPollIdx,
                                  'votes': [0, 0, 0, 0],
                                  'exp': expCtrl.text.trim(),
                                };
                              }

                              await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': 'user',
                                'content': text,
                                'tag': isPollMode ? 'Daily Quiz ⚡' : selectedTag,
                                'image_url': uploadedImageUrl,
                                'poll_data': pollJson,
                                'views_count': 1,
                              });

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
                        : const Text('Publish to Community 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
        : (_activeFilter == 'Saved 📌'
            ? _posts.where((p) => _savedPostIds.contains(p['id'])).toList()
            : _posts.where((p) => p['tag'].toString().contains(_activeFilter.split(' ').first)).toList());

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Community Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchFeedPosts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Post / Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        ? const Center(child: Text('No posts yet in this category.\nBe the first to share!'))
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
                              final Map<String, dynamic>? pollData = item['poll_data'];
                              final bool isSaved = _savedPostIds.contains(postId);

                              return Container(
                                color: bgSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: (creator['name'] != null) ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                          child: Text(
                                            ((creator['name'] ?? 'U')[0]).toUpperCase(),
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
                                                  Text(creator['name'] ?? 'Aspirant Candidate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                                  const SizedBox(width: 4),
                                                  if (creator['name'] != null)
                                                    const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                                                  const SizedBox(width: 6),
                                                  Text('@${creator['handle_id'] ?? item['creator_id'] ?? 'user'}', style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(item['tag'] ?? 'General', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    _buildRichTextContent(item['content'] ?? ''),

                                    if (pollData != null)
                                      _buildInteractivePollCard(postId, pollData, isDark),

                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(imgUrl, fit: BoxFit.cover, width: double.infinity, height: 200),
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
                                                  Text('${(attachedMock['questions_json'] as List?)?.length ?? 0} Qs • ${attachedMock['duration_mins']} Mins', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
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
                                          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.arrow_upward_rounded, size: 16, color: userVote == 1 ? const Color(0xFFFF4500) : Colors.grey[600]),
                                                onPressed: () => _handleVote(idx, true),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: userVote == 1 ? const Color(0xFFFF4500) : (userVote == -1 ? const Color(0xFF7193FF) : null))),
                                              IconButton(
                                                icon: Icon(Icons.arrow_downward_rounded, size: 16, color: userVote == -1 ? const Color(0xFF7193FF) : Colors.grey[600]),
                                                onPressed: () => _handleVote(idx, false),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        IconButton(
                                          icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20, color: isSaved ? const Color(0xFF2563EB) : Colors.grey),
                                          onPressed: () => _toggleBookmark(postId),
                                          tooltip: 'Save to Revision',
                                          visualDensity: VisualDensity.compact,
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

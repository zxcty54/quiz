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

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<int, int> _userVoteState = {};
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

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _fetchFeedPosts();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('community_saved_posts_ids') ?? [];
    final name = prefs.getString('custom_aspirant_name') ?? 'Aspirant';
    final handle = prefs.getString('logged_in_creator_handle') ?? 'user';
    if (mounted) {
      setState(() {
        _savedPostIds.addAll(saved.map((e) => int.tryParse(e) ?? 0));
        _customUserName = name;
        _currentLoggedInHandle = handle;
      });
    }
  }

  Future<void> _fetchFeedPosts() async {
    setState(() => _isLoading = true);
    try {
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60)).toIso8601String();

      final res = await Supabase.instance.client
          .from('community_posts')
          .select('*, creator_profiles(name, handle_id, subject_specialty, followers_count, is_blocked), creator_mocks(*)')
          .eq('is_approved', true)
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

  void _launchAttachedMock(Map<String, dynamic> mock, String coachingName, String handle) {
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

    // Free Open CBT launch without password
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
        .update({'upvotes': post['upvotes'], 'downvotes': post['downvotes']})
        .eq('id', postId)
        .then((_) {});
  }

  void _toggleBookmark(int postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
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

    await prefs.setStringList('community_saved_posts_ids', _savedPostIds.map((e) => e.toString()).toList());
    Supabase.instance.client
        .from('community_posts')
        .update({'bookmarks_count': post['bookmarks_count']})
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
                    Text('✍️ Ask Doubt / Share Notice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(selectedImage!, width: double.infinity, height: 140, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
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
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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
                                'is_approved': false,
                                'views_count': 1,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

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
                                  const SnackBar(content: Text('⏳ Post submitted for review!'), backgroundColor: Color(0xFF2563EB)),
                                );
                              }
                            } catch (_) {
                              setModalState(() => isUploading = false);
                            }
                          },
                    child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('Publish Post 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildRichTextContent(String text, {double fontSize = 14}) {
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
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(Uri.parse(matchText.startsWith('http') ? matchText : 'https://$matchText'), mode: LaunchMode.externalApplication),
          ),
        );
      } else if (matchText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => setState(() => _searchCtrl.text = matchText),
          ),
        );
      } else if (matchText.startsWith('@')) {
        final handle = matchText.substring(1);
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => _navigateToCreator(handle),
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

  // 🎯 Premium Free Mock Test Discovery Card
  Widget _buildMockDiscoveryCard(Map<String, dynamic> mock, String authorName, String handle, bool isDark) {
    final int totalQs = (mock['questions_json'] as List?)?.length ?? 0;
    final int duration = mock['duration_mins'] ?? 15;
    final int attempts = mock['attempts_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25), width: 1.1),
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
                        color: const Color(0xFF16A34A).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF16A34A)),
                          SizedBox(width: 3),
                          Text('FREE CBT MOCK', style: TextStyle(color: Color(0xFF16A34A), fontSize: 9.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    Text('$attempts Aspirants Attempted', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => _launchAttachedMock(mock, authorName, handle),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_fill_rounded, size: 16),
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
                color: const Color(0xFF2563EB).withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Curated by $authorName • Explore Classroom Batches →',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final filteredList = _posts.where((p) {
      bool matchesFilter = true;
      if (_activeFilter == 'Saved 📌') {
        matchesFilter = _savedPostIds.contains(p['id']);
      } else if (_activeFilter != 'All') {
        matchesFilter = p['tag'].toString().contains(_activeFilter.split(' ').first);
      }
      if (!matchesFilter) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return (p['content'] ?? '').toString().toLowerCase().contains(q) ||
          (p['author_name'] ?? '').toString().toLowerCase().contains(q) ||
          (p['tag'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(hintText: 'Search feed, mocks, tags...', border: InputBorder.none),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text('Community Feed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchFeedPosts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Share Doubt / Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _openCreatePostModal,
      ),
      body: Column(
        children: [
          // Filter Chips Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: _filters.map((f) {
                final isSel = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSel,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1, thickness: 0.8, color: dividerColor),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? Center(child: Text('No posts found in this section.', style: TextStyle(color: Colors.grey.shade500)))
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
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

                              final bool isVerifiedCreator = creator['name'] != null && (item['creator_id'] != 'user');
                              final String authorHandle = (creator['handle_id'] ?? item['creator_id'] ?? 'user').toString();
                              final String authorDisplayName = isVerifiedCreator ? (creator['name'] ?? 'Verified Mentor') : (item['author_name'] ?? 'Aspirant');

                              return Container(
                                color: bgSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 👤 Clickable Author Header (Transitions to Profile)
                                    InkWell(
                                      onTap: () {
                                        if (isVerifiedCreator) _navigateToCreator(authorHandle);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: isVerifiedCreator ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                            child: Text(
                                              authorDisplayName.isNotEmpty ? authorDisplayName[0].toUpperCase() : 'A',
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
                                                    Flexible(
                                                      child: Text(
                                                        authorDisplayName,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isVerifiedCreator) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                                                    ],
                                                    const SizedBox(width: 6),
                                                    Text('@$authorHandle', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                                  ],
                                                ),
                                                Text(
                                                  isVerifiedCreator ? '🎓 ${creator['subject_specialty'] ?? 'Coaching Mentor'}' : 'Aspirant • Community Member',
                                                  style: TextStyle(color: isVerifiedCreator ? const Color(0xFF2563EB) : Colors.grey[600], fontSize: 10.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                            child: Text(item['tag'] ?? 'General', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Post Content
                                    _buildRichTextContent(item['content'] ?? ''),

                                    // Special Material Card if PDF
                                    if (item['tag'] == 'Study Material 📚') _buildStudyMaterialCard(item['content'] ?? '', isDark),

                                    // Attached Mock Test Discovery Card
                                    if (attachedMock != null) _buildMockDiscoveryCard(attachedMock, authorDisplayName, authorHandle, isDark),

                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(imgUrl, fit: BoxFit.cover, width: double.infinity, height: 180),
                                      ),
                                    ],

                                    const SizedBox(height: 12),

                                    // Interaction Footer (Upvote, Views, Save, Share)
                                    Row(
                                      children: [
                                        Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.arrow_upward_rounded, size: 15, color: userVote == 1 ? const Color(0xFFFF4500) : Colors.grey[600]),
                                                onPressed: () => _handleVote(idx, true),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: userVote == 1 ? const Color(0xFFFF4500) : null)),
                                              IconButton(
                                                icon: Icon(Icons.arrow_downward_rounded, size: 15, color: userVote == -1 ? const Color(0xFF7193FF) : Colors.grey[600]),
                                                onPressed: () => _handleVote(idx, false),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        Row(
                                          children: [
                                            const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text('${item['views_count'] ?? 100}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(width: 8),

                                        InkWell(
                                          onTap: () => _toggleBookmark(postId, item),
                                          child: Row(
                                            children: [
                                              Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 15, color: isSaved ? const Color(0xFF2563EB) : Colors.grey),
                                              const SizedBox(width: 2),
                                              Text('${item['bookmarks_count'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),

                                        IconButton(
                                          icon: const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: item['content'] ?? ''));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                                          },
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

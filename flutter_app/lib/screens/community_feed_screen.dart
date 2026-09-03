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

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final Set<int> _likedPostIds = {};
  final Map<int, int> _userPollSelections = {};
  final Set<int> _savedPostIds = {};

  final List<String> _filters = [
    'All',
    'Mocks',
    'Study',
    'Quiz',
    'Doubts',
    'Notices',
    'Saved',
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
    final liked = prefs.getStringList('community_liked_posts_ids') ?? [];
    final name = prefs.getString('custom_aspirant_name') ?? 'Aspirant';
    final handle = prefs.getString('logged_in_creator_handle') ?? 'user';
    if (mounted) {
      setState(() {
        _savedPostIds.addAll(saved.map((e) => int.tryParse(e) ?? 0));
        _likedPostIds.addAll(liked.map((e) => int.tryParse(e) ?? 0));
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
    await prefs.setStringList('community_liked_posts_ids', _likedPostIds.map((e) => e.toString()).toList());

    Supabase.instance.client
        .from('community_posts')
        .update({'upvotes': post['upvotes']})
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
    String selectedTag = 'Doubts';
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
                    const Text('Ask Doubt / Share Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()),
                  items: _filters.where((f) => f != 'All' && f != 'Saved').map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
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
                                  const SnackBar(content: Text('Post submitted for review!'), backgroundColor: Color(0xFF2563EB)),
                                );
                              }
                            } catch (_) {
                              setModalState(() => isUploading = false);
                            }
                          },
                    child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('Publish Post', style: TextStyle(fontWeight: FontWeight.bold)),
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
      return Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
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
          color: widget.isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildMockDiscoveryCard(Map<String, dynamic> mock, String authorName, String handle, bool isDark) {
    final int totalQs = (mock['questions_json'] as List?)?.length ?? 0;
    final int duration = mock['duration_mins'] ?? 15;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFDBEAFE), width: 1),
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
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mock['title'] ?? 'Mock Drill',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalQs Questions • $duration Minutes • Instant Result',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      elevation: 0,
                    ),
                    onPressed: () => _launchAttachedMock(mock, authorName, handle),
                    child: const Text('Attempt Free Mock →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _navigateToCreator(handle),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFDBEAFE).withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '🎓 View Coaching: $authorName',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 15, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyMaterialCard(String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: Color(0xFF059669), size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Study Material Attached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
                Text('Tap download link inside the post to view PDF', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF78350F).withOpacity(0.3) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign_outlined, color: Color(0xFFD97706), size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Official Announcement / Notice',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFD97706)),
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
    final dividerColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final filteredList = _posts.where((p) {
      bool matchesFilter = true;
      if (_activeFilter == 'Saved') {
        matchesFilter = _savedPostIds.contains(p['id']);
      } else if (_activeFilter != 'All') {
        final tag = (p['tag'] ?? '').toString().toLowerCase();
        final target = _activeFilter.toLowerCase();
        matchesFilter = tag.contains(target);
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
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Learn • Discuss • Practice',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 22),
            onPressed: _fetchFeedPosts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Ask Doubt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _openCreatePostModal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search mocks, coaching, doubts, topics...',
                  hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: Colors.grey.shade500),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _filters.map((f) {
                final isSel = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeFilter = f),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 2),
          Divider(height: 1, thickness: 0.6, color: dividerColor),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? Center(child: Text('No posts found in this section.', style: TextStyle(color: Colors.grey.shade500)))
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.6, color: dividerColor),
                            itemBuilder: (context, idx) {
                              final item = filteredList[idx];
                              final creator = item['creator_profiles'] ?? {};
                              final attachedMock = item['creator_mocks'];
                              final postId = item['id'];
                              final bool isLiked = _likedPostIds.contains(postId);
                              final int likesCount = item['upvotes'] ?? 0;
                              final String? imgUrl = item['image_url'];
                              final bool isSaved = _savedPostIds.contains(postId);

                              final bool isVerifiedCreator = creator['name'] != null && (item['creator_id'] != 'user');
                              final String authorHandle = (creator['handle_id'] ?? item['creator_id'] ?? 'user').toString();
                              final String authorDisplayName = isVerifiedCreator ? (creator['name'] ?? 'Verified Mentor') : (item['author_name'] ?? 'Aspirant');
                              final String tag = (item['tag'] ?? 'General').toString();

                              return Container(
                                color: bgSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (isVerifiedCreator) _navigateToCreator(authorHandle);
                                      },
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 17,
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
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isVerifiedCreator) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                                                    ],
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '• $tag',
                                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  isVerifiedCreator ? (creator['subject_specialty'] ?? 'Coaching Mentor') : 'Aspirant',
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildRichTextContent(item['content'] ?? ''),

                                    if (tag.toLowerCase().contains('study')) _buildStudyMaterialCard(item['content'] ?? '', isDark),

                                    if (tag.toLowerCase().contains('notice') || tag.toLowerCase().contains('announcement'))
                                      _buildNoticeCard(item['content'] ?? '', isDark),

                                    if (attachedMock != null) _buildMockDiscoveryCard(attachedMock, authorDisplayName, authorHandle, isDark),

                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imgUrl,
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _handleLike(idx),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                                size: 15,
                                                color: isLiked ? const Color(0xFF2563EB) : Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$likesCount',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                                  color: isLiked ? const Color(0xFF2563EB) : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 18),

                                        Row(
                                          children: [
                                            Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text('0', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                        const SizedBox(width: 18),

                                        InkWell(
                                          onTap: () => _toggleBookmark(postId, item),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                                                size: 16,
                                                color: isSaved ? const Color(0xFF2563EB) : Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${item['bookmarks_count'] ?? 0}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSaved ? FontWeight.bold : FontWeight.normal,
                                                  color: isSaved ? const Color(0xFF2563EB) : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),

                                        IconButton(
                                          icon: Icon(Icons.share_outlined, size: 16, color: Colors.grey.shade600),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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

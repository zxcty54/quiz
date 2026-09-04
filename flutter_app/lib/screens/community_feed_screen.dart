import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_telegram_alert.dart';
import '../widgets/community_comments_sheet.dart';
import '../widgets/community_post_card.dart';

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
    'General 💬',
    'Announcement 📢',
    'Saved 📌'
  ];

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _lightCard = Colors.white;
  static const Color _lightDivider = Color(0xFFE2E8F0);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _darkDivider = Color(0xFF334155);

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

    try {
      final savedRes = await Supabase.instance.client
          .from('user_saved_posts')
          .select('post_id')
          .eq('user_handle', _currentLoggedInHandle);

      if (mounted && savedRes != null) {
        setState(() {
          _savedPostIds.clear();
          for (var row in savedRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _savedPostIds.add(pid);
          }
        });
      }
    } catch (_) {}

    try {
      final likesRes = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('user_handle', _currentLoggedInHandle);

      if (mounted && likesRes != null) {
        setState(() {
          _likedPostIds.clear();
          for (var row in likesRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _likedPostIds.add(pid);
          }
        });
      }
    } catch (_) {}

    try {
      final votesRes = await Supabase.instance.client
          .from('poll_votes')
          .select('post_id, option_index')
          .eq('user_handle', _currentLoggedInHandle);

      if (mounted && votesRes != null) {
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

  void _openCommentsSheet(int postId, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? _darkCard : _lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => CommunityCommentsSheet(
        postId: postId,
        post: post,
        currentLoggedInHandle: _currentLoggedInHandle,
        customUserName: _customUserName,
        isDarkMode: widget.isDarkMode,
        buildRichTextContent: (text, {fontSize = 14.5}) => Text(text, style: TextStyle(fontSize: fontSize)),
        onCommentAdded: () => setState(() => post['comments_count'] = (post['comments_count'] ?? 0) + 1),
      ),
    );
  }

  void _openCreatePostModal() {
    final contentCtrl = TextEditingController();
    final bool isCreator = _currentLoggedInHandle != 'user';

    final List<String> availableTags = isCreator
        ? [
            'Mock Tests ⚡',
            'Study Material 📚',
            'Daily Quiz ⚡',
            'Announcement 📢',
            'Doubts ❓',
            'General 💬',
          ]
        : [
            'Doubts ❓',
            'Study Material 📚',
            'General 💬',
          ];

    String selectedTag = 'Doubts ❓';
    File? selectedImage;
    bool isUploading = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? _darkCard : _lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '✍️ Ask Doubt / Post',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()),
                  items: availableTags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                if (selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(selectedImage!, width: double.infinity, height: 140, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 8),
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
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
                    onPressed: isUploading
                        ? null
                        : () async {
                            final text = contentCtrl.text.trim();
                            if (text.isEmpty && selectedImage == null) return;
                            setModalState(() => isUploading = true);

                            try {
                              String? uploadedImageUrl;
                              if (selectedImage != null) {
                                final bytes = await selectedImage!.readAsBytes();
                                final fileExt = selectedImage!.path.split('.').last;
                                final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                                await Supabase.instance.client.storage.from('post_images').uploadBinary(fileName, bytes);
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
                                  const SnackBar(content: Text('⏳ Post submitted for review! It will appear once approved.'), backgroundColor: _primaryBlue),
                                );
                              }
                            } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? _darkBg : _lightBg;
    final dividerColor = isDark ? _darkDivider : _lightDivider;
    final cardSurface = isDark ? _darkCard : _lightCard;

    final filteredList = _posts.where((p) {
      if (_activeFilter == 'Saved 📌') return _savedPostIds.contains(p['id']);
      if (_activeFilter != 'All') {
        final tag = (p['tag'] ?? '').toString().toLowerCase();
        final target = _activeFilter.split(' ').first.toLowerCase();
        if (!tag.contains(target)) return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (p['content'] ?? '').toString().toLowerCase().contains(q) ||
          (p['author_name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: cardSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Community Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : const Color(0xFF334155)), onPressed: _fetchFeedPosts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Post / Doubt', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreatePostModal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: cardSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: '🔍 Search mocks, doubts, topics, mentor...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: _primaryBlue,
                    backgroundColor: cardSurface,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569))),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: isSelected ? _primaryBlue : dividerColor)),
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, thickness: 1, color: dividerColor),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? Center(child: Text('No posts found.', style: TextStyle(color: Colors.grey[500])))
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: dividerColor),
                            itemBuilder: (context, idx) {
                              final item = filteredList[idx];
                              final postId = item['id'];

                              return CommunityPostCard(
                                post: item,
                                currentLoggedInHandle: _currentLoggedInHandle,
                                isLiked: _likedPostIds.contains(postId),
                                isSaved: _savedPostIds.contains(postId),
                                selectedPollIndex: _userPollSelections[postId],
                                isDarkMode: isDark,
                                onOpenComments: () => _openCommentsSheet(postId, item),
                                onLikeToggle: (liked) => setState(() => liked ? _likedPostIds.add(postId) : _likedPostIds.remove(postId)),
                                onBookmarkToggle: (saved) => setState(() => saved ? _savedPostIds.add(postId) : _savedPostIds.remove(postId)),
                                onPollVote: (optIdx) => setState(() => _userPollSelections[postId] = optIdx),
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

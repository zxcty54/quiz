import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../widgets/community_post_card.dart';
import 'post_detail_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final bool isDarkMode;
  const CommunityFeedScreen({super.key, required this.isDarkMode});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _activeFilter = 'All';
  String _activeFeedMode = 'For You';
  List<String> _followedCreatorHandles = [];

  static const List<String> _feedModes = ['For You', 'Latest'];
  String _customUserName = 'Aspirant';
  String _currentLoggedInHandle = 'user';

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  final Set<int> _likedPostIds = {};
  final Set<int> _viewedPostIds = {};
  final Map<int, int> _userPollSelections = {};
  final Set<int> _savedPostIds = {};

  final List<String> _filters = [
    'All',
    'Mock Tests',
    'Study Material',
    'Daily Quiz',
    'Doubts',
    'General',
    'Announcement',
    'Saved'
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
    _scrollController.addListener(_onScroll);
    _initializeFeed();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeFeed() async {
    await _loadUserPreferences();
    if (mounted) await _fetchFeedPosts();
  }

  List<dynamic> _parseRankedPosts(dynamic res) {
    if (res is List) return List<dynamic>.from(res);
    if (res is String) {
      try {
        final decoded = jsonDecode(res);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (_) {}
    }
    return <dynamic>[];
  }

  void _changeFeedMode(String mode) {
    if (_activeFeedMode == mode) return;
    setState(() => _activeFeedMode = mode);
    _fetchFeedPosts();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _fetchMorePosts();
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('custom_aspirant_name') ??
        prefs.getString('full_name') ??
        prefs.getString('user_name') ??
        'Aspirant';

    final creatorHandle = prefs.getString('logged_in_creator_handle');
    final userId = prefs.getString('user_id') ?? 'user';
    final followedCreators = prefs.getStringList('followed_creators') ?? [];

    final activeHandle = (creatorHandle != null && creatorHandle.trim().isNotEmpty)
        ? creatorHandle.trim()
        : userId.trim();

    if (mounted) {
      setState(() {
        _customUserName = name;
        _currentLoggedInHandle = activeHandle;
        _followedCreatorHandles = followedCreators;
      });
    }

    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('user_saved_posts')
            .select('post_id')
            .eq('user_handle', _currentLoggedInHandle),
        Supabase.instance.client
            .from('post_likes')
            .select('post_id')
            .eq('user_handle', _currentLoggedInHandle),
        Supabase.instance.client
            .from('poll_votes')
            .select('post_id, option_index')
            .eq('user_handle', _currentLoggedInHandle),
      ]);

      final savedRes = results[0] as List<dynamic>? ?? [];
      final likesRes = results[1] as List<dynamic>? ?? [];
      final votesRes = results[2] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _savedPostIds.clear();
          for (var row in savedRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _savedPostIds.add(pid);
          }

          _likedPostIds.clear();
          for (var row in likesRes) {
            final pid = int.tryParse(row['post_id'].toString());
            if (pid != null) _likedPostIds.add(pid);
          }

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
    } catch (e) {
      debugPrint("Parallel fetch error: $e");
    }
  }

  // Initial Load (First 20 posts)
  Future<void> _fetchFeedPosts() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
    });

    try {
      List<dynamic> fetchedPosts;

      // Dono mode ek hi SQL function se aate hain. For You = ranked,
      // Latest = sirf latest pehle. Isse dono me creator info aur sahi
      // comments/likes count milta hai.
      final res = await Supabase.instance.client.rpc(
        'get_ranked_community_feed',
        params: {
          'p_user_handle': _currentLoggedInHandle,
          'p_followed_handles': _followedCreatorHandles,
          'p_limit': _pageSize,
          'p_offset': 0,
          'p_mode': _activeFeedMode == 'Latest' ? 'latest' : 'for_you',
          'p_search': _searchQuery.isEmpty ? null : _searchQuery,
        },
      );
      fetchedPosts = _parseRankedPosts(res);

      if (mounted) {
        setState(() {
          _posts = fetchedPosts;
          _isLoading = false;
          if (fetchedPosts.length < _pageSize) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      debugPrint(">>> Feed Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Lazy Load Next Page (Agla batch)
  Future<void> _fetchMorePosts() async {
    setState(() => _isLoadingMore = true);

    final start = _posts.length;

    try {
      List<dynamic> fetchedPosts;

      final res = await Supabase.instance.client.rpc(
        'get_ranked_community_feed',
        params: {
          'p_user_handle': _currentLoggedInHandle,
          'p_followed_handles': _followedCreatorHandles,
          'p_limit': _pageSize,
          'p_offset': start,
          'p_mode': _activeFeedMode == 'Latest' ? 'latest' : 'for_you',
          'p_search': _searchQuery.isEmpty ? null : _searchQuery,
        },
      );
      fetchedPosts = _parseRankedPosts(res);

      if (mounted) {
        setState(() {
          _posts.addAll(fetchedPosts);
          _isLoadingMore = false;
          if (fetchedPosts.length < _pageSize) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      debugPrint(">>> Fetch More Error: $e");
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Search ab server par hota hai. Har akshar par load na mare,
  /// isliye aadhe second ruk kar hi fresh results laate hain.
  void _scheduleSearch(String val) {
    final q = val.trim();
    setState(() => _searchQuery = q);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _fetchFeedPosts();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    if (_searchQuery.isEmpty) return;
    setState(() => _searchQuery = '');
    _fetchFeedPosts();
  }

  Future<void> _handlePostViewed(int postId) async {
    // Ek app session me ek post ka view sirf ek baar count hoga.
    if (_viewedPostIds.contains(postId)) return;
    _viewedPostIds.add(postId);

    Map<String, dynamic>? targetPost;
    for (final item in _posts) {
      if (item is Map && item['id']?.toString() == postId.toString()) {
        // Cast view original map ko hi point karta hai, isliye count update
        // feed ke usi post object me dikhega.
        targetPost = item.cast<String, dynamic>();
        break;
      }
    }
    if (targetPost == null) return;

    // Apni khud ki post dekhne par view count nahi badhega.
    if ((targetPost['creator_id'] ?? '').toString() == _currentLoggedInHandle) return;

    try {
      final res = await Supabase.instance.client.rpc(
        'increment_post_view',
        params: {'p_post_id': postId},
      );
      final serverCount = int.tryParse(res?.toString() ?? '');
      targetPost['views_count'] = serverCount ??
          ((int.tryParse(targetPost['views_count']?.toString() ?? '') ?? 0) + 1);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Post view count failed: $e');
      _viewedPostIds.remove(postId);
    }
  }

  void _openPostDetail(Map<String, dynamic> post) {
    final postId = int.tryParse(post['id']?.toString() ?? '');
    if (postId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          currentLoggedInHandle: _currentLoggedInHandle,
          customUserName: _customUserName,
          isDarkMode: widget.isDarkMode,
          initialLiked: _likedPostIds.contains(postId),
          initialSaved: _savedPostIds.contains(postId),
          initialPollIndex: _userPollSelections[postId],
          onPostViewed: _handlePostViewed,
          onLikeToggle: (liked) {
            if (!mounted) return;
            setState(() {
              if (liked) {
                _likedPostIds.add(postId);
              } else {
                _likedPostIds.remove(postId);
              }
            });
          },
          onBookmarkToggle: (saved) {
            if (!mounted) return;
            setState(() {
              if (saved) {
                _savedPostIds.add(postId);
              } else {
                _savedPostIds.remove(postId);
              }
            });
          },
          onPollVote: (optIdx) {
            _userPollSelections[postId] = optIdx;
          },
          onPostDeleted: _fetchFeedPosts,
          onPostChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _openCreatePostModal() {
    final contentCtrl = TextEditingController();
    final bool isCreator = _currentLoggedInHandle.isNotEmpty &&
        !_currentLoggedInHandle.startsWith('usr_') &&
        _currentLoggedInHandle != 'user';

    final List<String> availableTags = isCreator
        ? [
            'Mock Tests',
            'Study Material',
            'Daily Quiz',
            'Announcement',
            'Doubts',
            'General',
          ]
        : [
            'Doubts',
            'Study Material',
            'General',
          ];

    String selectedTag = 'Doubts';
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
                      'Ask Doubt / Post',
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDarkMode ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTag == tag;
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: _primaryBlue,
                        backgroundColor: widget.isDarkMode ? _darkCard : Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (widget.isDarkMode ? Colors.white70 : const Color(0xFF475569)),
                        ),
                        onSelected: (selected) {
                          if (selected) setModalState(() => selectedTag = tag);
                        },
                      );
                    }).toList(),
                  ),
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

                              await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': _currentLoggedInHandle.isNotEmpty ? _currentLoggedInHandle : 'user',
                                'author_name': _customUserName,
                                'content': text,
                                'tag': selectedTag,
                                'image_url': uploadedImageUrl,
                                'is_approved': true,
                                'views_count': 1,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              });

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _fetchFeedPosts();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Post published successfully!'),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            } catch (err) {
                              debugPrint("Post creation failed: $err");
                              setModalState(() => isUploading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $err'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    child: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Publish Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _buildFeedModeTabs(Color cardSurface, Color dividerColor, bool isDark) {
    return Container(
      color: cardSurface,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: _feedModes.map((mode) {
          final isSelected = _activeFeedMode == mode;
          return Expanded(
            child: InkWell(
              onTap: () => _changeFeedMode(mode),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      width: 46,
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkeletonFeed(bool isDark) {
    final base = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);
    final block = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(99),
          ),
        );

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? _darkDivider : _lightDivider,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: block, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(120, 11), const SizedBox(height: 7), bar(82, 9)],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              bar(double.infinity, 12),
              const SizedBox(height: 8),
              bar(230, 12),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [bar(34, 12), bar(34, 12), bar(34, 12), bar(34, 12)],
              ),
            ],
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
      if (_activeFilter == 'Saved') return _savedPostIds.contains(p['id']);

      if (_activeFilter != 'All') {
        final postTag = (p['tag'] ?? '').toString().toLowerCase();
        final cleanPostTag = postTag.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        final cleanFilter = _activeFilter.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (!cleanPostTag.contains(cleanFilter) && !cleanFilter.contains(cleanPostTag)) return false;
      }

      return true; // Search server-side hai; yahan sirf category/Saved filter hai.
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: cardSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Community Feed',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : const Color(0xFF334155)),
            onPressed: _fetchFeedPosts,
          ),
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
          _buildFeedModeTabs(cardSurface, dividerColor, isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dividerColor),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onChanged: _scheduleSearch,
                decoration: InputDecoration(
                  hintText: 'Search mocks, doubts, topics, mentor...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[500]),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: _clearSearch,
                        ),
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
                    label: Text(
                      f,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _primaryBlue,
                    backgroundColor: cardSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                      side: BorderSide(color: isSelected ? _primaryBlue : dividerColor),
                    ),
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, thickness: 1, color: dividerColor),
          if (!_isLoading && _searchQuery.isEmpty && _activeFilter == 'All')
            Builder(builder: (_) {
              final pending = _posts.where((post) {
                final tag = (post['tag'] ?? '').toString().toLowerCase();
                final comments = (post['comments_count'] as num?)?.toInt() ?? 0;
                return tag.contains('doubt') && comments == 0;
              }).length;
              if (pending == 0) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.16 : 0.10),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline_rounded, size: 17, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$pending doubts waiting for answers',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _activeFilter = 'Doubts'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Comment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          Expanded(
            child: _isLoading
                ? _buildSkeletonFeed(isDark)
                : RefreshIndicator(
                    onRefresh: _fetchFeedPosts,
                    child: filteredList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 44, color: Colors.grey[400]),
                                  const SizedBox(height: 10),
                                  Text(
                                    (_searchQuery.isNotEmpty || _activeFilter != 'All')
                                        ? 'No posts match your search/filter.'
                                        : 'No posts yet. Start the first discussion!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_searchQuery.isNotEmpty || _activeFilter != 'All')
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() => _activeFilter = 'All');
                                        _clearSearch();
                                      },
                                      icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
                                      label: const Text('Clear search & filters'),
                                    ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryBlue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _openCreatePostModal,
                                    icon: const Icon(Icons.edit_rounded, size: 17),
                                    label: const Text('Post / Doubt'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 90),
                            // +1 extra slot for bottom loading spinner
                            itemCount: filteredList.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: dividerColor),
                            itemBuilder: (context, idx) {
                              if (idx == filteredList.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }

                              final item = filteredList[idx];
                              final postId = item['id'];

                              return CommunityPostCard(
                                post: item,
                                currentLoggedInHandle: _currentLoggedInHandle,
                                isLiked: _likedPostIds.contains(postId),
                                isSaved: _savedPostIds.contains(postId),
                                selectedPollIndex: _userPollSelections[postId],
                                isDarkMode: isDark,
                                onOpenComments: () => _openPostDetail(item),
                                onPostViewed: _handlePostViewed,
                                onLikeToggle: (liked) {
                                  if (liked) {
                                    _likedPostIds.add(postId);
                                  } else {
                                    _likedPostIds.remove(postId);
                                  }
                                },
                                onBookmarkToggle: (saved) {
                                  if (saved) {
                                    _savedPostIds.add(postId);
                                  } else {
                                    _savedPostIds.remove(postId);
                                  }
                                  if (_activeFilter == 'Saved' && mounted) {
                                    setState(() {});
                                  }
                                },
                                onPollVote: (optIdx) => _userPollSelections[postId] = optIdx,
                                onPostDeleted: _fetchFeedPosts,
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

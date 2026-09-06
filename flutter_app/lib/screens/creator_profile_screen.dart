import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'creator_profile_header.dart';
import 'creator_profile_tabs.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorProfileScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _coaching;
  List<dynamic> _batches = [];
  List<dynamic> _mocks = [];
  List<dynamic> _selections = [];
  List<dynamic> _galleryImages = [];

  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _lightDivider = Color(0xFFE2E8F0);
  static const Color _darkDivider = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _fetchProfileAndCoaching();

    await Future.wait([
      _fetchBatches(),
      _fetchMocks(),
      _fetchSelections(),
      _checkFollowStatus(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProfileAndCoaching() async {
    try {
      final client = Supabase.instance.client;
      final handle = widget.creatorHandle.trim();

      final profRes = await client
          .from('creator_profiles')
          .select('*')
          .eq('handle_id', handle)
          .maybeSingle();

      if (profRes != null) {
        _profile = profRes;
        _followersCount = profRes['followers_count'] ?? 0;
      }

      dynamic coachRes = await client
          .from('coachings')
          .select('*')
          .ilike('owner_name', handle)
          .maybeSingle();

      coachRes ??= await client
          .from('coachings')
          .select('*')
          .ilike('creator_handle', handle)
          .maybeSingle();

      _coaching = coachRes;

      if (_coaching != null) {
        _galleryImages = (_coaching!['gallery_images'] as List?) ?? [];
      }
    } catch (e) {
      debugPrint("Profile fetch error: $e");
    }
  }

  Future<void> _fetchBatches() async {
    try {
      if (_coaching == null) return;
      final coachingId = _coaching!['id'];

      final res = await Supabase.instance.client
          .from('batches')
          .select('*')
          .eq('coaching_id', coachingId)
          .neq('status', 'HIDDEN')
          .order('created_at', ascending: false);

      _batches = res ?? [];
    } catch (e) {
      debugPrint("Batches fetch error: $e");
    }
  }

  Future<void> _fetchMocks() async {
    try {
      final res = await Supabase.instance.client
          .from('creator_mocks')
          .select('*')
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      _mocks = res ?? [];
    } catch (e) {
      debugPrint("Mocks fetch error: $e");
    }
  }

  Future<void> _fetchSelections() async {
    try {
      if (_coaching == null) return;
      final coachingId = _coaching!['id'];

      final res = await Supabase.instance.client
          .from('coaching_selections')
          .select('*')
          .eq('coaching_id', coachingId)
          .order('created_at', ascending: false);

      _selections = res ?? [];
    } catch (e) {
      debugPrint("Selections fetch error: $e");
    }
  }

  Future<void> _checkFollowStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final followedList = prefs.getStringList('followed_creators') ?? [];
    _isFollowing = followedList.contains(widget.creatorHandle);
  }

  Future<void> _toggleFollow() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final followedList = prefs.getStringList('followed_creators') ?? [];

    setState(() {
      if (_isFollowing) {
        _isFollowing = false;
        _followersCount = (_followersCount - 1).clamp(0, 999999);
        followedList.remove(widget.creatorHandle);
      } else {
        _isFollowing = true;
        _followersCount += 1;
        followedList.add(widget.creatorHandle);
      }
    });

    await prefs.setStringList('followed_creators', followedList);

    try {
      await Supabase.instance.client
          .from('creator_profiles')
          .update({'followers_count': _followersCount})
          .eq('handle_id', widget.creatorHandle);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? _darkBg : _lightBg;
    final cardSurface = isDark ? _darkCard : Colors.white;
    final dividerColor = isDark ? _darkDivider : _lightDivider;

    final bannerUrl = _coaching?['banner_url'] ?? _profile?['banner_url'];

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgSurface,
        appBar: AppBar(backgroundColor: bgSurface, elevation: 0),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: bgSurface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: isDark ? _darkCard : Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: bannerUrl != null && bannerUrl.toString().trim().isNotEmpty
                    ? Image.network(bannerUrl.toString().trim(), fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _primaryBlue.withOpacity(0.85),
                              const Color(0xFF1E3A8A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: CreatorProfileHeader(
                profile: _profile,
                coaching: _coaching,
                handle: widget.creatorHandle,
                isDarkMode: isDark,
                isFollowing: _isFollowing,
                followersCount: _followersCount,
                batchesCount: _batches.length,
                mocksCount: _mocks.length,
                selectionsCount: _selections.length,
                onToggleFollow: _toggleFollow,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabHeaderDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: _primaryBlue,
                  indicatorWeight: 2.8,
                  labelColor: isDark ? Colors.white : _primaryBlue,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Batches (${_batches.length})'),
                    Tab(text: 'Free Mocks (${_mocks.length})'),
                    Tab(text: 'Wall of Fame (${_selections.length})'),
                    const Tab(text: 'About & Campus'),
                  ],
                ),
                cardSurface,
                dividerColor,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            CreatorBatchesTab(batches: _batches, isDarkMode: isDark),
            CreatorFreeMocksTab(mocks: _mocks, isDarkMode: isDark),
            CreatorWallOfFameTab(selections: _selections, isDarkMode: isDark),
            CreatorAboutCampusTab(
              profile: _profile,
              coaching: _coaching,
              galleryImages: _galleryImages,
              isDarkMode: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _bgColor;
  final Color _dividerColor;

  _SliverTabHeaderDelegate(this._tabBar, this._bgColor, this._dividerColor);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bgColor,
      child: Column(
        children: [
          _tabBar,
          Divider(height: 1, thickness: 1, color: _dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) => false;
}

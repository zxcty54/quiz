import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';

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
  List<dynamic> _updates = [];

  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  String _currentLoggedInHandle = 'user';

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _lightDivider = Color(0xFFE2E8F0);
  static const Color _darkDivider = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLoggedInHandle = prefs.getString('logged_in_creator_handle') ?? 'user';

    await Future.wait([
      _fetchProfileAndStats(),
      _fetchBatches(),
      _fetchMocks(),
      _fetchUpdates(),
      _checkFollowStatus(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProfileAndStats() async {
    try {
      final profRes = await Supabase.instance.client
          .from('creator_profiles')
          .select('*')
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      if (profRes != null) {
        _profile = profRes;
        _followersCount = profRes['followers_count'] ?? 0;

        final coachRes = await Supabase.instance.client
            .from('coachings')
            .select('*')
            .eq('creator_handle', widget.creatorHandle)
            .maybeSingle();

        _coaching = coachRes;
      }
    } catch (e) {
      debugPrint("Profile fetch error: $e");
    }
  }

  Future<void> _fetchBatches() async {
    try {
      final res = await Supabase.instance.client
          .from('batches')
          .select('*')
          .eq('creator_handle', widget.creatorHandle)
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

  Future<void> _fetchUpdates() async {
    try {
      final res = await Supabase.instance.client
          .from('community_posts')
          .select('*')
          .eq('creator_id', widget.creatorHandle)
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      _updates = res ?? [];
    } catch (e) {
      debugPrint("Updates fetch error: $e");
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Mock Drill',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  void _openTelegram(String? urlOrHandle) async {
    if (urlOrHandle == null || urlOrHandle.isEmpty) return;
    String cleanUrl = urlOrHandle.startsWith('http')
        ? urlOrHandle
        : 'https://t.me/${urlOrHandle.replaceAll('@', '')}';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openUnlockBatchDialog(Map<String, dynamic> batch) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          batch['title'] ?? 'Unlock Classroom Batch',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the classroom admission code provided by your coaching mentor:',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. BPSC2026',
                labelText: 'Batch Secret Code',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final entered = codeCtrl.text.trim();
              final actual = (batch['access_code'] ?? '').toString().trim();
              Navigator.pop(ctx);

              if (entered.isNotEmpty && entered.toUpperCase() == actual.toUpperCase()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Batch Unlocked Successfully!'),
                    backgroundColor: Color(0xFF16A34A),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect Batch Code. Please contact coaching.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Unlock Batch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? _darkBg : _lightBg;
    final cardSurface = isDark ? _darkCard : Colors.white;
    final dividerColor = isDark ? _darkDivider : _lightDivider;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgSurface,
        appBar: AppBar(backgroundColor: bgSurface, elevation: 0),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final name = _coaching?['coaching_name'] ?? _profile?['name'] ?? 'Educator';
    final handle = widget.creatorHandle;
    final specialty = _profile?['subject_specialty'] ?? 'Exam Mentor';
    final district = _coaching?['district'] ?? 'Bihar';
    final landmark = _coaching?['landmark'];
    final logoUrl = _coaching?['logo_url'] ?? _profile?['profile_image'];
    final bannerUrl = _coaching?['banner_url'] ?? _profile?['banner_url'];
    final telegram = _profile?['telegram_handle'] ?? _coaching?['telegram_link'];

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
                background: bannerUrl != null && bannerUrl.toString().isNotEmpty
                    ? Image.network(bannerUrl, fit: BoxFit.cover)
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
              child: Container(
                color: cardSurface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardSurface,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: _primaryBlue,
                            backgroundImage: (logoUrl != null && logoUrl.toString().isNotEmpty)
                                ? NetworkImage(logoUrl)
                                : null,
                            child: (logoUrl == null || logoUrl.toString().isEmpty)
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _isFollowing ? _primaryBlue : Colors.transparent,
                              foregroundColor: _isFollowing ? Colors.white : _primaryBlue,
                              side: const BorderSide(color: _primaryBlue, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: Icon(
                              _isFollowing ? Icons.check_rounded : Icons.add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: _toggleFollow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.verified, size: 17, color: _primaryBlue),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$handle',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            landmark != null && landmark.toString().isNotEmpty
                                ? '$landmark, $district'
                                : '$district, Bihar',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatBlock('$_followersCount', 'Followers'),
                        const SizedBox(width: 28),
                        _buildStatBlock('${_batches.length}', 'Batches'),
                        const SizedBox(width: 28),
                        _buildStatBlock('${_mocks.length}', 'Open Mocks'),
                      ],
                    ),
                    if (telegram != null && telegram.toString().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => _openTelegram(telegram),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A).withOpacity(0.3)
                                : const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFFBAE6FD),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.near_me_rounded, color: Color(0xFF0284C7), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Join Official Telegram Channel',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF0284C7)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    Tab(text: 'Batches (${_batches.length})'),
                    Tab(text: 'Mocks (${_mocks.length})'),
                    Tab(text: 'Updates (${_updates.length})'),
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
            _buildBatchesTab(cardSurface, dividerColor, isDark),
            _buildMocksTab(cardSurface, dividerColor, isDark),
            _buildUpdatesTab(cardSurface, dividerColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _buildBatchesTab(Color cardSurface, Color dividerColor, bool isDark) {
    if (_batches.isEmpty) {
      return Center(
        child: Text('No active batches listed yet.', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _batches.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
      itemBuilder: (context, idx) {
        final b = _batches[idx];
        final bool isLocked = (b['is_locked'] ?? true) == true;

        return Container(
          color: cardSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      b['title'] ?? 'Classroom Batch',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey.withOpacity(0.12)
                          : const Color(0xFF16A34A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                          size: 12,
                          color: isLocked ? Colors.grey[600] : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isLocked ? 'LOCKED' : 'UNLOCKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? Colors.grey[600] : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                b['description'] ?? 'Curated Private CBT Mock Drills & Daily Classroom Handouts',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryBlue,
                    side: const BorderSide(color: _primaryBlue, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openUnlockBatchDialog(b),
                  child: const Text('Unlock Classroom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMocksTab(Color cardSurface, Color dividerColor, bool isDark) {
    if (_mocks.isEmpty) {
      return Center(
        child: Text('No open practice mocks available.', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _mocks.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
      itemBuilder: (context, idx) {
        final m = _mocks[idx];
        final totalQs = (m['questions_json'] as List?)?.length ?? 0;
        final duration = m['duration_mins'] ?? 15;
        final attempts = m['attempts_count'] ?? 0;

        return Container(
          color: cardSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (m['subject'] ?? 'General').toString().toUpperCase(),
                      style: const TextStyle(color: _primaryBlue, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '$attempts attempts',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m['title'] ?? 'Practice Mock Test',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalQs Questions • $duration mins • Instant Result',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _launchAttachedMock(m),
                  child: const Text('Start Mock →', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdatesTab(Color cardSurface, Color dividerColor, bool isDark) {
    if (_updates.isEmpty) {
      return Center(
        child: Text('No community updates posted yet.', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _updates.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
      itemBuilder: (context, idx) {
        final p = _updates[idx];
        final String? imgUrl = p['image_url'];
        final tag = p['tag'] ?? 'Update';

        return Container(
          color: cardSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag.toString().toUpperCase(),
                      style: const TextStyle(color: _primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p['content'] ?? '',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                ),
              ),
              if (imgUrl != null && imgUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) {
    return false;
  }
}

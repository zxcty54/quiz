import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import 'batch_classroom_screen.dart';
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
  List<dynamic> _selections = [];
  List<dynamic> _galleryImages = [];
  List<dynamic> _facultyList = [];

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
    debugPrint("🔍 [PROFILE] Loading data for handle: ${widget.creatorHandle}");
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

      // 1. Fetch Creator Profile
      final profRes = await client
          .from('creator_profiles')
          .select('*')
          .eq('handle_id', handle)
          .maybeSingle();

      if (profRes != null) {
        _profile = profRes;
        _followersCount = profRes['followers_count'] ?? 0;
      }

      // 2. Fetch Coaching Row
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
        _facultyList = (_coaching!['faculty_list'] as List?) ?? [];
      }
    } catch (e, stack) {
      debugPrint("🔥 [ERROR] Profile/Coaching fetch error: $e\n$stack");
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
      debugPrint("🔥 [ERROR] Batches fetch error: $e");
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
      debugPrint("🔥 [ERROR] Mocks fetch error: $e");
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
      debugPrint("🔥 [ERROR] Selections fetch error: $e");
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
    } catch (e) {
      debugPrint("🔥 [ERROR] Follow update error: $e");
    }
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

  void _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openDialer(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _openWhatsApp(String phone) async {
    try {
      String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!cleanNumber.startsWith('91') && cleanNumber.length == 10) {
        cleanNumber = '91$cleanNumber';
      }
      final uri = Uri.parse(
          'https://wa.me/$cleanNumber?text=Hello,%20I%20want%20information%20regarding%20batches.');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openUnlockBatchDialog(Map<String, dynamic> batch) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          batch['batch_name'] ?? 'Unlock Classroom Batch',
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
                hintText: 'e.g. 111',
                labelText: 'Batch Secret Code',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final entered = codeCtrl.text.trim();
              final actual = (batch['batch_code'] ?? '').toString().trim();
              Navigator.pop(ctx);

              if (entered.isNotEmpty &&
                  entered.toUpperCase() == actual.toUpperCase()) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('unlocked_batch_${batch['id']}', true);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Batch Unlocked! Entering Classroom...'),
                    backgroundColor: Color(0xFF16A34A),
                    duration: Duration(seconds: 1),
                  ),
                );

                setState(() {});

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchClassroomScreen(
                      batchData: batch,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Incorrect Batch Code. Please contact coaching.'),
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

    final name = _coaching?['name'] ?? _profile?['name'] ?? 'Educator';
    final handle = widget.creatorHandle;
    final specialty = _profile?['subject_specialty'] ?? _coaching?['tagline'] ?? 'Exam Guidance Hub';
    final district = _coaching?['district'] ?? _coaching?['city'] ?? 'Bihar';
    final landmark = _coaching?['landmark_address'] ?? _coaching?['landmark'];
    final logoUrl = _coaching?['logo_url'] ?? _profile?['profile_image'];
    final bannerUrl = _coaching?['banner_url'] ?? _profile?['banner_url'];

    // Social Links
    final contactPhone = _coaching?['phone'] ?? _coaching?['contact_number'];
    final telegram = _coaching?['telegram_link'] ?? _profile?['telegram_handle'];
    final youtube = _coaching?['youtube_url'] ?? _profile?['youtube_handle'];
    final facebook = _coaching?['facebook_url'] ?? _profile?['facebook_handle'];
    final website = _coaching?['website_url'];

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
                            backgroundImage: (logoUrl != null &&
                                    logoUrl.toString().isNotEmpty)
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
                              backgroundColor: _isFollowing
                                  ? _primaryBlue
                                  : Colors.transparent,
                              foregroundColor:
                                  _isFollowing ? Colors.white : _primaryBlue,
                              side: const BorderSide(
                                  color: _primaryBlue, width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            icon: Icon(
                              _isFollowing
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
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
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            landmark != null && landmark.toString().isNotEmpty
                                ? '$landmark, $district'
                                : '$district, Bihar',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[300]
                                  : const Color(0xFF475569),
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

                    // Quick Stats
                    Row(
                      children: [
                        _buildStatBlock('$_followersCount', 'Followers'),
                        const SizedBox(width: 24),
                        _buildStatBlock('${_batches.length}', 'Batches'),
                        const SizedBox(width: 24),
                        _buildStatBlock('${_mocks.length}', 'Open Mocks'),
                        const SizedBox(width: 24),
                        _buildStatBlock('${_selections.length}', 'Selections 🎓'),
                      ],
                    ),

                    // 🌐 Complete Social & Contact Hub
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (contactPhone != null &&
                            contactPhone.toString().trim().isNotEmpty) ...[
                          _buildSocialPill(
                            icon: Icons.phone_outlined,
                            label: 'Call',
                            iconColor: const Color(0xFF16A34A),
                            dividerColor: dividerColor,
                            onTap: () => _openDialer(contactPhone.toString()),
                          ),
                          _buildSocialPill(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'WhatsApp',
                            iconColor: const Color(0xFF25D366),
                            dividerColor: dividerColor,
                            onTap: () => _openWhatsApp(contactPhone.toString()),
                          ),
                        ],
                        if (telegram != null &&
                            telegram.toString().trim().isNotEmpty)
                          _buildSocialPill(
                            icon: Icons.near_me_rounded,
                            label: 'Telegram',
                            iconColor: const Color(0xFF0284C7),
                            dividerColor: dividerColor,
                            onTap: () {
                              final tg = telegram.toString().trim();
                              final url = tg.startsWith('http')
                                  ? tg
                                  : 'https://t.me/${tg.replaceAll('@', '')}';
                              _openExternalUrl(url);
                            },
                          ),
                        if (youtube != null &&
                            youtube.toString().trim().isNotEmpty)
                          _buildSocialPill(
                            icon: Icons.smart_display_outlined,
                            label: 'YouTube',
                            iconColor: const Color(0xFFEF4444),
                            dividerColor: dividerColor,
                            onTap: () {
                              final yt = youtube.toString().trim();
                              final url = yt.startsWith('http')
                                  ? yt
                                  : 'https://youtube.com/${yt.startsWith('@') ? yt : "@$yt"}';
                              _openExternalUrl(url);
                            },
                          ),
                        if (facebook != null &&
                            facebook.toString().trim().isNotEmpty)
                          _buildSocialPill(
                            icon: Icons.facebook_rounded,
                            label: 'Facebook',
                            iconColor: const Color(0xFF1877F2),
                            dividerColor: dividerColor,
                            onTap: () {
                              final fb = facebook.toString().trim();
                              final url = fb.startsWith('http')
                                  ? fb
                                  : 'https://facebook.com/$fb';
                              _openExternalUrl(url);
                            },
                          ),
                        if (website != null &&
                            website.toString().trim().isNotEmpty)
                          _buildSocialPill(
                            icon: Icons.language_rounded,
                            label: 'Website',
                            iconColor: _primaryBlue,
                            dividerColor: dividerColor,
                            onTap: () {
                              final web = website.toString().trim();
                              final url = web.startsWith('http')
                                  ? web
                                  : 'https://$web';
                              _openExternalUrl(url);
                            },
                          ),
                      ],
                    ),
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
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Batches (${_batches.length})'),
                    Tab(text: 'Mocks (${_mocks.length})'),
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
            _buildBatchesTab(cardSurface, dividerColor, isDark),
            _buildMocksTab(cardSurface, dividerColor, isDark),
            _buildWallOfFameTab(cardSurface, dividerColor, isDark),
            _buildAboutCampusTab(cardSurface, dividerColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialPill({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color dividerColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: dividerColor, width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
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

  // 📦 Batches Tab with Fee Pricing Badges
  Widget _buildBatchesTab(Color cardSurface, Color dividerColor, bool isDark) {
    if (_batches.isEmpty) {
      return Center(
        child: Text('No active batches listed yet.',
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _batches.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, thickness: 0.8, color: dividerColor),
          itemBuilder: (context, idx) {
            final b = _batches[idx];
            final String batchId = b['id']?.toString() ?? '';
            final bool isUnlocked =
                prefs?.getBool('unlocked_batch_$batchId') ?? false;

            final feeType = (b['fee_type'] ?? 'FREE').toString().toUpperCase();
            final feeDesc = b['fee_description']?.toString();

            return Container(
              color: cardSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          b['batch_name'] ?? 'Classroom Batch',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 🏷️ Fee Model Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: feeType == 'FREE'
                              ? const Color(0xFF16A34A).withOpacity(0.12)
                              : const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          feeDesc != null && feeDesc.isNotEmpty
                              ? feeDesc
                              : (feeType == 'FREE'
                                  ? 'FREE BATCH'
                                  : 'OFFLINE FEE'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: feeType == 'FREE'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Unlocked / Locked Status Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? const Color(0xFF16A34A).withOpacity(0.12)
                              : Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUnlocked
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_outline_rounded,
                              size: 11,
                              color: isUnlocked
                                  ? const Color(0xFF16A34A)
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isUnlocked ? 'UNLOCKED' : 'LOCKED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked
                                  ? const Color(0xFF16A34A)
                                  : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b['target_pattern'] ??
                        'Based on standard examination pattern',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: isUnlocked
                        ? ElevatedButton.icon(
                            icon:
                                const Icon(Icons.meeting_room_rounded, size: 15),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BatchClassroomScreen(
                                    batchData: b,
                                    isDarkMode: isDark,
                                  ),
                                ),
                              );
                            },
                            label: const Text(
                              'Enter Classroom 🚀',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.vpn_key_rounded, size: 14),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryBlue,
                              side: const BorderSide(
                                  color: _primaryBlue, width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _openUnlockBatchDialog(b),
                            label: const Text(
                              'Unlock with Code',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMocksTab(Color cardSurface, Color dividerColor, bool isDark) {
    if (_mocks.isEmpty) {
      return Center(
        child: Text('No open practice mocks available.',
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _mocks.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 0.8, color: dividerColor),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (m['subject'] ?? 'General').toString().toUpperCase(),
                      style: const TextStyle(
                          color: _primaryBlue,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('$attempts attempts',
                      style:
                          TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m['title'] ?? 'Practice Mock Test',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _launchAttachedMock(m),
                  child: const Text('Start Mock →',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWallOfFameTab(
      Color cardSurface, Color dividerColor, bool isDark) {
    if (_selections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.military_tech_outlined,
                  size: 40, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text(
                'No student selections listed yet.',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Coaching will showcase its star achievers and success results here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _selections.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 0.8, color: dividerColor),
      itemBuilder: (context, idx) {
        final s = _selections[idx];
        final name = s['student_name'] ?? 'Candidate';
        final post = s['post_cleared'] ?? 'Officer';
        final exam = s['target_exam'] ?? 'Competitive Exam';
        final quote = s['testimonial_text'] ?? '';
        final isVerified = s['is_verified'] == true;

        return Container(
          color: cardSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF16A34A).withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 14, color: Color(0xFF16A34A)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$post • $exam',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue),
                    ),
                    if (quote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '“$quote”',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? Colors.grey[300]
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🏛️ About, Star Faculty, Campus Photos & Details
  Widget _buildAboutCampusTab(
      Color cardSurface, Color dividerColor, bool isDark) {
    final aboutText = _coaching?['description'] ??
        _profile?['bio'] ??
        'Premier preparation institute providing focused guidance and test series for competitive exams.';
    final fullAddress = _coaching?['landmark_address'] ??
        _coaching?['landmark'] ??
        'Bihar, India';
    final establishedYear = _coaching?['established_year'] ?? 'Active';

    return SingleChildScrollView(
      child: Container(
        color: cardSurface,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About the Institute',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              aboutText,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 20),

            // 👨‍🏫 Star Mentors & Faculty Members List
            if (_facultyList.isNotEmpty) ...[
              const Text(
                'Star Mentors & Faculty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 105,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _facultyList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final f = _facultyList[i];
                    final fName = f['name'] ?? 'Mentor';
                    final fSubj = f['subject'] ?? 'General Studies';
                    final fExp = f['exp'] ?? '';
                    final fPhoto = f['photo_url'];

                    return Container(
                      width: 175,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? _darkBg : _lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: dividerColor, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _primaryBlue.withOpacity(0.15),
                            backgroundImage: (fPhoto != null &&
                                    fPhoto.toString().isNotEmpty)
                                ? NetworkImage(fPhoto.toString())
                                : null,
                            child: (fPhoto == null ||
                                    fPhoto.toString().isEmpty)
                                ? Text(
                                    fName.isNotEmpty ? fName[0].toUpperCase() : 'M',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _primaryBlue,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fSubj,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (fExp.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    fExp,
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[500]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 🏛️ Classroom & Facilities Photos
            if (_galleryImages.isNotEmpty) ...[
              const Text(
                'Classroom & Campus Facilities',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _galleryImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _galleryImages[i].toString(),
                        width: 180,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 180,
                          color: Colors.grey.withOpacity(0.1),
                          child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            Divider(height: 1, thickness: 0.8, color: dividerColor),
            const SizedBox(height: 14),
            _buildInfoRow(
                Icons.pin_drop_outlined, 'Address', fullAddress, isDark),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today_outlined, 'Serving Since',
                establishedYear.toString(), isDark),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.shield_outlined, 'Status',
                'Registered Coaching Centre', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _primaryBlue),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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

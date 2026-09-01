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

class _CreatorProfileScreenState extends State<CreatorProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _coachingData;
  List<dynamic> _mocks = [];
  List<dynamic> _posts = [];
  List<dynamic> _batches = [];
  bool _isLoading = true;
  bool _isCreator = false;
  bool _isFollowing = false;
  String? _userEnrolledCode;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _fetchCreatorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCreatorData() async {
    try {
      final client = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      _userEnrolledCode = prefs.getString('user_enrolled_batch_code');

      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      final coachingRes = await client
          .from('coachings')
          .select()
          .eq('owner_name', widget.creatorHandle)
          .maybeSingle();

      if (profileRes != null) {
        _isCreator = true;
        _profile = profileRes;
        _coachingData = coachingRes;

        final mocksRes = await client
            .from('creator_mocks')
            .select()
            .eq('creator_id', widget.creatorHandle)
            .order('created_at', ascending: false);

        _mocks = mocksRes ?? [];

        if (coachingRes != null) {
          final batchRes = await client
              .from('batches')
              .select('*, batch_tests(*)')
              .eq('coaching_id', coachingRes['id'])
              .order('created_at', ascending: false);
          
          // Hidden batches are excluded from public profile
          _batches = (batchRes as List? ?? []).where((b) => b['status'] != 'HIDDEN').toList();
        }
      } else {
        _isCreator = false;
        _profile = {
          'name': widget.creatorHandle == 'user' ? 'Aspirant Candidate' : widget.creatorHandle,
          'handle_id': widget.creatorHandle,
          'subject_specialty': 'Competitive Exam Aspirant',
          'followers_count': 0,
        };
      }

      final postsRes = await client
          .from('community_posts')
          .select()
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      _posts = postsRes ?? [];
      _tabController = TabController(length: _isCreator ? 3 : 1, vsync: this);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleFollow() {
    HapticFeedback.selectionClick();
    if (_profile == null || !_isCreator) return;

    final currentFollowers = _profile!['followers_count'] ?? 0;
    final newFollowers = _isFollowing ? (currentFollowers - 1).clamp(0, 999999) : currentFollowers + 1;

    setState(() {
      _isFollowing = !_isFollowing;
      _profile!['followers_count'] = newFollowers;
    });

    Supabase.instance.client
        .from('creator_profiles')
        .update({'followers_count': newFollowers})
        .eq('handle_id', widget.creatorHandle)
        .then((_) {});
  }

  void _openTelegram(String? urlOrHandle) async {
    if (urlOrHandle == null || urlOrHandle.isEmpty) return;
    String cleanUrl = urlOrHandle.startsWith('http') ? urlOrHandle : 'https://t.me/$urlOrHandle';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 🔑 Secure Password/Code Verification Dialog
  void _openBatchUnlockDialog(Map<String, dynamic> batch) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enroll: ${batch['batch_name']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apne coaching / teacher dwara diya gaya secret batch code enter karein:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. PATNA100',
                labelText: 'Secret Batch Code',
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
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final enteredCode = codeCtrl.text.trim().toUpperCase();
              final actualCode = (batch['batch_code'] ?? '').toString().toUpperCase();

              if (enteredCode.isNotEmpty && enteredCode == actualCode) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_enrolled_batch_code', enteredCode);

                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _userEnrolledCode = enteredCode);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Verified! Welcome to "${batch['batch_name']}"'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Invalid Code! Teacher se sahi password/code lein.')),
                  );
                }
              }
            },
            child: const Text('Unlock Batch 🚀'),
          ),
        ],
      ),
    );
  }

  void _startMockTest(Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions in this test!')));
      return;
    }

    List<Question> parsedQuestions = [];
    for (var item in rawList) {
      if (item is Map) {
        parsedQuestions.add(Question.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    if (parsedQuestions.isEmpty) return;

    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': (mock['attempts_count'] ?? 0) + 1})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Mock Test',
          questions: parsedQuestions,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final String? bannerUrl = _coachingData?['banner_url'];
    final String displayName = _coachingData?['name'] ?? _profile?['name'] ?? widget.creatorHandle;
    final String locationText = _coachingData?['district'] ?? _coachingData?['city'] ?? _profile?['subject_specialty'] ?? 'Bihar';
    final String? landmarkText = _coachingData?['landmark_address'];

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isCreator ? displayName : 'Candidate Profile',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0.5,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: cardBg,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    // 🖼️ 1. BIG HIGH-VISIBILITY BANNER (Height: 185px)
                    if (bannerUrl != null && bannerUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Image.network(
                          bannerUrl,
                          height: 185, // 👈 Height enhanced for billboard visibility
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: _isCreator ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _isCreator ? const Color(0xFF2563EB).withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _isCreator ? 'INSTITUTE' : 'ASPIRANT',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: _isCreator ? const Color(0xFF2563EB) : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${widget.creatorHandle} • 📍 $locationText${landmarkText != null && landmarkText.isNotEmpty ? " • $landmarkText" : ""}',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_isCreator) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('${_profile!['followers_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(width: 4),
                                    Text('Followers', style: TextStyle(color: Colors.grey[500], fontSize: 12.5)),
                                    const SizedBox(width: 14),
                                    Text('${_batches.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(width: 4),
                                    Text('Batches', style: TextStyle(color: Colors.grey[500], fontSize: 12.5)),
                                  ],
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)) : const Color(0xFF2563EB),
                                    foregroundColor: _isFollowing ? (isDark ? Colors.white : Colors.black87) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    elevation: 0,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: _toggleFollow,
                                  child: Text(_isFollowing ? 'Following' : 'Follow +', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            if (_profile!['telegram_handle'] != null && _profile!['telegram_handle'].toString().isNotEmpty) ...[
                              const Divider(height: 20),
                              InkWell(
                                onTap: () => _openTelegram(_profile!['telegram_handle']),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.telegram, color: Color(0xFF0088CC), size: 18),
                                    SizedBox(width: 6),
                                    Text('Join Telegram Channel', style: TextStyle(color: Color(0xFF0088CC), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            Row(
                              children: [
                                Icon(Icons.forum_outlined, size: 16, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                Text('${_posts.length} Discussions Shared', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isCreator)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF2563EB),
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    Tab(text: 'Batches (${_batches.length})'),
                    Tab(text: 'Open Mocks (${_mocks.length})'),
                    Tab(text: 'Notices (${_posts.length})'),
                  ],
                ),
                color: cardBg,
              ),
            ),
        ],
        body: _isCreator
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildBatchesTab(cardBg),
                  _buildMocksTab(cardBg),
                  _buildPostsTab(cardBg),
                ],
              )
            : _buildPostsTab(cardBg),
      ),
    );
  }

  // 🎓 BATCHES TAB (PASSWORD PROTECTED & CODE HIDDEN)
  Widget _buildBatchesTab(Color cardBg) {
    if (_batches.isEmpty) {
      return const Center(child: Text('No active batches right now.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _batches.length,
      itemBuilder: (context, idx) {
        final b = _batches[idx];
        final List tests = b['batch_tests'] ?? [];
        final String batchCode = (b['batch_code'] ?? '').toString().toUpperCase();
        final bool isUnlocked = _userEnrolledCode != null && _userEnrolledCode == batchCode;
        final bool isUpcoming = b['status'] == 'UPCOMING';

        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isUnlocked ? const Color(0xFF16A34A).withOpacity(0.5) : Colors.grey.withOpacity(0.18),
              width: isUnlocked ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        b['batch_name'] ?? 'Class Batch',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? const Color(0xFF16A34A).withOpacity(0.15)
                            : (isUpcoming ? Colors.amber.withOpacity(0.15) : Colors.grey.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUnlocked ? '✅ UNLOCKED' : (isUpcoming ? '⏳ UPCOMING' : '🔒 PASSWORD LOCKED'),
                        style: TextStyle(
                          color: isUnlocked ? const Color(0xFF16A34A) : (isUpcoming ? Colors.amber.shade800 : Colors.grey[700]),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${tests.length} Private CBT Tests & Notes inside this batch.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),

                // Action Button (Lock vs Unlock State)
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnlocked ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (isUnlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Accessing "${b['batch_name']}" tests!'), backgroundColor: const Color(0xFF16A34A)),
                        );
                      } else {
                        _openBatchUnlockDialog(b);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isUnlocked ? Icons.play_circle_fill_rounded : Icons.lock_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          isUnlocked ? 'Open Classroom Mocks 🚀' : 'Enter Password to Unlock 🔑',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ⚡ OPEN PUBLIC MOCKS TAB
  Widget _buildMocksTab(Color cardBg) {
    if (_mocks.isEmpty) {
      return const Center(child: Text('No open mock tests published yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _mocks.length,
      itemBuilder: (context, idx) {
        final m = _mocks[idx];
        final List qList = m['questions_json'] ?? [];
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(m['subject'] ?? 'General', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Text('${m['attempts_count'] ?? 0} Attempts', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m['title'] ?? 'Mock Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${qList.length} Questions • ${m['duration_mins'] ?? 10} Mins • Public Practice', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _startMockTest(m),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Start Free Mock Test ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 📚 NOTICES & PUBLIC NOTES TAB
  Widget _buildPostsTab(Color cardBg) {
    if (_posts.isEmpty) {
      return const Center(child: Text('No announcements shared yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (context, idx) {
        final p = _posts[idx];
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(p['tag'] ?? 'Notice', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(p['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.color});
  final TabBar _tabBar;
  final Color color;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

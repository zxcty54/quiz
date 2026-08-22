import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';
import 'creator_profile_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final bool isDarkMode;
  const CommunityFeedScreen({super.key, required this.isDarkMode});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  List<dynamic> _feedItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('creator_mocks')
          .select('*, creator_profiles!inner(name, handle_id, subject_specialty, telegram_handle, is_blocked)')
          .eq('creator_profiles.is_blocked', false)
          .order('created_at', ascending: false);

      setState(() {
        _feedItems = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startMock(Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) return;

    final List<Question> qList = rawList.map((q) => Question(
      qe: q['qe'] ?? q['qh'] ?? '',
      qh: q['qh'] ?? q['qe'] ?? '',
      se: q['se'] != null ? List<String>.from(q['se']) : null,
      sh: q['sh'] != null ? List<String>.from(q['sh']) : null,
      oe: List<String>.from(q['oe'] ?? q['oh'] ?? []),
      oh: List<String>.from(q['oh'] ?? q['oe'] ?? []),
      answerIndex: q['a'] ?? 0,
      explanation: q['eh'] ?? q['ee'] ?? '',
    )).toList();

    // Increment Attempt count
    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': (mock['attempts_count'] ?? 0) + 1})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Community Mock',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  void _openTelegram(String? urlOrHandle) async {
    if (urlOrHandle == null || urlOrHandle.isEmpty) return;
    String cleanUrl = urlOrHandle.startsWith('http') ? urlOrHandle : 'https://t.me/$urlOrHandle';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community & Creator Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Feed',
            onPressed: _fetchFeedData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFeedData,
              child: _feedItems.isEmpty
                  ? const Center(
                      child: Text('No community posts or tests yet.\nBe the first creator to post!'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: _feedItems.length,
                      itemBuilder: (context, idx) {
                        final item = _feedItems[idx];
                        final creator = item['creator_profiles'] ?? {};
                        final List qList = item['questions_json'] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          color: cardBg,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 👤 Creator Header Bar
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreatorProfileScreen(
                                              creatorHandle: creator['handle_id'] ?? '',
                                              isDarkMode: isDark,
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFF2563EB),
                                        child: Text(
                                          (creator['name'] ?? 'E')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CreatorProfileScreen(
                                                    creatorHandle: creator['handle_id'] ?? '',
                                                    isDarkMode: isDark,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              creator['name'] ?? 'Educator',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                          Text(
                                            creator['subject_specialty'] ?? 'Mentor',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (creator['telegram_handle'] != null && creator['telegram_handle'].toString().isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 22),
                                        tooltip: 'Join Channel',
                                        onPressed: () => _openTelegram(creator['telegram_handle']),
                                      ),
                                  ],
                                ),
                                const Divider(height: 18),

                                // 📝 Test / Post Content Details
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['subject'] ?? 'General',
                                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${item['attempts_count'] ?? 0} Attempts', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                Text(
                                  item['title'] ?? 'Mock Test',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Contains ${qList.length} Questions • ${item['duration_mins']} Minutes Test',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 14),

                                // 🚀 Start Test CTA
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                    label: const Text('Attempt Mock Drill', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _startMock(item),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';
import 'creator_profile_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final bool isDarkMode;
  const CommunityFeedScreen({super.key, required this.isDarkMode});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  List<dynamic> _feedItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('creator_mocks')
          .select('*, creator_profiles!inner(name, handle_id, subject_specialty, telegram_handle, is_blocked)')
          .eq('creator_profiles.is_blocked', false)
          .order('created_at', ascending: false);

      setState(() {
        _feedItems = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startMock(Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) return;

    final List<Question> qList = rawList.map((q) => Question(
      qe: q['qe'] ?? q['qh'] ?? '',
      qh: q['qh'] ?? q['qe'] ?? '',
      se: q['se'] != null ? List<String>.from(q['se']) : null,
      sh: q['sh'] != null ? List<String>.from(q['sh']) : null,
      oe: List<String>.from(q['oe'] ?? q['oh'] ?? []),
      oh: List<String>.from(q['oh'] ?? q['oe'] ?? []),
      answerIndex: q['a'] ?? 0,
      explanation: q['eh'] ?? q['ee'] ?? '',
    )).toList();

    // Increment Attempt count
    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': (mock['attempts_count'] ?? 0) + 1})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Community Mock',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  void _openTelegram(String? urlOrHandle) async {
    if (urlOrHandle == null || urlOrHandle.isEmpty) return;
    String cleanUrl = urlOrHandle.startsWith('http') ? urlOrHandle : 'https://t.me/$urlOrHandle';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community & Creator Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Feed',
            onPressed: _fetchFeedData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFeedData,
              child: _feedItems.isEmpty
                  ? const Center(
                      child: Text('No community posts or tests yet.\nBe the first creator to post!'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: _feedItems.length,
                      itemBuilder: (context, idx) {
                        final item = _feedItems[idx];
                        final creator = item['creator_profiles'] ?? {};
                        final List qList = item['questions_json'] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          color: cardBg,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 👤 Creator Header Bar
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreatorProfileScreen(
                                              creatorHandle: creator['handle_id'] ?? '',
                                              isDarkMode: isDark,
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFF2563EB),
                                        child: Text(
                                          (creator['name'] ?? 'E')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CreatorProfileScreen(
                                                    creatorHandle: creator['handle_id'] ?? '',
                                                    isDarkMode: isDark,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              creator['name'] ?? 'Educator',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                          Text(
                                            creator['subject_specialty'] ?? 'Mentor',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (creator['telegram_handle'] != null && creator['telegram_handle'].toString().isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 22),
                                        tooltip: 'Join Channel',
                                        onPressed: () => _openTelegram(creator['telegram_handle']),
                                      ),
                                  ],
                                ),
                                const Divider(height: 18),

                                // 📝 Test / Post Content Details
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['subject'] ?? 'General',
                                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${item['attempts_count'] ?? 0} Attempts', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                Text(
                                  item['title'] ?? 'Mock Test',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Contains ${qList.length} Questions • ${item['duration_mins']} Minutes Test',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 14),

                                // 🚀 Start Test CTA
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                    label: const Text('Attempt Mock Drill', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _startMock(item),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

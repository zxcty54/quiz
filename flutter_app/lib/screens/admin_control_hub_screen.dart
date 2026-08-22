import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminControlHubScreen extends StatefulWidget {
  final bool isDarkMode;
  const AdminControlHubScreen({super.key, required this.isDarkMode});

  @override
  State<AdminControlHubScreen> createState() => _AdminControlHubScreenState();
}

class _AdminControlHubScreenState extends State<AdminControlHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final client = Supabase.instance.client;

  List<dynamic> _creators = [];
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllAdminData();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);
    try {
      final creatorsRes = await client.from('creator_profiles').select().order('created_at', ascending: false);
      final postsRes = await client.from('community_posts').select().order('created_at', ascending: false).limit(50);

      if (mounted) {
        setState(() {
          _creators = creatorsRes;
          _posts = postsRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔴 1. Delete Any Post Instantly
  Future<void> _deletePost(int postId) async {
    HapticFeedback.heavyImpact();
    await client.from('community_posts').delete().eq('id', postId);
    _loadAllAdminData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Post purged permanently from feed!'), backgroundColor: Colors.red),
      );
    }
  }

  // ⚡ 2. Toggle Creator Block / Ban
  Future<void> _toggleCreatorBlock(String handle, bool currentStatus) async {
    HapticFeedback.mediumImpact();
    await client.from('creator_profiles').update({'is_blocked': !currentStatus}).eq('handle_id', handle);
    _loadAllAdminData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentStatus ? '🚫 Creator @$handle Blocked!' : '✅ Creator @$handle Unblocked!'),
          backgroundColor: !currentStatus ? Colors.red : Colors.green,
        ),
      );
    }
  }

  // 📢 3. Broadcast Official Admin Announcement
  void _openBroadcastAlertModal() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📢 Push Global Admin Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Notice Headline', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Details / Instructions...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                onPressed: () async {
                  final text = contentCtrl.text.trim();
                  if (text.isEmpty) return;

                  Navigator.pop(ctx);
                  await client.from('community_posts').insert({
                    'creator_id': 'admin',
                    'author_name': 'Official Admin 🛡️',
                    'content': '🚨 **${titleCtrl.text.trim()}**\n\n$text',
                    'tag': 'Exam Gossip 🔥',
                    'views_count': 500,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🚀 Official Admin Alert live on feed!'), backgroundColor: Color(0xFF16A34A)),
                    );
                    _loadAllAdminData();
                  }
                },
                child: const Text('Broadcast Pinned Notice 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Master Admin Control Suite 🛡️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAllAdminData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Creators'),
            Tab(text: 'Feed Purge'),
            Tab(text: 'System Broadcast'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 👥 TAB 1: Creators Management
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _creators.length,
                  itemBuilder: (ctx, idx) {
                    final c = _creators[idx];
                    final bool isBlocked = c['is_blocked'] ?? false;
                    return Card(
                      color: cardBg,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isBlocked ? Colors.red : const Color(0xFF2563EB),
                          child: Text((c['name'] ?? 'M')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Row(
                          children: [
                            Text(c['name'] ?? 'Creator', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 4),
                            if (!isBlocked) const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                          ],
                        ),
                        subtitle: Text('@${c['handle_id']} • PIN: ${c['security_pin'] ?? 'None'} • Followers: ${c['followers_count'] ?? 0}', style: const TextStyle(fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBlocked ? Colors.green : Colors.redAccent,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _toggleCreatorBlock(c['handle_id'], isBlocked),
                          child: Text(isBlocked ? 'Unban' : 'Ban / Block', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),

                // 🗑️ TAB 2: Feed Moderation / Post Purge
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _posts.length,
                  itemBuilder: (ctx, idx) {
                    final p = _posts[idx];
                    return Card(
                      color: cardBg,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(p['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('By @${p['creator_id']} • Tag: ${p['tag']} • ID: ${p['id']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                          onPressed: () => _deletePost(p['id']),
                        ),
                      ),
                    );
                  },
                ),

                // 📢 TAB 3: Global System Announcements
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.campaign_rounded, size: 64, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      const Text('Broadcast System Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 6),
                      const Text(
                        'Push official exam updates or platform maintenance notices directly to all students feed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_alert_rounded),
                        label: const Text('Create Global Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _openBroadcastAlertModal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

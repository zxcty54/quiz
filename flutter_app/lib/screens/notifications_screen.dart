import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'post_detail_screen.dart';

/// App ke andar ki notifications: kisi ne aapki post par comment kiya,
/// aapke comment ka reply diya, ya post/comment like kiya.
/// Data user_notifications table se aata hai (SQL triggers bharte hain).
class NotificationsScreen extends StatefulWidget {
  final bool isDarkMode;

  const NotificationsScreen({super.key, required this.isDarkMode});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _handle = 'user';
  String _name = 'Aspirant';

  static const Color _primaryBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final creatorHandle = prefs.getString('logged_in_creator_handle');
    final userId = prefs.getString('user_id') ?? 'user';
    _handle = (creatorHandle != null && creatorHandle.trim().isNotEmpty)
        ? creatorHandle.trim()
        : userId.trim();
    _name = prefs.getString('custom_aspirant_name') ??
        prefs.getString('user_name') ??
        'Aspirant';

    try {
      final rows = await Supabase.instance.client
          .from('user_notifications')
          .select()
          .eq('user_handle', _handle)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    setState(() => item['is_read'] = true);
    try {
      await Supabase.instance.client
          .from('user_notifications')
          .update({'is_read': true}).eq('id', item['id']);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _items) {
        n['is_read'] = true;
      }
    });
    try {
      await Supabase.instance.client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('user_handle', _handle)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    await _markRead(item);
    final postId = int.tryParse(item['post_id']?.toString() ?? '');
    if (postId == null || !mounted) return;

    try {
      final row = await Supabase.instance.client
          .from('community_posts')
          .select()
          .eq('id', postId)
          .maybeSingle();
      if (row == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: Map<String, dynamic>.from(row),
            currentLoggedInHandle: _handle,
            customUserName: _name,
            isDarkMode: widget.isDarkMode,
            initialLiked: false,
            initialSaved: false,
            initialPollIndex: null,
            onLikeToggle: (_) {},
            onBookmarkToggle: (_) {},
            onPollVote: (_) {},
          ),
        ),
      );
    } catch (_) {}
  }

  String _relativeTime(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.isNegative || diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'comment_reply':
        return Icons.reply_rounded;
      case 'comment_like':
        return Icons.thumb_up_rounded;
      case 'post_like':
        return Icons.favorite_rounded;
      case 'post_comment':
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _iconColor(String? type) {
    switch (type) {
      case 'comment_like':
      case 'post_like':
        return const Color(0xFFDB2777);
      case 'comment_reply':
        return const Color(0xFF059669);
      default:
        return _primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final title = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final hasUnread = _items.any((n) => n['is_read'] != true);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: title),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 44, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      Text(
                        'No notifications yet',
                        style: TextStyle(color: muted, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Replies and likes on your posts will show here.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (context, i) {
                      final n = _items[i];
                      final unread = n['is_read'] != true;
                      final type = n['type']?.toString();
                      final color = _iconColor(type);

                      return InkWell(
                        onTap: () => _openItem(n),
                        child: Container(
                          color: unread
                              ? _primaryBlue.withValues(alpha: isDark ? 0.14 : 0.06)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: color.withValues(alpha: 0.14),
                                child: Icon(_icon(type), color: color, size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (n['message'] ?? 'New activity').toString(),
                                      style: TextStyle(
                                        color: title,
                                        fontSize: 13.5,
                                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _relativeTime(n['created_at']),
                                      style: TextStyle(color: muted, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (unread)
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: _primaryBlue,
                                    shape: BoxShape.circle,
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

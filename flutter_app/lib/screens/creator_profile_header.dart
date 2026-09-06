import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CreatorProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? coaching;
  final String handle;
  final bool isDarkMode;
  final bool isFollowing;
  final int followersCount;
  final int batchesCount;
  final int mocksCount;
  final int selectionsCount;
  final VoidCallback onToggleFollow;

  const CreatorProfileHeader({
    super.key,
    required this.profile,
    required this.coaching,
    required this.handle,
    required this.isDarkMode,
    required this.isFollowing,
    required this.followersCount,
    required this.batchesCount,
    required this.mocksCount,
    required this.selectionsCount,
    required this.onToggleFollow,
  });

  static const Color _primaryBlue = Color(0xFF2563EB);

  void _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openDialer(String phone) async {
    try {
      // Space aur unwanted symbols remove karke clean number dial karna
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final uri = Uri(scheme: 'tel', path: cleanPhone);
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
      final uri = Uri.parse('https://wa.me/$cleanNumber?text=Hello,%20I%20want%20information%20regarding%20batches.');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cardSurface = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final name = coaching?['name'] ?? profile?['name'] ?? 'Educator';
    final specialty = profile?['subject_specialty'] ?? coaching?['tagline'] ?? 'Exam Guidance Hub';
    final district = coaching?['district'] ?? coaching?['city'] ?? 'Bihar';
    final landmark = coaching?['landmark_address'] ?? coaching?['landmark'];
    final logoUrl = coaching?['logo_url'] ?? profile?['profile_image'];

    // Deep Read for Contact & Social Fields
    final contactPhone = (coaching?['phone'] ?? coaching?['contact_number'] ?? profile?['phone'] ?? '').toString().trim();
    final telegram = (coaching?['telegram_link'] ?? profile?['telegram_handle'] ?? '').toString().trim();
    final youtube = (coaching?['youtube_url'] ?? profile?['youtube_handle'] ?? '').toString().trim();
    final facebook = (coaching?['facebook_url'] ?? profile?['facebook_handle'] ?? '').toString().trim();
    final website = (coaching?['website_url'] ?? profile?['website_url'] ?? '').toString().trim();

    final hasAnySocial = contactPhone.isNotEmpty ||
        telegram.isNotEmpty ||
        youtube.isNotEmpty ||
        facebook.isNotEmpty ||
        website.isNotEmpty;

    return Container(
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
                  border: Border.all(color: cardSurface, width: 3.5),
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
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isFollowing ? _primaryBlue : Colors.transparent,
                    foregroundColor: isFollowing ? Colors.white : _primaryBlue,
                    side: const BorderSide(color: _primaryBlue, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: Icon(isFollowing ? Icons.check_rounded : Icons.add_rounded, size: 16),
                  label: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: onToggleFollow,
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
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.verified, size: 17, color: _primaryBlue),
            ],
          ),
          const SizedBox(height: 2),
          Text('@$handle', style: TextStyle(color: Colors.grey[500], fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  landmark != null && landmark.toString().isNotEmpty ? '$landmark, $district' : '$district, Bihar',
                  style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[300] : const Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(specialty, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryBlue)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat('$followersCount', 'Followers'),
              const SizedBox(width: 24),
              _buildStat('$batchesCount', 'Batches'),
              const SizedBox(width: 24),
              _buildStat('$mocksCount', 'Free Mocks'),
              const SizedBox(width: 24),
              _buildStat('$selectionsCount', 'Selections 🎓'),
            ],
          ),

          // 🌐 Social Links Strip (Only appears when at least 1 link exists)
          if (hasAnySocial) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (contactPhone.isNotEmpty) ...[
                  _buildSocialPill(
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    iconColor: const Color(0xFF16A34A),
                    dividerColor: dividerColor,
                    onTap: () => _openDialer(contactPhone),
                  ),
                  _buildSocialPill(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'WhatsApp',
                    iconColor: const Color(0xFF25D366),
                    dividerColor: dividerColor,
                    onTap: () => _openWhatsApp(contactPhone),
                  ),
                ],
                if (telegram.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.near_me_rounded,
                    label: 'Telegram',
                    iconColor: const Color(0xFF0284C7),
                    dividerColor: dividerColor,
                    onTap: () {
                      _openUrl(telegram.startsWith('http') ? telegram : 'https://t.me/${telegram.replaceAll('@', '')}');
                    },
                  ),
                if (youtube.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.smart_display_outlined,
                    label: 'YouTube',
                    iconColor: const Color(0xFFEF4444),
                    dividerColor: dividerColor,
                    onTap: () {
                      _openUrl(youtube.startsWith('http') ? youtube : 'https://youtube.com/${youtube.startsWith('@') ? youtube : "@$youtube"}');
                    },
                  ),
                if (facebook.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.facebook_rounded,
                    label: 'Facebook',
                    iconColor: const Color(0xFF1877F2),
                    dividerColor: dividerColor,
                    onTap: () {
                      _openUrl(facebook.startsWith('http') ? facebook : 'https://facebook.com/$facebook');
                    },
                  ),
                if (website.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    iconColor: _primaryBlue,
                    dividerColor: dividerColor,
                    onTap: () {
                      _openUrl(website.startsWith('http') ? website : 'https://$website');
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
      ],
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
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

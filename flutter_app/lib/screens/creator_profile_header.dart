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
    final textDark = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final name = (coaching?['name'] ?? profile?['name'] ?? '').toString().trim();
    final specialty = (coaching?['tagline'] ?? profile?['subject_specialty'] ?? '').toString().trim();
    final district = (coaching?['district'] ?? coaching?['city'] ?? '').toString().trim();
    final landmark = (coaching?['landmark_address'] ?? coaching?['landmark'] ?? '').toString().trim();
    final logoUrl = coaching?['banner_url'] ?? profile?['banner_url'] ?? coaching?['logo_url'] ?? profile?['profile_image'];

    // Social Links Check
    final contactPhone = (coaching?['phone'] ?? coaching?['contact_number'] ?? profile?['phone'] ?? '').toString().trim();
    final telegram = (coaching?['telegram_link'] ?? profile?['telegram_handle'] ?? '').toString().trim();
    final youtube = (coaching?['youtube_url'] ?? profile?['youtube_handle'] ?? '').toString().trim();
    final facebook = (coaching?['facebook_url'] ?? profile?['facebook_handle'] ?? '').toString().trim();
    final website = (coaching?['website_url'] ?? profile?['website_url'] ?? '').toString().trim();

    final hasAnySocial = contactPhone.isNotEmpty || telegram.isNotEmpty || youtube.isNotEmpty || facebook.isNotEmpty || website.isNotEmpty;

    // Build location string from actual database fields
    String locationText = '';
    if (landmark.isNotEmpty && district.isNotEmpty) {
      locationText = '$landmark, $district';
    } else if (district.isNotEmpty) {
      locationText = district;
    }

    return Container(
      color: cardSurface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP ROW: SQUARE AVATAR WITH TROPHY + SOLID FOLLOW BUTTON
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Square Avatar with Rounded Corners & Trophy Icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardSurface, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: (logoUrl != null && logoUrl.toString().trim().isNotEmpty)
                          ? Image.network(
                              logoUrl.toString().trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Right Button: Solid Orange / Green Follow Button
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  icon: Icon(isFollowing ? Icons.check_rounded : Icons.school_outlined, size: 16),
                  label: Text(
                    isFollowing ? 'Following' : 'Follow Institute',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: onToggleFollow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. COACHING TITLE & GOLD MEDAL ICON
          Row(
            children: [
              Flexible(
                child: Text(
                  name.isNotEmpty ? name : 'Coaching Hub',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: textDark,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.military_tech_rounded, size: 20, color: Color(0xFFF59E0B)),
            ],
          ),

          // 3. TAGLINE IN GOLD/AMBER TONE (Only if exists)
          if (specialty.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              specialty,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD97706),
                height: 1.35,
              ),
            ),
          ],

          // 4. LOCATION (Only if real location exists)
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationText,
                    style: TextStyle(fontSize: 12, color: textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // 5. REAL STATS ROW
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

          // 6. SOCIAL LINKS STRIP (Appears only if genuine links exist)
          if (hasAnySocial) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (contactPhone.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'WhatsApp',
                    iconColor: const Color(0xFF25D366),
                    dividerColor: dividerColor,
                    onTap: () => _openWhatsApp(contactPhone),
                  ),
                if (telegram.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.near_me_rounded,
                    label: 'Telegram',
                    iconColor: const Color(0xFF0284C7),
                    dividerColor: dividerColor,
                    onTap: () => _openUrl(telegram.startsWith('http') ? telegram : 'https://t.me/${telegram.replaceAll('@', '')}'),
                  ),
                if (youtube.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.smart_display_outlined,
                    label: 'YouTube',
                    iconColor: const Color(0xFFEF4444),
                    dividerColor: dividerColor,
                    onTap: () => _openUrl(youtube.startsWith('http') ? youtube : 'https://youtube.com/${youtube.startsWith('@') ? youtube : "@$youtube"}'),
                  ),
                if (facebook.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.facebook_rounded,
                    label: 'Facebook',
                    iconColor: const Color(0xFF1877F2),
                    dividerColor: dividerColor,
                    onTap: () => _openUrl(facebook.startsWith('http') ? facebook : 'https://facebook.com/$facebook'),
                  ),
                if (website.isNotEmpty)
                  _buildSocialPill(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    iconColor: _primaryBlue,
                    dividerColor: dividerColor,
                    onTap: () => _openUrl(website.startsWith('http') ? website : 'https://$website'),
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

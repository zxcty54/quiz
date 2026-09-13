import 'package:flutter/material.dart';
import 'revision_subtopic_modal.dart';

// 1. Direct Flat Card (Used for Aptitude & Reasoning - No sub pills)
class RevisionDirectCard extends StatelessWidget {
  final String title;
  final String badgeText;
  final String headerLabel;
  final String icon;
  final String mappingKey;
  final String fallbackKey;
  final Color brandColor;
  final bool isDark;
  final bool isLoading;
  final Map<String, dynamic> liveMapping;
  final Function(BuildContext, String, String) onLaunchPractice;

  const RevisionDirectCard({
    super.key,
    required this.title,
    required this.badgeText,
    required this.headerLabel,
    required this.icon,
    required this.mappingKey,
    required this.fallbackKey,
    required this.brandColor,
    required this.isDark,
    required this.isLoading,
    required this.liveMapping,
    required this.onLaunchPractice,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    Map<String, dynamic> activeChapters = {};
    if (liveMapping.containsKey(mappingKey) && liveMapping[mappingKey] is Map) {
      activeChapters = Map<String, dynamic>.from(liveMapping[mappingKey]);
    } else if (liveMapping.containsKey(fallbackKey) && liveMapping[fallbackKey] is Map) {
      activeChapters = Map<String, dynamic>.from(liveMapping[fallbackKey]);
    }

    return Card(
      color: cardBg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? brandColor.withOpacity(0.5) : brandColor.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: brandColor,
        collapsedIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        leading: Text(icon, style: const TextStyle(fontSize: 22)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: brandColor)),
            const SizedBox(height: 2),
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? brandColor.withOpacity(0.95) : brandColor.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(headerLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${activeChapters.length} Chapters",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: brandColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          activeChapters.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    isLoading ? "Loading chapters..." : "No chapters added yet.",
                    style: TextStyle(fontSize: 11.5, color: subTextColor),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeChapters.entries.map((entry) {
                      final bool hasSubTypes = entry.value is Map;

                      return ActionChip(
                        elevation: 1,
                        backgroundColor: isDark ? brandColor.withOpacity(0.2) : Colors.white,
                        side: BorderSide(color: isDark ? brandColor.withOpacity(0.5) : brandColor.withOpacity(0.35)),
                        avatar: hasSubTypes ? Icon(Icons.folder, size: 15, color: brandColor) : null,
                        label: Text(
                          entry.key,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : brandColor),
                        ),
                        onPressed: () {
                          if (hasSubTypes) {
                            RevisionSubTopicModal.show(
                              context: context,
                              chapterTitle: entry.key,
                              subTypes: Map<String, dynamic>.from(entry.value),
                              isDark: isDark,
                              themeColor: brandColor,
                              onLaunchPractice: onLaunchPractice,
                            );
                          } else {
                            onLaunchPractice(context, entry.key, entry.value.toString());
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}

// 2. Segmented Pill Card (Used for Science, GK, Static GK)
class RevisionSegmentedCard extends StatelessWidget {
  final String title;
  final String badgeText;
  final String icon;
  final Color color;
  final bool isDark;
  final bool isLoading;
  final int selectedIndex;
  final ValueChanged<int> onPillSelected;
  final List<Map<String, dynamic>> subjects;
  final Map<String, dynamic> liveMapping;
  final Function(BuildContext, String, String) onLaunchPractice;

  const RevisionSegmentedCard({
    super.key,
    required this.title,
    required this.badgeText,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.isLoading,
    required this.selectedIndex,
    required this.onPillSelected,
    required this.subjects,
    required this.liveMapping,
    required this.onLaunchPractice,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    final currentSub = subjects[selectedIndex.clamp(0, subjects.length - 1)];
    final String activeKey = currentSub['key'];

    Map<String, dynamic> activeChapters = {};
    if (liveMapping.containsKey(activeKey) && liveMapping[activeKey] is Map) {
      activeChapters = Map<String, dynamic>.from(liveMapping[activeKey]);
    }

    return Card(
      color: cardBg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: color,
        collapsedIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        leading: Text(icon, style: const TextStyle(fontSize: 22)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: color)),
            const SizedBox(height: 2),
            Text(badgeText, style: TextStyle(fontSize: 11, color: isDark ? color.withOpacity(0.95) : color.withOpacity(0.9), fontWeight: FontWeight.bold)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          const Divider(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(subjects.length, (idx) {
                final item = subjects[idx];
                final bool isSelected = selectedIndex == idx;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(
                      item['title'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                      ),
                    ),
                    selectedColor: color,
                    backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    onSelected: (val) {
                      if (val) onPillSelected(idx);
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${currentSub['title']} Sets", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${activeChapters.length} Chapters",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          activeChapters.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    isLoading ? "Loading chapters..." : "No chapters added yet.",
                    style: TextStyle(fontSize: 11.5, color: subTextColor),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeChapters.entries.map((entry) {
                      return ActionChip(
                        elevation: 1,
                        backgroundColor: isDark ? color.withOpacity(0.2) : Colors.white,
                        side: BorderSide(color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.35)),
                        label: Text(
                          entry.key,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color),
                        ),
                        onPressed: () => onLaunchPractice(context, entry.key, entry.value.toString()),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tabs/widgets/revision_subtopic_modal.dart';

class RevisionSubjectSection {
  final String label;
  final String mappingKey;
  final String? fallbackKey;

  const RevisionSubjectSection({
    required this.label,
    required this.mappingKey,
    this.fallbackKey,
  });
}

/// Practice Hub 2.0 — ek subject ke saare chapters ki saaf numbered list.
/// Data wahi purana live subject_mapping hai; sirf presentation nayi hai.
class RevisionChaptersScreen extends StatefulWidget {
  final String title;
  final String icon;
  final Color brandColor;
  final List<RevisionSubjectSection> sections;
  final Map<String, dynamic> liveMapping;
  final bool isLoading;
  final Function(BuildContext, String, String) onLaunchPractice;
  final Widget? customBody; // Current Affairs jaise special content ke liye

  const RevisionChaptersScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.brandColor,
    required this.sections,
    required this.liveMapping,
    required this.isLoading,
    required this.onLaunchPractice,
    this.customBody,
  });

  @override
  State<RevisionChaptersScreen> createState() => _RevisionChaptersScreenState();
}

class _RevisionChaptersScreenState extends State<RevisionChaptersScreen> {
  int _selectedSection = 0;
  Map<String, int> _progressByKey = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> found = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('rev_prog_')) {
        final v = prefs.getInt(key);
        if (v != null && v > 0) found[key] = v;
      }
    }
    if (mounted) setState(() => _progressByKey = found);
  }

  Map<String, dynamic> _chaptersFor(RevisionSubjectSection section) {
    final m = widget.liveMapping;
    if (m[section.mappingKey] is Map) {
      return Map<String, dynamic>.from(m[section.mappingKey] as Map);
    }
    final fb = section.fallbackKey;
    if (fb != null && m[fb] is Map) {
      return Map<String, dynamic>.from(m[fb] as Map);
    }
    return {};
  }

  String _progKey(String path) =>
      'rev_prog_${path.split('?').first.replaceAll('/', '_').replaceAll('.', '_')}';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FF);
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final bool hasSections = widget.customBody == null && widget.sections.isNotEmpty;
    final section = hasSections
        ? widget.sections[_selectedSection.clamp(0, widget.sections.length - 1)]
        : null;
    final chapters = section != null ? _chaptersFor(section) : <String, dynamic>{};
    final int totalChapters = widget.sections.fold<int>(
      0,
      (sum, s) => sum + _chaptersFor(s).length,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.title,
          style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF1F7)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(widget.brandColor, Colors.black, 0.28)!,
                  widget.brandColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.brandColor.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Center(child: Text(widget.icon, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, height: 1.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.customBody != null
                            ? 'Month-wise National + Bihar sets'
                            : '$totalChapters chapters • ${widget.sections.map((s) => s.label).join(' • ')}',
                        style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 11, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (widget.customBody != null)
            widget.customBody!
          else ...[
            // Section pills (Physics / Polity / ...) — jab ek se zyada hon
            if (widget.sections.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(widget.sections.length, (idx) {
                    final s = widget.sections[idx];
                    final bool selected = idx == _selectedSection;
                    final int count = _chaptersFor(s).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        showCheckmark: false,
                        label: Text(
                          '${s.label} ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                            color: selected ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                          ),
                        ),
                        selectedColor: widget.brandColor,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        side: BorderSide(
                          color: selected ? widget.brandColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        onSelected: (v) {
                          if (v) setState(() => _selectedSection = idx);
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (chapters.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.isLoading
                      ? 'Chapters load ho rahe hain…'
                      : 'Is section me abhi koi chapter add nahi hua hai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              )
            else
              ...List.generate(chapters.length, (i) {
                final entry = chapters.entries.elementAt(i);
                final bool hasSubTypes = entry.value is Map;
                final String path = hasSubTypes ? '' : entry.value.toString();
                final int savedIndex = hasSubTypes ? 0 : (_progressByKey[_progKey(path)] ?? 0);
                return RevisionChapterRow(
                  index: i,
                  title: entry.key,
                  subtitle: hasSubTypes
                      ? '${(entry.value as Map).length} Types — tap karke set chunein'
                      : (section?.label ?? widget.title),
                  brandColor: widget.brandColor,
                  isDark: isDark,
                  isFolder: hasSubTypes,
                  savedIndex: savedIndex,
                  onTap: () {
                    if (hasSubTypes) {
                      RevisionSubTopicModal.show(
                        context: context,
                        chapterTitle: entry.key,
                        subTypes: Map<String, dynamic>.from(entry.value as Map),
                        isDark: isDark,
                        themeColor: widget.brandColor,
                        onLaunchPractice: widget.onLaunchPractice,
                      );
                    } else {
                      widget.onLaunchPractice(context, entry.key, path);
                    }
                  },
                );
              }),
          ],
        ],
      ),
    );
  }
}

/// Ek chapter ki row — numbered, progress tag ke saath.
/// Chapter screen aur Practice Hub ke search results dono me use hoti hai.
class RevisionChapterRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final Color brandColor;
  final bool isDark;
  final bool isFolder;
  final int savedIndex;
  final VoidCallback onTap;

  const RevisionChapterRow({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.brandColor,
    required this.isDark,
    required this.onTap,
    this.isFolder = false,
    this.savedIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(isDark ? 0.25 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isFolder
                        ? Icon(Icons.folder_rounded, size: 16, color: brandColor)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: brandColor),
                          ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor, height: 1.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                if (savedIndex > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '⏳ Q${savedIndex + 1}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

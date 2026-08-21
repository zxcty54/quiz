import 'package:flutter/material.dart';
import '../models/question_model.dart';
import 'revision_practice_screen.dart';

class SubjectDirectoryScreen extends StatefulWidget {
  final String title;
  final String icon;
  final Color accentColor;
  final List<Map<String, dynamic>> subSections;
  final Map<String, dynamic> subjectMapping;
  final Function(BuildContext, String, String) onLaunchPractice;

  const SubjectDirectoryScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.subSections,
    required this.subjectMapping,
    required this.onLaunchPractice,
  });

  @override
  State<SubjectDirectoryScreen> createState() => _SubjectDirectoryScreenState();
}

class _SubjectDirectoryScreenState extends State<SubjectDirectoryScreen> {
  String _selectedSectionKey = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getFilteredChapters() {
    List<Map<String, String>> chapters = [];

    for (var section in widget.subSections) {
      final String sectionKey = section['key'] ?? '';
      final String sectionTitle = section['title'] ?? '';

      if (_selectedSectionKey != 'ALL' && _selectedSectionKey != sectionKey) {
        continue;
      }

      if (widget.subjectMapping.containsKey(sectionKey) &&
          widget.subjectMapping[sectionKey] is Map) {
        final Map mapData = widget.subjectMapping[sectionKey];
        mapData.forEach((k, v) {
          final String title = k.toString();
          final String path = v.toString();
          if (_searchQuery.isEmpty ||
              title.toLowerCase().contains(_searchQuery.toLowerCase())) {
            chapters.add({
              'title': title,
              'path': path,
              'section': sectionTitle,
            });
          }
        });
      }
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filteredList = _getFilteredChapters();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            Text(widget.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderColor, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Minimalist Search Input
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search chapter by name...',
                hintStyle: TextStyle(fontSize: 13, color: subTextColor),
                prefixIcon: Icon(Icons.search, size: 18, color: subTextColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.accentColor, width: 1.2),
                ),
              ),
            ),
          ),

          // 🏷️ Horizontal Filter Pills
          Container(
            color: cardBg,
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterPill(
                    label: 'All Sets',
                    isSelected: _selectedSectionKey == 'ALL',
                    onTap: () => setState(() => _selectedSectionKey = 'ALL'),
                    isDark: isDark,
                  ),
                  ...widget.subSections.map((sec) {
                    final key = sec['key'] ?? '';
                    final label = (sec['title'] ?? '').toString().split('(').first.trim();
                    return _buildFilterPill(
                      label: label,
                      isSelected: _selectedSectionKey == key,
                      onTap: () => setState(() => _selectedSectionKey = key),
                      isDark: isDark,
                    );
                  }),
                ],
              ),
            ),
          ),
          Container(height: 1, color: borderColor),

          // 📋 Professional Minimalist Chapter List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Text(
                      'No chapters found',
                      style: TextStyle(fontSize: 13, color: subTextColor),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.8,
                      indent: 16,
                      endIndent: 16,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final title = item['title'] ?? '';
                      final path = item['path'] ?? '';
                      final section = item['section'] ?? '';

                      return InkWell(
                        onTap: () => widget.onLaunchPractice(context, title, path),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: subTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      section,
                                      style: TextStyle(fontSize: 11, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: subTextColor),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }
}import 'package:flutter/material.dart';
import '../models/question_model.dart';
import 'revision_practice_screen.dart';

class SubjectDirectoryScreen extends StatefulWidget {
  final String title;
  final String icon;
  final Color accentColor;
  final List<Map<String, dynamic>> subSections;
  final Map<String, dynamic> subjectMapping;
  final Function(BuildContext, String, String) onLaunchPractice;

  const SubjectDirectoryScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.subSections,
    required this.subjectMapping,
    required this.onLaunchPractice,
  });

  @override
  State<SubjectDirectoryScreen> createState() => _SubjectDirectoryScreenState();
}

class _SubjectDirectoryScreenState extends State<SubjectDirectoryScreen> {
  String _selectedSectionKey = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getFilteredChapters() {
    List<Map<String, String>> chapters = [];

    for (var section in widget.subSections) {
      final String sectionKey = section['key'] ?? '';
      final String sectionTitle = section['title'] ?? '';

      if (_selectedSectionKey != 'ALL' && _selectedSectionKey != sectionKey) {
        continue;
      }

      if (widget.subjectMapping.containsKey(sectionKey) &&
          widget.subjectMapping[sectionKey] is Map) {
        final Map mapData = widget.subjectMapping[sectionKey];
        mapData.forEach((k, v) {
          final String title = k.toString();
          final String path = v.toString();
          if (_searchQuery.isEmpty ||
              title.toLowerCase().contains(_searchQuery.toLowerCase())) {
            chapters.add({
              'title': title,
              'path': path,
              'section': sectionTitle,
            });
          }
        });
      }
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filteredList = _getFilteredChapters();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            Text(widget.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderColor, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Minimalist Search Input
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search chapter by name...',
                hintStyle: TextStyle(fontSize: 13, color: subTextColor),
                prefixIcon: Icon(Icons.search, size: 18, color: subTextColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.accentColor, width: 1.2),
                ),
              ),
            ),
          ),

          // 🏷️ Horizontal Filter Pills
          Container(
            color: cardBg,
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterPill(
                    label: 'All Sets',
                    isSelected: _selectedSectionKey == 'ALL',
                    onTap: () => setState(() => _selectedSectionKey = 'ALL'),
                    isDark: isDark,
                  ),
                  ...widget.subSections.map((sec) {
                    final key = sec['key'] ?? '';
                    final label = (sec['title'] ?? '').toString().split('(').first.trim();
                    return _buildFilterPill(
                      label: label,
                      isSelected: _selectedSectionKey == key,
                      onTap: () => setState(() => _selectedSectionKey = key),
                      isDark: isDark,
                    );
                  }),
                ],
              ),
            ),
          ),
          Container(height: 1, color: borderColor),

          // 📋 Professional Minimalist Chapter List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Text(
                      'No chapters found',
                      style: TextStyle(fontSize: 13, color: subTextColor),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.8,
                      indent: 16,
                      endIndent: 16,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final title = item['title'] ?? '';
                      final path = item['path'] ?? '';
                      final section = item['section'] ?? '';

                      return InkWell(
                        onTap: () => widget.onLaunchPractice(context, title, path),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: subTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      section,
                                      style: TextStyle(fontSize: 11, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: subTextColor),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }
}

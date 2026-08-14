import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'learn_chat_screen.dart';

class LearnHubScreen extends StatefulWidget {
  const LearnHubScreen({super.key});

  @override
  State<LearnHubScreen> createState() => _LearnHubScreenState();
}

class _LearnHubScreenState extends State<LearnHubScreen> {
  List<Map<String, dynamic>> _subjects = [];
  int _selectedSubjectIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialAndPersistentData();
  }

  // 1️⃣ Pehle Disk/Asset se load karo (0ms UI), fir GitHub live sync
  Future<void> _loadInitialAndPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_learn_hub_data_json');

    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is List && mounted) {
          setState(() {
            _subjects = List<Map<String, dynamic>>.from(decoded);
          });
        }
      } catch (_) {}
    }

    // Agar cache khali ho toh local asset padho
    if (_subjects.isEmpty) {
      try {
        final String assetStr = await rootBundle.loadString('assets/data/learn_data.json');
        final decodedAsset = jsonDecode(assetStr);
        if (decodedAsset is List && mounted) {
          setState(() {
            _subjects = List<Map<String, dynamic>>.from(decodedAsset);
          });
        }
      } catch (_) {}
    }

    _fetchLiveGitHubLearnData();
  }

  // 🚀 DIRECT REALTIME GITHUB SYNC
  Future<void> _fetchLiveGitHubLearnData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> urls = [
      "https://raw.githubusercontent.com/zxcty54/quiz/main/learn_data.json?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/learn_data.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn_data.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final dynamic parsed = jsonDecode(utf8.decode(res.bodyBytes));
          List<Map<String, dynamic>> loadedList = [];
          if (parsed is List) {
            loadedList = List<Map<String, dynamic>>.from(parsed);
          } else if (parsed is Map && parsed['subjects'] is List) {
            loadedList = List<Map<String, dynamic>>.from(parsed['subjects']);
          }

          if (loadedList.isNotEmpty && mounted) {
            setState(() {
              _subjects = loadedList;
              if (_selectedSubjectIndex >= _subjects.length) {
                _selectedSubjectIndex = 0;
              }
              _isLoading = false;
            });

            // 💾 Phone ke permanent disk storage mein save
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('persistent_learn_hub_data_json', jsonEncode(loadedList));
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue is int) return Color(colorValue);
    if (colorValue is String) {
      try {
        String hex = colorValue.replaceAll('#', '').replaceAll('0x', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    if (_subjects.isEmpty && _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_subjects.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No subjects available")),
      );
    }

    final activeSubject = _subjects[_selectedSubjectIndex];
    final List chapters = activeSubject['chapters'] ?? [];
    final Color subjectColor = _parseColor(activeSubject['color']);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester Learn 🎓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 📌 POSITIONING STRIP
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exam-Focused Interactive Learning',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Concept ➔ Story ➔ Practice',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'BPSC • TRE • SSC • BSSC CGL • All Bihar Competitive Exams',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // 🚀 HORIZONTAL SUBJECT SELECTOR
          Container(
            height: 60,
            color: Theme.of(context).cardColor,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                final bool isSelected = index == _selectedSubjectIndex;
                final Color color = _parseColor(sub['color']);

                return GestureDetector(
                  onTap: () => setState(() => _selectedSubjectIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(sub['icon'] ?? '📚', style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          sub['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 📋 CHAPTER LIST WITH REFRESH INDICATOR
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF059669),
              onRefresh: _fetchLiveGitHubLearnData,
              child: chapters.isEmpty
                  ? const Center(
                      child: Text('No chapters available yet.', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chap = chapters[index];
                        final bool isAvailable = chap['isAvailable'] ?? false;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: subjectColor.withOpacity(0.12),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: subjectColor),
                              ),
                            ),
                            title: Text(
                              chap['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Row(
                              children: [
                                const Text('👨‍🏫 ', style: TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Text(
                                    chap['subtitle'] ?? 'Learn with Aman Sir & Raju',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isAvailable ? const Color(0xFF059669) : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: isAvailable
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF075E54),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LearnChatScreen(
                                            jsonUrl: chap['jsonUrl'] ?? '',
                                            chapterTitle: chap['title'] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Start ➔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  )
                                : const Icon(Icons.lock_clock_rounded, color: Colors.grey, size: 20),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

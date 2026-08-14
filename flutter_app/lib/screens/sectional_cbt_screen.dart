import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import '../widgets/latex_text.dart';
import '../widgets/cbt_widgets.dart';
import '../services/telegram_tracker.dart';
import '../services/user_stats_service.dart';

// ============================================================================
// 📱 SECTIONAL MOCKS LIST VIEW (100% DYNAMIC & ZERO-REBUILD)
// ============================================================================
class SectionalCbtTab extends StatefulWidget {
  final bool isDarkMode;
  const SectionalCbtTab({super.key, required this.isDarkMode});

  @override
  State<SectionalCbtTab> createState() => SectionalCbtTabState();
}

class SectionalCbtTabState extends State<SectionalCbtTab> {
  Map<String, dynamic> _sectionalData = {};
  bool _isLoading = true;
  String _selectedTarget = 'ALL';

  final Map<String, Map<String, dynamic>> _examMeta = {
    'bpsc': {'tag': 'STATE PCS', 'title': 'BPSC PCS', 'color': const Color(0xFF881337)},
    'ssc': {'tag': 'TCS PATTERN', 'title': 'SSC / NTPC', 'color': const Color(0xFF065F46)},
    'bssc_cgl': {'tag': 'GRADUATE', 'title': 'BSSC CGL', 'color': const Color(0xFF581C87)},
    'bssc_inter': {'tag': 'INTER LEVEL', 'title': 'BSSC 10+2', 'color': const Color(0xFF1E3A8A)},
    'bihar_si': {'tag': 'POLICE / DAROGA', 'title': 'BIHAR SI', 'color': const Color(0xFFD97706)},
  };

  final List<Color> _fallbackColors = [
    const Color(0xFFDC2626),
    const Color(0xFF0D9488),
    const Color(0xFF2563EB),
    const Color(0xFF4F46E5),
  ];

  @override
  void initState() {
    super.initState();
    fetchSectionalMocks(forceRefresh: true);
  }

  // 📰 FETCH LIVE JSON FROM GITHUB WITH CACHE BUSTER
  Future<void> fetchSectionalMocks({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'cached_sectional_data_json_v5';

    if (!forceRefresh) {
      String? cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        try {
          final data = jsonDecode(cachedJson);
          if (mounted) {
            setState(() {
              _sectionalData = data is Map<String, dynamic> ? data : {};
              _isLoading = false;
            });
          }
        } catch (_) {}
      }
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String url =
        "https://raw.githubusercontent.com/zxcty54/quiz/main/sectional_data.json?t=$timestamp";

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        String decoded = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decoded);

        if (mounted) {
          setState(() {
            _sectionalData = data is Map<String, dynamic> ? data : {};
            _isLoading = false;
          });
        }
        await prefs.setString(cacheKey, decoded);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching Sectional Mocks: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final List<String> availableKeys = _sectionalData.keys.toList();

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async => await fetchSectionalMocks(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                const Text('🎯 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Target Exam Sectional Mocks',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 🎯 TOP DYNAMIC HORIZONTAL SCROLL CARDS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _targetExamChip('ALL', 'ALL EXAMS', 'Show All Mocks', const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  ...List.generate(availableKeys.length, (idx) {
                    final key = availableKeys[idx];
                    final meta = _examMeta[key] ?? {
                      'tag': 'TARGET EXAM',
                      'title': key.replaceAll('_', ' ').toUpperCase(),
                      'color': _fallbackColors[idx % _fallbackColors.length]
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _targetExamChip(key, meta['tag'], meta['title'], meta['color']),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 📋 SETS RENDER SECTION
            _buildSetsSection(cardBg),
          ],
        ),
      ),
    );
  }

  Widget _targetExamChip(String key, String tag, String title, Color activeColor) {
    bool isSelected = _selectedTarget == key;
    return InkWell(
      onTap: () => setState(() => _selectedTarget = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.15)
              : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tag, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: activeColor)),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsSection(Color cardBg) {
    List<Widget> sections = [];

    _sectionalData.forEach((key, value) {
      if (_selectedTarget != 'ALL' && _selectedTarget != key) return;

      Color themeColor = _examMeta[key]?['color'] ?? const Color(0xFF2563EB);

      // Single Object Map (Jaise BPSC)
      if (value is Map<String, dynamic>) {
        final String title = value['title'] ?? 'Special Zone';
        final int totalSets = value['total_sets'] ?? 10;
        final String pathPrefix = value['path_prefix'] ?? '$key/set';

        sections.add(_buildSetGroupCard(
          groupTitle: title,
          setsCount: totalSets,
          subFolder: pathPrefix,
          themeColor: themeColor,
          isPrefixPath: true,
        ));
      }
      // List Array (Jaise bihar_si, ssc, bssc_cgl, bssc_inter)
      else if (value is List) {
        for (var item in value) {
          if (item is Map<String, dynamic>) {
            final String title = item['title'] ?? 'Practice Sets';
            final int setsCount = item['sets'] ?? 5;
            final String folder = item['folder'] ?? key;

            sections.add(_buildSetGroupCard(
              groupTitle: title,
              setsCount: setsCount,
              subFolder: folder,
              themeColor: themeColor,
              isPrefixPath: false,
            ));
          }
        }
      }
    });

    if (sections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("No Sets Available for this Category", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(children: sections);
  }

  Widget _buildSetGroupCard({
    required String groupTitle,
    required int setsCount,
    required String subFolder,
    required Color themeColor,
    required bool isPrefixPath,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(groupTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(setsCount, (idx) {
              int setNum = idx + 1;
              String setLabel = "Set ${setNum.toString().padLeft(2, '0')}";

              return InkWell(
                onTap: () {
                  _loadAndLaunchTest(context, groupTitle, subFolder, setNum, isPrefixPath);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeColor, width: 1.2),
                  ),
                  child: Text(
                    setLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 🚀 ADAPTIVE GITHUB QUESTION FETCHER (Supports all naming formats: set1, set01, set_01)
  void _loadAndLaunchTest(BuildContext context, String title, String subFolder, int setNum, bool isPrefixPath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    String paddedSet = setNum.toString().padLeft(2, '0');
    List<String> candidateUrls = [];

    if (isPrefixPath) {
      candidateUrls = [
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder$setNum.json",
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder$paddedSet.json",
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder/$setNum.json",
      ];
    } else {
      candidateUrls = [
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder/set$setNum.json",
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder/set$paddedSet.json",
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder/set_$paddedSet.json",
        "https://raw.githubusercontent.com/zxcty54/quiz/main/$subFolder/set_$setNum.json",
      ];
    }

    http.Response? finalResponse;

    for (String url in candidateUrls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          finalResponse = res;
          break;
        }
      } catch (_) {}
    }

    if (mounted) Navigator.pop(context); // Close loading dialog

    if (finalResponse != null && finalResponse.statusCode == 200) {
      try {
        List parsed = jsonDecode(utf8.decode(finalResponse.bodyBytes));
        List<Question> qList = parsed.map((q) => Question.fromJson(q)).toList();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => SectionalCbtScreen(
                testTitle: "$title - Set $paddedSet",
                questions: qList,
                subFolder: subFolder,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid JSON formatting in Set $paddedSet: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find file on GitHub for Set $paddedSet in $subFolder')),
        );
      }
    }
  }
}

// ============================================================================
// 📝 ACTUAL CBT ENGINE & RESULT REPORT SCREEN
// ============================================================================
class SectionalCbtScreen extends StatefulWidget {
  final String testTitle;
  final List<Question> questions;
  final String subFolder;

  const SectionalCbtScreen({
    super.key,
    required this.testTitle,
    required this.questions,
    required this.subFolder,
  });

  @override
  State<SectionalCbtScreen> createState() => _SectionalCbtScreenState();
}

class _SectionalCbtScreenState extends State<SectionalCbtScreen> {
  int _currentIndex = 0;
  int _totalTimeSeconds = 25 * 60;
  Timer? _examTimer;

  bool _isHindi = false;
  final Map<int, int> _userAnswers = {};
  final Set<int> _markedForReview = {};
  final Map<int, int> _questionTimers = {};
  int _currentQTime = 0;
  Timer? _qTimer;

  bool _isExamSubmitted = false;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _isHindi = widget.subFolder.contains('bssc') ||
        widget.subFolder.contains('bpsc') ||
        widget.subFolder.contains('bihar_si');
    _startTimers();
    _checkBookmarkStatus();
  }

  void _startTimers() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalTimeSeconds > 0) {
        setState(() => _totalTimeSeconds--);
      } else {
        _submitExam();
      }
    });

    _qTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentQTime++;
      _questionTimers[_currentIndex] = (_questionTimers[_currentIndex] ?? 0) + 1;
    });
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _qTimer?.cancel();
    super.dispose();
  }

  void _selectOption(int optionIndex) => setState(() => _userAnswers[_currentIndex] = optionIndex);

  void _toggleReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
    });
  }

  // 📌 Check if Current Question is Bookmarked
  void _checkBookmarkStatus() async {
    final savedList = await UserStatsService.getSavedQuestions();
    final currentQ = widget.questions[_currentIndex];
    String currentText = currentQ.getText(_isHindi);

    bool exists = savedList.any((item) {
      String qText = item['qe'] ?? item['qh'] ?? '';
      return qText == currentText || qText == currentQ.qe;
    });

    if (mounted) {
      setState(() => _isBookmarked = exists);
    }
  }

  // 📌 Toggle Bookmark
  void _toggleBookmarkQuestion() async {
    final currentQ = widget.questions[_currentIndex];
    Map<String, dynamic> qJson = {
      'qe': currentQ.qe,
      'qh': currentQ.qh,
      'se': currentQ.se,
      'sh': currentQ.sh,
      'oe': currentQ.oe,
      'oh': currentQ.oh,
      'options': currentQ.getOptions(_isHindi),
      'answerIndex': currentQ.answerIndex,
      'explanation': currentQ.explanation,
    };

    bool saved = await UserStatsService.toggleBookmark(qJson);

    if (mounted) {
      setState(() => _isBookmarked = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? '📌 Question Bookmarked!' : '🗑️ Bookmark Removed'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // 🎯 EXAM SUBMISSION
  void _submitExam() async {
    _examTimer?.cancel();
    _qTimer?.cancel();
    setState(() => _isExamSubmitted = true);

    int correctCount = 0;
    int wrongCount = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAns = _userAnswers[i];

      if (userAns != null) {
        bool isCorrect = (userAns == q.answerIndex);
        final currentOptions = q.getOptions(_isHindi);

        if (isCorrect) {
          correctCount++;
          await UserStatsService.recordQuestionAttempt(
            isCorrect: true,
            chapterName: widget.testTitle,
            chapterPath: widget.subFolder,
          );
        } else {
          wrongCount++;
          await UserStatsService.recordQuestionAttempt(
            isCorrect: false,
            chapterName: widget.testTitle,
            chapterPath: widget.subFolder,
            wrongQuestionJson: {
              'qe': q.qe,
              'qh': q.qh,
              'se': q.se,
              'sh': q.sh,
              'oe': q.oe,
              'oh': q.oh,
              'options': currentOptions,
              'answerIndex': q.answerIndex,
              'explanation': q.explanation,
            },
            userSelectedOption: currentOptions[userAns],
          );
        }
      }
    }

    await UserStatsService.recordMockTest(questionsAttempted: _userAnswers.length);

    TelegramTracker.recordTestCompletion(
      widget.testTitle,
      "Sahi: $correctCount, Galat: $wrongCount / Total: ${widget.questions.length}",
    );
  }

  String _formatTime(int totalSec) {
    int m = totalSec ~/ 60;
    int s = totalSec % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isExamSubmitted) return _buildResultReportScreen();

    final currentQ = widget.questions[_currentIndex];
    final String qText = currentQ.getText(_isHindi);
    final List<String> currentOptions = currentQ.getOptions(_isHindi);
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(6)),
            child: Text(_formatTime(_totalTimeSeconds), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _isHindi = !_isHindi),
            child: Text(_isHindi ? "EN 🇬🇧" : "HI 🇮🇳", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => CbtPaletteDrawer(
                totalQuestions: widget.questions.length,
                currentIndex: _currentIndex,
                userAnswers: _userAnswers,
                markedForReview: _markedForReview,
                onSelectQuestion: (idx) {
                  setState(() => _currentIndex = idx);
                  _checkBookmarkStatus();
                },
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("QUESTION ${_currentIndex + 1} OF ${widget.questions.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                        color: _isBookmarked ? const Color(0xFF2563EB) : Colors.grey,
                      ),
                      onPressed: _toggleBookmarkQuestion,
                      tooltip: "Bookmark Question",
                    ),
                    IconButton(
                      icon: Icon(_markedForReview.contains(_currentIndex) ? Icons.rate_review : Icons.rate_review_outlined, color: _markedForReview.contains(_currentIndex) ? const Color(0xFF8E44AD) : Colors.grey),
                      onPressed: _toggleReview,
                      tooltip: "Mark for Review",
                    ),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LatexText("Q${_currentIndex + 1}. $qText", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4)),
                  const SizedBox(height: 12),

                  if (statements != null && statements.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: statements.asMap().entries.map((entry) {
                        int index = entry.key + 1;
                        String stmtText = entry.value.trim().replaceFirst(RegExp(r'^(\(\d+\)|\d+\.)\s*'), '');

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Color(0xFF2575FC), width: 4))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF2575FC), borderRadius: BorderRadius.circular(4)), child: Text("($index)", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              Expanded(child: LatexText(stmtText, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.4))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  ...List.generate(currentOptions.length, (optIdx) {
                    final isSelected = _userAnswers[_currentIndex] == optIdx;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () => _selectOption(optIdx),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            border: Border.all(color: isSelected ? const Color(0xFF2575FC) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isSelected ? const Color(0xFF2575FC) : Colors.grey.shade200,
                                child: Text(String.fromCharCode(65 + optIdx), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: LatexText(currentOptions[optIdx], style: TextStyle(fontSize: 13.5, color: Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentIndex > 0
                      ? () {
                          setState(() => _currentIndex--);
                          _checkBookmarkStatus();
                        }
                      : null,
                  child: const Text("← PREV"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.white),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Submit Mock Test?"),
                      content: Text("Attempted: ${_userAnswers.length} / ${widget.questions.length}"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                        ElevatedButton(onPressed: () { Navigator.pop(ctx); _submitExam(); }, child: const Text("Submit 🚀"))
                      ],
                    ),
                  ),
                  child: const Text("SUBMIT TEST"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2575FC), foregroundColor: Colors.white),
                  onPressed: () {
                    if (_currentIndex < widget.questions.length - 1) {
                      setState(() => _currentIndex++);
                      _checkBookmarkStatus();
                    } else {
                      _submitExam();
                    }
                  },
                  child: Text(_currentIndex < widget.questions.length - 1 ? "SAVE & NEXT →" : "FINISH"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📊 RESULT REPORT SCREEN (WITH BIHAR SI RULES)
  Widget _buildResultReportScreen() {
    int total = widget.questions.length;
    int correct = 0;
    int wrong = 0;

    _userAnswers.forEach((qIdx, userAns) {
      if (userAns == widget.questions[qIdx].answerIndex) { correct++; } else { wrong++; }
    });

    int attempted = _userAnswers.length;
    int skipped = total - attempted;

    double score = 0.0;
    double cutoffTarget = 22.00;
    String examName = "SSC / Central Exams";

    if (widget.subFolder.contains('bssc')) {
      score = (correct * 4) - (wrong * 1.0);
      cutoffTarget = 88.00;
      examName = "BSSC Graduate Level";
    } else if (widget.subFolder.contains('bpsc')) {
      score = (correct * 1.0) - (wrong * 0.33);
      cutoffTarget = 21.00;
      examName = "BPSC Prelims";
    } else if (widget.subFolder.contains('bihar_si')) {
      score = (correct * 2.0) - (wrong * 0.40);
      cutoffTarget = 130.00;
      examName = "Bihar SI Prelims";
    } else {
      score = (correct * 1.0) - (wrong * 0.25);
      cutoffTarget = 22.00;
    }

    bool isCleared = score >= cutoffTarget;

    return Scaffold(
      appBar: AppBar(title: const Text("Performance Summary")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(isCleared ? "CUTOFF CLEARED!" : "FAILED TO CLEAR CUTOFF", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCleared ? Colors.green : Colors.red)),
            const SizedBox(height: 16),

            CbtPieChartCard(correct: correct, wrong: wrong, skipped: skipped),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _scoreRow("Total Questions", "$total"),
                    _scoreRow("Attempted", "$attempted"),
                    _scoreRow("Correct Answers", "$correct", color: Colors.green),
                    _scoreRow("Wrong Answers", "$wrong", color: Colors.red),
                    _scoreRow("Skipped", "$skipped"),

                    if (wrong > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Text("🎯", style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Galat questions Vault me save ho gaye hain! Deep AI Trap Analysis ke liye Profile ➔ Wrong Question Vault dekhein.",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.bold,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 20),
                    _scoreRow("Exam Cutoff", "$cutoffTarget Marks ($examName)"),
                    _scoreRow("Your Final Score", score.toStringAsFixed(2), color: const Color(0xFF2575FC), isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Align(alignment: Alignment.centerLeft, child: Text("Detailed Review & Explanations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),

            ...List.generate(widget.questions.length, (i) {
              final q = widget.questions[i];
              final userAns = _userAnswers[i];
              final isCorrect = userAns == q.answerIndex;
              final timeSpent = _questionTimers[i] ?? 0;
              final options = q.getOptions(_isHindi);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Q${i + 1}. ${q.getText(_isHindi)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text("Your Answer: ${userAns != null ? options[userAns] : 'Skipped'}", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Correct Answer: ${options[q.answerIndex]}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("⏱️ Time Spent: ${timeSpent}s", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LatexText("Explanation: ${q.explanation.isNotEmpty ? q.explanation : 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 10),

                            if (!isCorrect && userAns != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Row(
                                  children: [
                                    Text("💡", style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "AI Analysis ke liye apne Profile ke 'Wrong Question Vault' par jayein.",
                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            WikiContributionBox(
                              subFolder: widget.subFolder,
                              qIndex: i,
                              questionSnippet: q.getText(_isHindi),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

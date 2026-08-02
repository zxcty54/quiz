import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// 🎲 Deterministic PRNG Generator (Exact seed logic for identical questions for friend)
class SeededRandom {
  int h;
  SeededRandom(String seedString) : h = _hash(seedString);

  static int _hash(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = (31 * hash + str.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash;
  }

  double nextDouble() {
    h = ((h ^ (h >> 16)) * 2246822507) & 0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 3266489909) & 0xFFFFFFFF;
    h = (h ^ (h >> 16)) & 0xFFFFFFFF;
    return (h & 0xFFFFFFFF) / 4294967296.0;
  }
}

class SprintChallengeScreen extends StatefulWidget {
  final Map<String, dynamic> subjectMapping;
  final String? roomSets;
  final int? vsScore;

  const SprintChallengeScreen({
    super.key,
    required this.subjectMapping,
    this.roomSets,
    this.vsScore,
  });

  @override
  State<SprintChallengeScreen> createState() => _SprintChallengeScreenState();
}

class _SprintChallengeScreenState extends State<SprintChallengeScreen> {
  static const String cdnBase = "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/";

  bool _isLoading = false;
  int _currentScreen = 0; // 0: Intro, 1: Quiz, 2: Result

  List<Map<String, dynamic>> _activeQuestions = [];
  int _currentQuestionIndex = 0;
  final Map<int, int> _userSelectedAnswers = {};

  Timer? _timer;
  int _timeRemaining = 300; // 5 Minutes
  int _finalScore = 0;
  String _activeRoomSignature = "";

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 🚀 FETCH QUESTIONS DIRECTLY FROM SUBJECT_MAPPING.JSON
  Future<void> _startSprintFromSubjectMapping() async {
    setState(() {
      _isLoading = true;
    });

    List<String> validMappedPaths = [];
    widget.subjectMapping.forEach((subjectKey, mappings) {
      if (subjectKey != 'current_mapping' && mappings is Map) {
        mappings.forEach((chapterName, jsonPath) {
          if (jsonPath != null && jsonPath.toString().isNotEmpty) {
            validMappedPaths.add(jsonPath.toString());
          }
        });
      }
    });

    if (validMappedPaths.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Subject mapping loading error!')),
      );
      return;
    }

    List<int> pickedIndices = [];

    if (widget.roomSets != null && widget.roomSets!.contains('-')) {
      _activeRoomSignature = widget.roomSets!;
      pickedIndices = widget.roomSets!.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    } else {
      List<int> tempIndices = [];
      for (int i = 0; i < 4 && i < validMappedPaths.length; i++) {
        tempIndices.add((DateTime.now().microsecondsSinceEpoch + i * 7) % validMappedPaths.length);
      }
      pickedIndices = tempIndices;
      _activeRoomSignature = pickedIndices.join('-');
    }

    final prng = SeededRandom(_activeRoomSignature);

    List<String> selectedJsonPaths = [];
    for (int idx in pickedIndices) {
      int safeIdx = idx % validMappedPaths.length;
      selectedJsonPaths.add(validMappedPaths[safeIdx]);
    }

    List<Map<String, dynamic>> masterMixPool = [];

    try {
      final responses = await Future.wait(
        selectedJsonPaths.map((path) => http.get(Uri.parse("$cdnBase$path"))),
      );

      for (var res in responses) {
        if (res.statusCode == 200) {
          List rawArray = jsonDecode(utf8.decode(res.bodyBytes));

          for (var item in rawArray) {
            String qText = item['qe'] ?? item['q'] ?? item['question'] ?? '';
            List rawOpts = item['o'] ?? item['options'] ?? [];
            dynamic ans = item['a'] ?? 0;
            String exp = item['e'] ?? item['explanation'] ?? '';

            if (qText.isEmpty || rawOpts.isEmpty) continue;

            List<Map<String, dynamic>> mappedOptions = [];
            for (int optIdx = 0; optIdx < rawOpts.length; optIdx++) {
              mappedOptions.add({'text': rawOpts[optIdx].toString(), 'origIdx': optIdx});
            }

            for (int k = mappedOptions.length - 1; k > 0; k--) {
              int j = (prng.nextDouble() * (k + 1)).floor();
              var temp = mappedOptions[k];
              mappedOptions[k] = mappedOptions[j];
              mappedOptions[j] = temp;
            }

            int correctIdx = 0;
            if (ans is String && int.tryParse(ans) == null) {
              correctIdx = mappedOptions.indexWhere((o) => o['text'] == ans);
            } else {
              int targetOrig = int.tryParse(ans.toString()) ?? 0;
              correctIdx = mappedOptions.indexWhere((o) => o['origIdx'] == targetOrig);
            }
            if (correctIdx == -1) correctIdx = 0;

            masterMixPool.add({
              'q': qText,
              'o': mappedOptions.map((e) => e['text'].toString()).toList(),
              'a': correctIdx,
              'e': exp,
            });
          }
        }
      }

      for (int i = masterMixPool.length - 1; i > 0; i--) {
        int j = (prng.nextDouble() * (i + 1)).floor();
        var temp = masterMixPool[i];
        masterMixPool[i] = masterMixPool[j];
        masterMixPool[j] = temp;
      }

      if (mounted) {
        setState(() {
          _activeQuestions = masterMixPool.take(10).toList();
          _currentQuestionIndex = 0;
          _userSelectedAnswers.clear();
          _timeRemaining = 300;
          _isLoading = false;
          _currentScreen = 1;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Network Error: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() => _timeRemaining--);
      } else {
        _timer?.cancel();
        _evaluateResults();
      }
    });
  }

  void _evaluateResults() {
    _timer?.cancel();
    int correct = 0;
    for (int i = 0; i < _activeQuestions.length; i++) {
      if (_userSelectedAnswers[i] == _activeQuestions[i]['a']) {
        correct++;
      }
    }
    setState(() {
      _finalScore = correct;
      _currentScreen = 2;
    });
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _shareChallenge(String platform) async {
    final String shareUrl = "https://www.mocktester.online/p/speed-run.html?sprint_duel=true&room_sets=$_activeRoomSignature&vs_score=$_finalScore";
    final String message = "🔥 I scored $_finalScore/10 on MockTester's Live Subject Challenge! Can you beat my score on the exact same set? Challenge Link: $shareUrl";

    String targetUri = "";
    if (platform == 'whatsapp') {
      targetUri = "https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}";
    } else {
      targetUri = "https://t.me/share/url?url=${Uri.encodeComponent(shareUrl)}&text=${Uri.encodeComponent(message)}";
    }

    try {
      await launchUrl(Uri.parse(targetUri), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $platform')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text('🎯 Accuracy Sprint Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.vsScore != null && _currentScreen == 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEA580C), borderRadius: BorderRadius.circular(6)),
                        child: const Text('⚔️ LIVE DUEL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your friend scored ${widget.vsScore}/10 on this room set! Can you beat them?',
                          style: const TextStyle(color: Color(0xFFC2410C), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_currentScreen == 0) _buildIntroScreen(),
              if (_currentScreen == 1) _buildQuizScreen(),
              if (_currentScreen == 2) _buildResultScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Text('🎯 ACCURACY DRILL', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            const Text('Challenge Your Friend', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 8),
            const Text('Polity, History, Science, Geography & Economy se 10 high-yield questions ka mix challenge!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatBadge('⏱️ 5 Mins'),
                const SizedBox(width: 8),
                _buildStatBadge('📝 10 Levels'),
                const SizedBox(width: 8),
                _buildStatBadge('📊 Core Mix'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startSprintFromSubjectMapping,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('🚀 Start Mastery Sprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizScreen() {
    final currentQ = _activeQuestions[_currentQuestionIndex];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Question ${_currentQuestionIndex + 1} of 10', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                  child: Text('Time: ${_formatTime(_timeRemaining)}', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: (_currentQuestionIndex + 1) / 10, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)), minHeight: 6),
            ),
            const SizedBox(height: 20),
            Text(currentQ['q'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.4)),
            const SizedBox(height: 20),
            ...List.generate(currentQ['o'].length, (optIdx) {
              bool isSelected = _userSelectedAnswers[_currentQuestionIndex] == optIdx;
              return InkWell(
                onTap: () => setState(() => _userSelectedAnswers[_currentQuestionIndex] = optIdx),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(currentQ['o'][optIdx], style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF1E40AF) : Colors.black87, fontSize: 13)),
                ),
              );
            }),
            const SizedBox(height: 16),
            if (_userSelectedAnswers.containsKey(_currentQuestionIndex))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentQuestionIndex < 9) {
                      setState(() => _currentQuestionIndex++);
                    } else {
                      _evaluateResults();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text(_currentQuestionIndex == 9 ? 'Finish Sprint 🏁' : 'Next Level ➡️', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    Widget? duelStatusCard;
    if (widget.vsScore != null) {
      if (_finalScore > widget.vsScore!) {
        duelStatusCard = _buildStatusCard('🏆 🎉 BOOM! Aapne apne dost ko hara diya!', 'Aapka Score: $_finalScore/10 | Dost ka Score: ${widget.vsScore}/10', const Color(0xFFECFDF5), const Color(0xFF10B981), const Color(0xFF065F46));
      } else if (_finalScore == widget.vsScore) {
        duelStatusCard = _buildStatusCard('🤝 Match Tie Ho Gaya!', 'Dono ne barabar perform kiya! Score: $_finalScore/10', const Color(0xFFFEF3C7), const Color(0xFFF59E0B), const Color(0xFF92400E));
      } else {
        duelStatusCard = _buildStatusCard('💥 Oh! Dost baazi maar le gaya!', 'Dost ka Score: ${widget.vsScore}/10 | Aapka Score: $_finalScore/10', const Color(0xFFFEF2F2), const Color(0xFFEF4444), const Color(0xFF991B1B));
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Sprint Completed!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Score: $_finalScore/10', style: const TextStyle(fontWeight: FontWeight.extrabold, fontSize: 28, color: Color(0xFF059669))),
            const SizedBox(height: 16),

            if (duelStatusCard != null) ...[duelStatusCard, const SizedBox(height: 16)],

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text('⚔️ Challenge Your Friends!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Kya koi aapka score beat kar sakta hai? Share karein!', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _shareChallenge('whatsapp'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _shareChallenge('telegram'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Telegram', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _currentScreen = 0),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              child: const Text('🔄 Play Another Random Sprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusCard(String title, String subtitle, Color bg, Color border, Color text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 1.5), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: text, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: text, fontSize: 12)),
        ],
      ),
    );
  }
}

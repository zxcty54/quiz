import 'package:flutter/material.dart';
import '../screens/student_cbt_report_screen.dart';
import '../utils/subtopic_engine.dart';

class StudentIntelligenceSheet extends StatefulWidget {
  final List<dynamic> batches;
  final List<dynamic> rawSubmissions;
  final List<dynamic> batchTests;
  final bool isDarkMode;

  const StudentIntelligenceSheet({
    super.key,
    required this.batches,
    required this.rawSubmissions,
    required this.batchTests,
    required this.isDarkMode,
  });

  @override
  State<StudentIntelligenceSheet> createState() =>
      _StudentIntelligenceSheetState();
}

class _StudentIntelligenceSheetState
    extends State<StudentIntelligenceSheet> {
  String _selectedBatchFilter = 'ALL';
  String _selectedTestId = 'ALL';
  bool _showOnlyEnrolledRoster = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color primary = Color(0xFF2563EB);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color purple = Color(0xFF7C3AED);

  Color get cardColor =>
      widget.isDarkMode ? const Color(0xFF172033) : Colors.white;

  Color get surfaceColor =>
      widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  Color get textColor =>
      widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

  Color get mutedTextColor =>
      widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // WEAK TOPIC ENGINE
  // ---------------------------------------------------------------------------

  String _resolveAccurateWeakTopic(
    Map<String, dynamic> submission,
    Map<String, dynamic>? parentTest,
  ) {
    final List responses =
        (submission['detailed_responses'] is List)
            ? submission['detailed_responses']
            : [];

    if (responses.isEmpty) {
      return submission['weak_subject']?.toString() ?? 'All Clear';
    }

    final Map<String, int> wrongTopicFrequencies = {};

    for (var item in responses) {
      if (item is Map) {
        final bool isCorrect =
            item['is_correct'] == true || item['isCorrect'] == true;

        if (!isCorrect) {
          final String chapter =
              (item['chapter'] ?? item['topic'] ?? '').toString();

          final String qe =
              (item['question_en'] ??
                      item['qe'] ??
                      item['question'] ??
                      '')
                  .toString();

          final String qh =
              (item['question_hi'] ?? item['qh'] ?? '').toString();

          final List<dynamic>? se =
              item['statements_en'] is List
                  ? List<dynamic>.from(item['statements_en'])
                  : null;

          final List<dynamic>? sh =
              item['statements_hi'] is List
                  ? List<dynamic>.from(item['statements_hi'])
                  : null;

          final String subject =
              (item['subject'] ??
                      item['subFolder'] ??
                      parentTest?['subject'] ??
                      '')
                  .toString();

          final String detectedTopic =
              SubtopicEngine.extractSubtopic(
                chapterName: chapter,
                subjectName: subject,
                qe: qe,
                qh: qh,
                se: se,
                sh: sh,
              );

          wrongTopicFrequencies[detectedTopic] =
              (wrongTopicFrequencies[detectedTopic] ?? 0) + 1;
        }
      }
    }

    if (wrongTopicFrequencies.isNotEmpty) {
      return wrongTopicFrequencies.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return 'All Clear';
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _testTitle(Map<String, dynamic> test) {
    return (test['title'] ??
            test['test_title'] ??
            test['testTitle'] ??
            'Mock Drill')
        .toString();
  }

  String _studentName(Map<String, dynamic> submission) {
    final String directName =
        (submission['student_name'] ?? '').toString().trim();

    final String identifier =
        (submission['student_identifier'] ?? '').toString().trim();

    String name =
        directName.isNotEmpty
            ? directName
            : (identifier.isNotEmpty ? identifier : 'Aspirant');

    if (name.contains('•')) {
      name = name.split('•').first.trim();
    }

    if (name.contains('(')) {
      name = name.split('(').first.trim();
    }

    if (name.isEmpty || name.toLowerCase() == 'enrolled student') {
      name = 'Aspirant';
    }

    return name;
  }

  bool _isEnrolled(Map<String, dynamic> submission) {
    final String identifier =
        (submission['student_identifier'] ?? '').toString();

    return submission['is_enrolled'] == true ||
        identifier.contains('🎓 Enrolled') ||
        identifier.contains('Enrolled');
  }

  String _contactInfo(Map<String, dynamic> submission) {
    final String identifier =
        (submission['student_identifier'] ?? '').toString().trim();

    if (identifier.contains('Roll/Ph:')) {
      return identifier.split('Roll/Ph:').last.replaceAll(')', '').trim();
    }

    if (identifier.contains('Ph:')) {
      return identifier.split('Ph:').last.replaceAll(')', '').trim();
    }

    return '';
  }

  Map<String, dynamic>? _findParentTest(Map<String, dynamic> submission) {
    final String testId = (submission['test_id'] ?? '').toString();

    for (final test in widget.batchTests) {
      if ((test['id'] ?? '').toString() == testId) {
        return Map<String, dynamic>.from(test);
      }
    }

    return null;
  }

  double _score(Map<String, dynamic> submission) {
    return (submission['score'] as num?)?.toDouble() ?? 0.0;
  }

  int _accuracy(Map<String, dynamic> submission) {
    return (submission['accuracy'] as num?)?.toInt() ?? 0;
  }

  int _correct(Map<String, dynamic> submission) {
    return (submission['correct_count'] as num?)?.toInt() ?? 0;
  }

  int _wrong(Map<String, dynamic> submission) {
    return (submission['wrong_count'] as num?)?.toInt() ?? 0;
  }

  List _responses(Map<String, dynamic> submission) {
    return submission['detailed_responses'] is List
        ? submission['detailed_responses']
        : [];
  }

  String _weaknessLabel(Map<String, dynamic> submission) {
    final int accuracy = _accuracy(submission);

    if (accuracy < 40) return 'Critical';
    if (accuracy < 70) return 'Needs Practice';
    return 'Minor Gap';
  }

  Color _weaknessColor(Map<String, dynamic> submission) {
    final int accuracy = _accuracy(submission);

    if (accuracy < 40) return danger;
    if (accuracy < 70) return warning;
    return const Color(0xFFCA8A04);
  }

  List<Map<String, dynamic>> _getUniqueEnrolledStudents(List<dynamic> submissions) {
    final Map<String, Map<String, dynamic>> uniqueStudents = {};

    for (var raw in submissions) {
      final s = Map<String, dynamic>.from(raw);
      if (!_isEnrolled(s)) continue;

      final String name = _studentName(s);
      final String contact = _contactInfo(s);
      final String key = contact.isNotEmpty ? contact : name.toLowerCase();

      if (!uniqueStudents.containsKey(key)) {
        uniqueStudents[key] = {
          'name': name,
          'contact': contact,
          'total_attempts': 1,
          'total_score': _score(s),
          'highest_score': _score(s),
          'last_attempted_test': _findParentTest(s) != null
              ? _testTitle(_findParentTest(s)!)
              : 'Classroom Mock',
        };
      } else {
        uniqueStudents[key]!['total_attempts'] =
            (uniqueStudents[key]!['total_attempts'] as int) + 1;
        uniqueStudents[key]!['total_score'] =
            (uniqueStudents[key]!['total_score'] as double) + _score(s);

        final currentScore = _score(s);
        if (currentScore > (uniqueStudents[key]!['highest_score'] as double)) {
          uniqueStudents[key]!['highest_score'] = currentScore;
        }
      }
    }

    return uniqueStudents.values.toList();
  }

  // ---------------------------------------------------------------------------
  // UI COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 10.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _filterButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color:
              selected
                  ? primary
                  : (widget.isDarkMode
                      ? const Color(0xFF1E293B)
                      : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected
                    ? primary
                    : (widget.isDarkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: primary.withOpacity(.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : mutedTextColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : textColor,
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(String hint) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF263449)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim().toLowerCase();
          });
        },
        style: TextStyle(color: textColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: mutedTextColor, fontSize: 11.5),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: mutedTextColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  color: mutedTextColor,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _rosterToggleTabs(int totalAttempts, int totalEnrolled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF1E293B)
            : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _showOnlyEnrolledRoster = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_showOnlyEnrolledRoster ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Test Attempts ($totalAttempts)',
                  style: TextStyle(
                    color: !_showOnlyEnrolledRoster ? Colors.white : mutedTextColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _showOnlyEnrolledRoster = true;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _showOnlyEnrolledRoster ? success : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '🎓 Enrolled Roster ($totalEnrolled)',
                  style: TextStyle(
                    color: _showOnlyEnrolledRoster ? Colors.white : mutedTextColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color:
                widget.isDarkMode
                    ? const Color(0xFF263449)
                    : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: 8.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scoreBadge(double score) {
    Color color;

    if (score >= 80) {
      color = success;
    } else if (score >= 50) {
      color = warning;
    } else {
      color = danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'SCORE',
            style: TextStyle(
              color: color.withOpacity(.8),
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$value ',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      color: mutedTextColor,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ENROLLED DIRECTORY CARD
  // ---------------------------------------------------------------------------

  Widget _enrolledDirectoryCard(Map<String, dynamic> student) {
    final int attempts = student['total_attempts'] as int;
    final double totalScore = student['total_score'] as double;
    final double highestScore = student['highest_score'] as double;
    final double avgScore = attempts > 0 ? (totalScore / attempts) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: success.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? .10 : .03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: success.withOpacity(0.12),
            child: Text(
              student['name'].toString().isNotEmpty
                  ? student['name'][0].toUpperCase()
                  : 'A',
              style: const TextStyle(
                color: success,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 14, color: success),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  student['contact'].toString().isNotEmpty
                      ? 'Ph: ${student['contact']}'
                      : 'Classroom Verified Member',
                  style: TextStyle(color: mutedTextColor, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recent: ${student['last_attempted_test']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$attempts Mocks',
                  style: const TextStyle(
                    color: primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Avg: ${avgScore.toStringAsFixed(1)}',
                style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              Text(
                'Max: ${highestScore.toStringAsFixed(1)}',
                style: TextStyle(color: mutedTextColor, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STUDENT ATTEMPT CARD
  // ---------------------------------------------------------------------------

  Widget _studentCard(Map<String, dynamic> s) {
    final String displayName = _studentName(s);
    final bool enrolled = _isEnrolled(s);
    final String contact = _contactInfo(s);

    final double score = _score(s);
    final int accuracy = _accuracy(s);
    final int correct = _correct(s);
    final int wrong = _wrong(s);
    final List responses = _responses(s);

    final Map<String, dynamic>? parentTest = _findParentTest(s);

    final String matchedTestTitle =
        parentTest != null
            ? _testTitle(parentTest)
            : 'Classroom CBT Test';

    final String weakTopic =
        _resolveAccurateWeakTopic(s, parentTest);

    final bool hasWeakTopic =
        weakTopic.isNotEmpty && weakTopic != 'All Clear';

    final Color weaknessColor = _weaknessColor(s);
    final String weaknessLabel = _weaknessLabel(s);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color:
              widget.isDarkMode
                  ? const Color(0xFF263449)
                  : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              widget.isDarkMode ? .10 : .035,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (enrolled) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: success.withOpacity(.09),
                                borderRadius:
                                    BorderRadius.circular(5),
                                border: Border.all(
                                  color: success.withOpacity(.20),
                                ),
                              ),
                              child: const Text(
                                'ENROLLED',
                                style: TextStyle(
                                  color: success,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$matchedTestTitle'
                        '${contact.isNotEmpty ? '  •  $contact' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                _scoreBadge(score),
              ],
            ),

            const SizedBox(height: 13),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Accuracy',
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$accuracy%',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (accuracy / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor:
                    widget.isDarkMode
                        ? const Color(0xFF273449)
                        : const Color(0xFFEFF2F6),
                valueColor: AlwaysStoppedAnimation<Color>(
                  accuracy >= 80
                      ? success
                      : accuracy >= 50
                          ? warning
                          : danger,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _statItem(
                  icon: Icons.check_circle_outline,
                  value: '$correct',
                  label: 'Correct',
                  color: success,
                ),
                _statItem(
                  icon: Icons.cancel_outlined,
                  value: '$wrong',
                  label: 'Wrong',
                  color: danger,
                ),
                _statItem(
                  icon: Icons.track_changes,
                  value: '$accuracy%',
                  label: 'Accuracy',
                  color: purple,
                ),
              ],
            ),

            if (hasWeakTopic) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: weaknessColor.withOpacity(.055),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: weaknessColor.withOpacity(.16),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: weaknessColor.withOpacity(.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.priority_high_rounded,
                        size: 15,
                        color: weaknessColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Needs Attention',
                                style: TextStyle(
                                  color: weaknessColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                decoration: BoxDecoration(
                                  color: weaknessColor
                                      .withOpacity(.10),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  weaknessLabel,
                                  style: TextStyle(
                                    color: weaknessColor,
                                    fontSize: 7,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            weakTopic,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.analytics_outlined,
                  size: 16,
                ),
                label: const Text(
                  'View Detailed Analysis',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () {
                  if (responses.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Detailed response is not available for this attempt.',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentCbtReportScreen(
                        studentName: displayName,
                        testTitle: matchedTestTitle,
                        score: score,
                        responseBreakdown: responses,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final batchSubmissions =
        widget.rawSubmissions.where((s) {
          if (_selectedBatchFilter == 'ALL') return true;

          return (s['batch_id'] ?? '')
                  .toString()
                  .trim() ==
              _selectedBatchFilter.trim();
        }).toList();

    final batchTests =
        widget.batchTests.where((t) {
          if (_selectedBatchFilter == 'ALL') return true;

          return (t['batch_id'] ?? '')
                  .toString()
                  .trim() ==
              _selectedBatchFilter.trim();
        }).toList();

    // Unique Enrolled Students
    final enrolledStudents = _getUniqueEnrolledStudents(batchSubmissions);

    // Analytics
    double totalScoreSum = 0;
    final Map<String, int> weakFrequency = {};

    for (final rawSubmission in batchSubmissions) {
      final s = Map<String, dynamic>.from(rawSubmission);

      totalScoreSum += _score(s);

      final parentTest = _findParentTest(s);

      final weak =
          _resolveAccurateWeakTopic(
            s,
            parentTest,
          );

      if (weak.isNotEmpty && weak != 'All Clear') {
        weakFrequency[weak] =
            (weakFrequency[weak] ?? 0) + 1;
      }
    }

    final double avgBatchScore =
        batchSubmissions.isNotEmpty
            ? totalScoreSum / batchSubmissions.length
            : 0;

    final String topWeakArea =
        weakFrequency.isNotEmpty
            ? weakFrequency.entries
                .reduce(
                  (a, b) =>
                      a.value > b.value ? a : b,
                )
                .key
            : 'All Concepts Stable';

    // Filter by Assessment
    final baseSubmissions = batchSubmissions.where((s) {
      if (_selectedTestId == 'ALL') return true;

      return (s['test_id'] ?? '')
              .toString()
              .trim() ==
          _selectedTestId.trim();
    }).toList();

    // Filter by Search Query
    final filteredSubmissions = baseSubmissions.where((s) {
      if (_searchQuery.isEmpty) return true;

      final name = _studentName(s).toLowerCase();
      final contact = _contactInfo(s).toLowerCase();
      final identifier = (s['student_identifier'] ?? '').toString().toLowerCase();
      final weak = (s['weak_subject'] ?? '').toString().toLowerCase();

      return name.contains(_searchQuery) ||
          contact.contains(_searchQuery) ||
          identifier.contains(_searchQuery) ||
          weak.contains(_searchQuery);
    }).toList();

    // Filter Enrolled Roster by Search Query
    final filteredEnrolled = enrolledStudents.where((st) {
      if (_searchQuery.isEmpty) return true;

      final name = st['name'].toString().toLowerCase();
      final contact = st['contact'].toString().toLowerCase();
      return name.contains(_searchQuery) || contact.contains(_searchQuery);
    }).toList();

    final int totalCorrect = batchSubmissions.fold(
      0,
      (sum, s) =>
          sum +
          ((s['correct_count'] as num?)?.toInt() ?? 0),
    );

    final int totalWrong = batchSubmissions.fold(
      0,
      (sum, s) =>
          sum +
          ((s['wrong_count'] as num?)?.toInt() ?? 0),
    );

    final int overallAccuracy =
        (totalCorrect + totalWrong) > 0
            ? ((totalCorrect /
                        (totalCorrect + totalWrong)) *
                    100)
                .round()
            : 0;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * .92,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                10,
                8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Intelligence',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Performance & learning insights',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  24,
                ),
                children: [
                  _sectionTitle(
                    'Classroom',
                    subtitle: 'Choose a batch to view performance',
                  ),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterButton(
                          label: 'All Batches',
                          icon: Icons.public_rounded,
                          selected: _selectedBatchFilter == 'ALL',
                          onTap: () {
                            setState(() {
                              _selectedBatchFilter = 'ALL';
                              _selectedTestId = 'ALL';
                            });
                          },
                        ),
                        ...widget.batches.map((b) {
                          final String id = (b['id'] ?? '').toString();
                          final String name = (b['batch_name'] ?? 'Batch').toString();

                          return Padding(
                            padding: const EdgeInsets.only(left: 7),
                            child: _filterButton(
                              label: name,
                              icon: Icons.school_outlined,
                              selected: _selectedBatchFilter == id,
                              onTap: () {
                                setState(() {
                                  _selectedBatchFilter = id;
                                  _selectedTestId = 'ALL';
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Segmented Tab Switcher (Attempts vs Enrolled Directory)
                  _rosterToggleTabs(batchSubmissions.length, enrolledStudents.length),

                  if (_showOnlyEnrolledRoster) ...[
                    // VIEW 1: ENROLLED DIRECTORY
                    _searchBar('Search by enrolled student name or phone...'),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Verified Classroom Roster',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${filteredEnrolled.length} enrolled',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (filteredEnrolled.isEmpty)
                      _emptyStateContainer(
                        icon: Icons.person_off_outlined,
                        title: 'No enrolled students found',
                        subtitle: 'No candidates enrolled in this batch yet or match the search.',
                      )
                    else
                      ...filteredEnrolled.map((st) => _enrolledDirectoryCard(st)),
                  ] else ...[
                    // VIEW 2: TEST ATTEMPTS & ANALYTICS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.isDarkMode
                              ? const [Color(0xFF172554), Color(0xFF172033)]
                              : const [Color(0xFFEFF6FF), Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary.withOpacity(.14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedBatchFilter == 'ALL'
                                      ? 'Overall Performance'
                                      : 'Batch Performance',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(.09),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${batchSubmissions.length} attempts',
                                  style: const TextStyle(
                                    color: primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              _metricCard(
                                title: 'AVERAGE SCORE',
                                value: avgBatchScore.toStringAsFixed(1),
                                icon: Icons.leaderboard_outlined,
                                color: primary,
                              ),
                              const SizedBox(width: 8),
                              _metricCard(
                                title: 'OVERALL ACCURACY',
                                value: '$overallAccuracy%',
                                icon: Icons.track_changes_rounded,
                                color: purple,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: widget.isDarkMode
                                    ? const Color(0xFF263449)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: danger.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.priority_high_rounded,
                                    color: danger,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TOP WEAK AREA',
                                        style: TextStyle(
                                          color: mutedTextColor,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        topWeakArea,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _sectionTitle(
                      'Assessment',
                      subtitle: 'Filter students by CBT mock drill',
                    ),
                    const SizedBox(height: 8),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterButton(
                            label: 'All Tests (${batchSubmissions.length})',
                            icon: Icons.view_list_outlined,
                            selected: _selectedTestId == 'ALL',
                            onTap: () {
                              setState(() {
                                _selectedTestId = 'ALL';
                              });
                            },
                          ),
                          ...batchTests.map((t) {
                            final String testId = (t['id'] ?? '').toString();
                            final int count = batchSubmissions
                                .where((s) => (s['test_id'] ?? '').toString() == testId)
                                .length;

                            return Padding(
                              padding: const EdgeInsets.only(left: 7),
                              child: _filterButton(
                                label: '${_testTitle(t)} ($count)',
                                icon: Icons.assignment_outlined,
                                selected: _selectedTestId == testId,
                                onTap: () {
                                  setState(() {
                                    _selectedTestId = testId;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Search input
                    _searchBar('Search student name, phone, or weak concept...'),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Student Attempts',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${filteredSubmissions.length} shown',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (filteredSubmissions.isEmpty)
                      _emptyStateContainer(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'No attempts found',
                        subtitle: 'Try changing your search query or assessment filter.',
                      )
                    else
                      ...filteredSubmissions.map(
                        (raw) => _studentCard(
                          Map<String, dynamic>.from(raw),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateContainer({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 48,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF263449)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primary.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

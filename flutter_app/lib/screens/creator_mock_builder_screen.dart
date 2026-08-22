import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorMockBuilderScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorMockBuilderScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorMockBuilderScreen> createState() => _CreatorMockBuilderScreenState();
}

class _CreatorMockBuilderScreenState extends State<CreatorMockBuilderScreen> {
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController(text: 'General Studies');
  final _timeCtrl = TextEditingController(text: '10');

  // Active Question Card Controllers
  final _qCtrl = TextEditingController();
  final _opACtrl = TextEditingController();
  final _opBCtrl = TextEditingController();
  final _opCCtrl = TextEditingController();
  final _opDCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  int _selectedAnswerIndex = 0;

  int _currentQuestionIndex = 0;
  final List<Map<String, dynamic>> _savedQuestions = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addNewQuestionDraft();
  }

  // 🪄 Magic Splitter Logic for PDF/Raw Text Paste
  Map<String, dynamic> _splitRawQuestionText(String raw) {
    String question = '';
    String opA = '', opB = '', opC = '', opD = '', exp = '';
    int ansIdx = 0;

    final text = raw.replaceAll('\r\n', '\n');

    final optAReg = RegExp(r'[(]?[A|a][)]?[\.:\s]');
    final optBReg = RegExp(r'[(]?[B|b][)]?[\.:\s]');
    final optCReg = RegExp(r'[(]?[C|c][)]?[\.:\s]');
    final optDReg = RegExp(r'[(]?[D|d][)]?[\.:\s]');
    final ansReg = RegExp(r'(?:Ans|Answer)[\.:\s]', caseSensitive: false);
    final expReg = RegExp(r'(?:Exp|Explanation)[\.:\s]', caseSensitive: false);

    if (optAReg.hasMatch(text) && optBReg.hasMatch(text)) {
      final aMatch = optAReg.firstMatch(text)!;
      question = text.substring(0, aMatch.start).replaceFirst(RegExp(r'^(?:Q\d+|\d+)[\.:\s]*'), '').trim();

      final remaining = text.substring(aMatch.start);
      final lines = remaining.split('\n');

      for (var l in lines) {
        final line = l.trim();
        if (optAReg.hasMatch(line) && !line.toLowerCase().contains('ans')) {
          opA = line.replaceFirst(optAReg, '').trim();
        } else if (optBReg.hasMatch(line)) {
          opB = line.replaceFirst(optBReg, '').trim();
        } else if (optCReg.hasMatch(line)) {
          opC = line.replaceFirst(optCReg, '').trim();
        } else if (optDReg.hasMatch(line)) {
          opD = line.replaceFirst(optDReg, '').trim();
        } else if (ansReg.hasMatch(line)) {
          final val = line.replaceFirst(ansReg, '').trim().toUpperCase();
          if (val.contains('A') || val.startsWith('1')) ansIdx = 0;
          if (val.contains('B') || val.startsWith('2')) ansIdx = 1;
          if (val.contains('C') || val.startsWith('3')) ansIdx = 2;
          if (val.contains('D') || val.startsWith('4')) ansIdx = 3;
        } else if (expReg.hasMatch(line)) {
          exp = line.replaceFirst(expReg, '').trim();
        }
      }
    } else {
      question = text.trim();
    }

    return {
      'q': question,
      'a': opA,
      'b': opB,
      'c': opC,
      'd': opD,
      'ans': ansIdx,
      'exp': exp,
    };
  }

  void _addNewQuestionDraft() {
    _saveCurrentToMemory();
    _qCtrl.clear();
    _opACtrl.clear();
    _opBCtrl.clear();
    _opCCtrl.clear();
    _opDCtrl.clear();
    _expCtrl.clear();
    _selectedAnswerIndex = 0;
    _currentQuestionIndex = _savedQuestions.length;
    setState(() {});
  }

  void _loadQuestionIntoForm(int index) {
    _saveCurrentToMemory();
    if (index >= 0 && index < _savedQuestions.length) {
      final q = _savedQuestions[index];
      _qCtrl.text = q['qh'] ?? '';
      final List opts = q['oh'] ?? ['', '', '', ''];
      _opACtrl.text = opts.isNotEmpty ? opts[0] : '';
      _opBCtrl.text = opts.length > 1 ? opts[1] : '';
      _opCCtrl.text = opts.length > 2 ? opts[2] : '';
      _opDCtrl.text = opts.length > 3 ? opts[3] : '';
      _selectedAnswerIndex = q['a'] ?? 0;
      _expCtrl.text = q['eh'] ?? '';
      _currentQuestionIndex = index;
      setState(() {});
    }
  }

  void _deleteCurrentQuestion() {
    if (_savedQuestions.isEmpty) return;
    if (_currentQuestionIndex < _savedQuestions.length) {
      _savedQuestions.removeAt(_currentQuestionIndex);
    }
    if (_savedQuestions.isEmpty) {
      _addNewQuestionDraft();
    } else {
      int nextIdx = _currentQuestionIndex > 0 ? _currentQuestionIndex - 1 : 0;
      _loadQuestionIntoForm(nextIdx);
    }
  }

  void _saveCurrentToMemory() {
    if (_qCtrl.text.trim().isEmpty) return;

    final qData = {
      'id': _currentQuestionIndex + 1,
      'qh': _qCtrl.text.trim(),
      'qe': _qCtrl.text.trim(),
      'oh': [_opACtrl.text.trim(), _opBCtrl.text.trim(), _opCCtrl.text.trim(), _opDCtrl.text.trim()],
      'oe': [_opACtrl.text.trim(), _opBCtrl.text.trim(), _opCCtrl.text.trim(), _opDCtrl.text.trim()],
      'a': _selectedAnswerIndex,
      'eh': _expCtrl.text.trim(),
      'ee': _expCtrl.text.trim(),
    };

    if (_currentQuestionIndex < _savedQuestions.length) {
      _savedQuestions[_currentQuestionIndex] = qData;
    } else {
      _savedQuestions.add(qData);
    }
  }

  void _openMagicPasteModal() {
    final rawInputCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 Paste Raw Question (From PDF / Text)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('App will auto-split into Question, Options & Answer.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: rawInputCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste here e.g.:\n1. Bihar ki rajdhani?\nA) Patna\nB) Gaya\nC) Bhagalpur\nD) Ranchi\nAns: A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (rawInputCtrl.text.trim().isNotEmpty) {
                    final res = _splitRawQuestionText(rawInputCtrl.text.trim());
                    setState(() {
                      _qCtrl.text = res['q'];
                      _opACtrl.text = res['a'];
                      _opBCtrl.text = res['b'];
                      _opCCtrl.text = res['c'];
                      _opDCtrl.text = res['d'];
                      _selectedAnswerIndex = res['ans'];
                      _expCtrl.text = res['exp'];
                    });
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('✨ Auto-Fill Form'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _publishToSupabase() async {
    _saveCurrentToMemory();
    if (_titleCtrl.text.trim().isEmpty || _savedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a Title and at least 1 Question!')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;

      // 1. Insert into creator_mocks and get back created row (with UUID id)
      final mockResponse = await client.from('creator_mocks').insert({
        'creator_id': widget.creatorHandle,
        'title': _titleCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim().isEmpty ? 'General Studies' : _subjectCtrl.text.trim(),
        'duration_mins': int.tryParse(_timeCtrl.text.trim()) ?? 10,
        'questions_json': _savedQuestions,
      }).select().single();

      final createdMockId = mockResponse['id'];

      // 2. 🚀 Automatically create an announcement post in Community Feed
      await client.from('community_posts').insert({
        'creator_id': widget.creatorHandle,
        'content': '⚡ New High-Yield Mock Drill Published: "${_titleCtrl.text.trim()}". Contains ${_savedQuestions.length} questions. Attempt now!',
        'tag': 'Mock Tests ⚡',
        'mock_id': createdMockId,
        'views_count': 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Test & Community Announcement Published!'),
          backgroundColor: Color(0xFF16A34A),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Creator Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _openMagicPasteModal,
            icon: const Icon(Icons.paste_rounded, color: Colors.amber),
            tooltip: 'Paste Full Question',
          ),
          if (_savedQuestions.isNotEmpty)
            IconButton(
              onPressed: _deleteCurrentQuestion,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Delete this question',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Test Title', isDense: true, border: OutlineInputBorder())),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(controller: _timeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mins', isDense: true, border: OutlineInputBorder())),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...List.generate(_savedQuestions.length, (idx) {
                    final isCurrent = idx == _currentQuestionIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('Q${idx + 1}'),
                        selected: isCurrent,
                        onSelected: (_) => _loadQuestionIntoForm(idx),
                      ),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Add Q'),
                    onPressed: _addNewQuestionDraft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Question #${_currentQuestionIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          onPressed: _openMagicPasteModal,
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Quick Split Paste', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _qCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Enter question text...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    const Text('Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    _buildOptionInput('A', _opACtrl, 0),
                    const SizedBox(height: 6),
                    _buildOptionInput('B', _opBCtrl, 1),
                    const SizedBox(height: 6),
                    _buildOptionInput('C', _opCCtrl, 2),
                    const SizedBox(height: 6),
                    _buildOptionInput('D', _opDCtrl, 3),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Explanation (Optional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addNewQuestionDraft,
                    icon: const Icon(Icons.add),
                    label: const Text('Next Question'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _publishToSupabase,
                    icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded),
                    label: const Text('Publish Test', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionInput(String label, TextEditingController ctrl, int idx) {
    final isSelected = _selectedAnswerIndex == idx;
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedAnswerIndex = idx),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(label, style: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(hintText: 'Option $label', isDense: true, border: const OutlineInputBorder()),
          ),
        ),
      ],
    );
  }
}

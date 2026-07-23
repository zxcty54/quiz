class Question {
  final String qe; // English Question
  final String? qh; // Hindi Question
  final List<String>? se; // Statements English
  final List<String>? sh; // Statements Hindi
  final List<String> options; // Options list
  final int answerIndex; // Correct answer index (0-based)
  final String explanation; // Explanation text

  Question({
    required this.qe,
    this.qh,
    this.se,
    this.sh,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    // 1. Question Text Parsing
    String mainQe = json['qe'] ?? json['q'] ?? json['question'] ?? '';
    String? mainQh = json['qh'];

    // 2. Statements List Parsing (se / sh)
    List<String>? stmtE;
    if (json['se'] != null) {
      stmtE = List<String>.from(json['se']);
    }

    List<String>? stmtH;
    if (json['sh'] != null) {
      stmtH = List<String>.from(json['sh']);
    }

    // 3. Options Parsing (o / options)
    List<String> opts = [];
    if (json['o'] != null) {
      opts = List<String>.from(json['o'].map((item) => item.toString().split('|')[0].trim()));
    } else if (json['options'] != null) {
      opts = List<String>.from(json['options']);
    }

    // 4. Answer Index Parsing (a / answer)
    int ansIdx = 0;
    if (json['a'] != null) {
      ansIdx = json['a'] is int ? json['a'] : int.tryParse(json['a'].toString()) ?? 0;
    } else if (json['answer'] != null) {
      ansIdx = json['answer'] is int ? json['answer'] : int.tryParse(json['answer'].toString()) ?? 0;
    }

    // 5. Explanation Parsing (e / explanation)
    String exp = json['e'] ?? json['explanation'] ?? '';

    return Question(
      qe: mainQe,
      qh: mainQh,
      se: stmtE,
      sh: stmtH,
      options: opts,
      answerIndex: ansIdx,
      explanation: exp,
    );
  }
}

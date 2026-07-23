class Question {
  final String qe; // English Question Text
  final String? qh; // Hindi Question Text
  final List<String>? se; // Statements English
  final List<String>? sh; // Statements Hindi
  final List<String> options; // Options List
  final int answerIndex; // Correct Answer Index (0-based)
  final String explanation; // Explanation / Solution

  Question({
    required this.qe,
    this.qh,
    this.se,
    this.sh,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  // 🎯 SMART TEXT GETTER (Fixes missing getText error & White screen fallback)
  String getText(bool isHindi) {
    if (isHindi) {
      if (qh != null && qh!.trim().isNotEmpty) return qh!;
      if (qe.trim().isNotEmpty) return qe;
    } else {
      if (qe.trim().isNotEmpty) return qe;
      if (qh != null && qh!.trim().isNotEmpty) return qh!;
    }
    return "Question text not available.";
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    // 1. Question Text Parsing
    String mainQe = json['qe'] ?? json['q'] ?? json['question'] ?? '';
    String? mainQh = json['qh'];

    // 2. Statements List Parsing (se / sh)
    List<String>? stmtE = json['se'] != null ? List<String>.from(json['se']) : null;
    List<String>? stmtH = json['sh'] != null ? List<String>.from(json['sh']) : null;

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

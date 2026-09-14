class Question {
  final String qe;
  final String? qh;
  final List<String>? se;
  final List<String>? sh;
  final List<String>? oe;
  final List<String>? oh;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String? ee;
  final String? eh;

  Question({
    required this.qe,
    this.qh,
    this.se,
    this.sh,
    this.oe,
    this.oh,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    this.ee,
    this.eh,
  });

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

  List<String> getOptions(bool isHindi) {
    if (isHindi) {
      if (oh != null && oh!.isNotEmpty) return oh!;
      if (oe != null && oe!.isNotEmpty) return oe!;
    } else {
      if (oe != null && oe!.isNotEmpty) return oe!;
      if (oh != null && oh!.isNotEmpty) return oh!;
    }
    return options.isNotEmpty ? options : ["Option text not available."];
  }

  String getExplanation(bool isHindi) {
    if (isHindi) {
      if (eh != null && eh!.trim().isNotEmpty) return eh!;
      if (explanation.trim().isNotEmpty) return explanation;
      if (ee != null && ee!.trim().isNotEmpty) return ee!;
    } else {
      if (ee != null && ee!.trim().isNotEmpty) return ee!;
      if (explanation.trim().isNotEmpty) return explanation;
      if (eh != null && eh!.trim().isNotEmpty) return eh!;
    }
    return explanation.trim().isNotEmpty ? explanation : "Explanation not available.";
  }

  String get question => qe.isNotEmpty ? qe : (qh ?? '');
  String? get questionHindi => qh;
  String get questionText => getText(false);
  int get answer => answerIndex;
  int get correctOptionIndex => answerIndex;
  String? get subject => null;

  factory Question.fromJson(Map<String, dynamic> json) {
    String mainQe = json['qe'] ?? json['q'] ?? json['question'] ?? '';
    String? mainQh = json['qh'] ?? json['question_hindi'];

    List<String>? stmtE = json['se'] != null ? List<String>.from(json['se']) : null;
    List<String>? stmtH = json['sh'] != null ? List<String>.from(json['sh']) : null;

    List<String>? optsE = json['oe'] != null ? List<String>.from(json['oe']) : null;
    List<String>? optsH = json['oh'] != null ? List<String>.from(json['oh']) : null;

    List<String> opts = [];
    if (json['o'] != null) {
      opts = List<String>.from(json['o'].map((item) => item.toString().split('|')[0].trim()));
    } else if (json['options'] != null) {
      opts = List<String>.from(json['options']);
    } else if (optsE != null && optsE.isNotEmpty) {
      opts = optsE;
    } else if (optsH != null && optsH.isNotEmpty) {
      opts = optsH;
    }

    // 🎯 FIXED: Robust Answer Index Parser (Handles "A", "B", "C", "D", 0, 1, 2, 3, etc.)
    int ansIdx = 0;
    final dynamic rawAns = json['a'] ?? json['answerIndex'] ?? json['answer'];

    if (rawAns != null) {
      if (rawAns is int) {
        ansIdx = rawAns;
      } else {
        final String cleanAns = rawAns.toString().trim().toUpperCase();
        if (cleanAns == 'A' || cleanAns == '(A)') {
          ansIdx = 0;
        } else if (cleanAns == 'B' || cleanAns == '(B)') {
          ansIdx = 1;
        } else if (cleanAns == 'C' || cleanAns == '(C)') {
          ansIdx = 2;
        } else if (cleanAns == 'D' || cleanAns == '(D)') {
          ansIdx = 3;
        } else {
          ansIdx = int.tryParse(cleanAns) ?? 0;
        }
      }
    }

    String exp = json['e'] ?? json['explanation'] ?? '';
    String? expE = json['ee'];
    String? expH = json['eh'];

    return Question(
      qe: mainQe,
      qh: mainQh,
      se: stmtE,
      sh: stmtH,
      oe: optsE,
      oh: optsH,
      options: opts,
      answerIndex: ansIdx,
      explanation: exp,
      ee: expE,
      eh: expH,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qe': qe,
      'qh': qh,
      'se': se,
      'sh': sh,
      'oe': oe,
      'oh': oh,
      'options': options,
      'answerIndex': answerIndex,
      'a': answerIndex,
      'explanation': explanation,
      'e': explanation,
      'ee': ee,
      'eh': eh,
    };
  }
}

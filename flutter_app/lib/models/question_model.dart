class Question {
  final String qe; // English Question Text
  final String? qh; // Hindi Question Text
  final List<String>? se; // Statements English
  final List<String>? sh; // Statements Hindi
  final List<String>? oe; // Options English
  final List<String>? oh; // Options Hindi
  final List<String> options; // Options List (Legacy / Default Fallback)
  final int answerIndex; // Correct Answer Index (0-based)
  final String explanation; // Explanation / Solution (Fallback)
  final String? ee; // English Detailed Explanation
  final String? eh; // Hindi Detailed Explanation

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

  // 🎯 SMART TEXT GETTER (Handles Bilingual Question Text)
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

  // 🌐 SMART OPTIONS GETTER (Handles Bilingual Options oe & oh)
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

  // 💡 SMART EXPLANATION GETTER (Handles Direct 'e' and Bilingual 'ee'/'eh')
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

  // 🛡️ COMPATIBILITY GETTERS
  String get question => qe.isNotEmpty ? qe : (qh ?? '');
  String get questionHindi => qh;
  String get questionText => getText(false);
  int get answer => answerIndex;
  int get correctOptionIndex => answerIndex;
  String? get subject => null;

  // 🚀 DESERIALIZER: JSON -> Question
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

    int ansIdx = 0;
    if (json['a'] != null) {
      ansIdx = json['a'] is int ? json['a'] : int.tryParse(json['a'].toString()) ?? 0;
    } else if (json['answerIndex'] != null) {
      ansIdx = json['answerIndex'] is int ? json['answerIndex'] : int.tryParse(json['answerIndex'].toString()) ?? 0;
    } else if (json['answer'] != null) {
      ansIdx = json['answer'] is int ? json['answer'] : int.tryParse(json['answer'].toString()) ?? 0;
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

  // 💾 SERIALIZER: Question -> JSON (Fixes Build Failure)
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

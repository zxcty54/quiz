class Question {
  final String questionEn;
  final String questionHi;
  final List<String>? statementsEn;
  final List<String>? statementsHi;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  Question({
    required this.questionEn,
    required this.questionHi,
    this.statementsEn,
    this.statementsHi,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      questionEn: json['qe'] ?? '',
      questionHi: json['qh'] ?? '',
      statementsEn: json['se'] != null ? List<String>.from(json['se']) : null,
      statementsHi: json['sh'] != null ? List<String>.from(json['sh']) : null,
      options: List<String>.from(json['o'] ?? []),
      answerIndex: json['a'] ?? 0,
      explanation: json['e'] ?? '',
    );
  }
}

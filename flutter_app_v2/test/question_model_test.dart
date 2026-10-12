import 'package:flutter_test/flutter_test.dart';
import 'package:mocktester_v2/core/models/question_model.dart';

void main() {
  group('Question.fromJson', () {
    test('reads the short bilingual schema (qe/qh/oe/oh/a/e)', () {
      final Question q = Question.fromJson(<String, dynamic>{
        'qe': 'What is the capital of Bihar?',
        'qh': 'बिहार की राजधानी क्या है?',
        'oe': <String>['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur'],
        'oh': <String>['पटना', 'गया', 'भागलपुर', 'मुजफ्फरपुर'],
        'a': 'A',
        'e': 'Patna is the capital of Bihar.',
      });

      expect(q.qe, 'What is the capital of Bihar?');
      expect(q.qh, 'बिहार की राजधानी क्या है?');
      expect(q.answerIndex, 0, reason: '"A" must map to index 0');
      expect(q.getText(false), startsWith('What is the capital'));
      expect(q.getText(true), startsWith('बिहार'));
      expect(q.getOptions(false).first, 'Patna');
    });

    test('accepts numeric and long-form answer keys', () {
      expect(
        Question.fromJson(<String, dynamic>{'qe': 'x', 'a': 3}).answerIndex,
        3,
      );
      expect(
        Question.fromJson(<String, dynamic>{'qe': 'x', 'answerIndex': 2})
            .answerIndex,
        2,
      );
      expect(
        Question.fromJson(<String, dynamic>{'qe': 'x', 'answer': 'C'})
            .answerIndex,
        2,
      );
    });

    test('splits pipe-separated options and falls back gracefully', () {
      final Question q = Question.fromJson(<String, dynamic>{
        'qe': 'Pick one',
        'o': <String>['Alpha|a', 'Beta|b', 'Gamma|c'],
        'a': 1,
      });
      expect(q.options, <String>['Alpha', 'Beta', 'Gamma']);
      expect(q.getExplanation(false), 'Explanation not available.');
    });

    test('round-trips through toJson', () {
      final Question original = Question.fromJson(<String, dynamic>{
        'qe': 'Round trip?',
        'options': <String>['yes', 'no'],
        'answerIndex': 0,
        'explanation': 'because',
      });
      final Question copy = Question.fromJson(original.toJson());
      expect(copy.qe, original.qe);
      expect(copy.options, original.options);
      expect(copy.answerIndex, original.answerIndex);
      expect(copy.explanation, original.explanation);
    });

    test('prefers Hindi text only when it is available', () {
      final Question englishOnly =
          Question.fromJson(<String, dynamic>{'qe': 'Only English'});
      expect(englishOnly.getText(true), 'Only English');

      final Question hindiOnly =
          Question.fromJson(<String, dynamic>{'qh': 'केवल हिंदी'});
      expect(hindiOnly.getText(false), 'केवल हिंदी');
    });
  });
}

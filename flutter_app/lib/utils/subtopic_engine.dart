import 'subtopic_dictionary.dart';

class SubtopicEngine {
  /// 🎯 Taxonomy-Aligned Multi-Statement Subtopic Extractor
  static String extractSubtopic({
    required String chapterName,
    String? subjectName,
    required String? qe,
    required String? qh,
    List<dynamic>? se,
    List<dynamic>? sh,
  }) {
    // 1. Combine all bilingual fields into a single search string
    final StringBuffer buffer = StringBuffer();
    if (qe != null) buffer.write('$qe ');
    if (qh != null) buffer.write('$qh ');
    if (se != null) buffer.write('${se.join(" ")} ');
    if (sh != null) buffer.write('${sh.join(" ")} ');

    final String searchContext = buffer.toString().toLowerCase();

    // 2. Resolve target subject (e.g., 'physics', 'history', 'geography')
    String targetDomain = (subjectName ?? '').trim().toLowerCase();
    if (targetDomain.isEmpty || targetDomain == 'general' || targetDomain == 'all') {
      targetDomain = _detectSubjectFromKeywords(searchContext);
    }

    String? bestMatchedChapter;
    String? bestMatchedSubtopic;
    int maxKeywordLength = 0;

    // 3. Scan taxonomy (Target domain match first)
    for (var subjectEntry in SubtopicDictionary.taxonomy.entries) {
      final String currentSubjectName = subjectEntry.key.toLowerCase();

      // Skip subjects that don't match our active domain (prevents cross-subject bleed)
      if (targetDomain.isNotEmpty && !_isSubjectCompatible(targetDomain, currentSubjectName)) {
        continue;
      }

      for (var chapterEntry in subjectEntry.value.entries) {
        final String currentChapterKey = chapterEntry.key;

        for (var subtopicEntry in chapterEntry.value.entries) {
          final String subtopicKey = subtopicEntry.key;
          final List<String> keywords = subtopicEntry.value;

          for (var keyword in keywords) {
            final cleanKeyword = keyword.trim().toLowerCase();
            if (cleanKeyword.isEmpty) continue;

            // Prioritize whole-word or exact phrase containment
            if (searchContext.contains(cleanKeyword)) {
              if (cleanKeyword.length > maxKeywordLength) {
                maxKeywordLength = cleanKeyword.length;
                bestMatchedChapter = _formatTitle(currentChapterKey);
                bestMatchedSubtopic = _formatTitle(subtopicKey);
              }
            }
          }
        }
      }
    }

    // 4. Return hierarchical topic if matched
    if (bestMatchedChapter != null && bestMatchedSubtopic != null) {
      return '$bestMatchedChapter > $bestMatchedSubtopic';
    }

    // 5. Fallback strictly within the same subject domain
    return _getDefaultBySubject(targetDomain, chapterName);
  }

  /// Check broad subject compatibility (e.g., 'science' maps to 'physics'/'chemistry'/'biology')
  static bool _isSubjectCompatible(String activeDomain, String taxonomyDomain) {
    if (activeDomain == taxonomyDomain) return true;
    if (activeDomain == 'science' && 
       (taxonomyDomain == 'physics' || taxonomyDomain == 'chemistry' || taxonomyDomain == 'biology')) {
      return true;
    }
    return false;
  }

  /// Detect broad subject from Hindi / English terms
  static String _detectSubjectFromKeywords(String text) {
    // Science / Physics
    if (text.contains('ध्वनि') || text.contains('चाल') || text.contains('तरंग') ||
        text.contains('प्रकाश') || text.contains('वेग') || text.contains('ठोस') ||
        text.contains('द्रव') || text.contains('गैस') || text.contains('निर्वात') ||
        text.contains('ऊर्जा') || text.contains('sound') || text.contains('velocity') ||
        text.contains('vacuum') || text.contains('unit') || text.contains('si unit')) {
      return 'physics';
    }

    // History
    if (text.contains('कांग्रेस') || text.contains('अध्यक्ष') || text.contains('अधिवेशन') ||
        text.contains('क्रांति') || text.contains('विद्रोह') || text.contains('सत्याग्रह') ||
        text.contains('गांधी') || text.contains('मुगल') || text.contains('1857')) {
      return 'history';
    }

    // Polity
    if (text.contains('संविधान') || text.contains('अनुच्छेद') || text.contains('राष्ट्रपति') ||
        text.contains('चुनाव') || text.contains('आयुक्त') || text.contains('संसद')) {
      return 'polity';
    }

    // Geography
    if (text.contains('अक्षांश') || text.contains('देशांतर') || text.contains('नदी') ||
        text.contains('पर्वत') || text.contains('मानसून') || text.contains('latitude')) {
      return 'geography';
    }

    return 'general';
  }

  static String _getDefaultBySubject(String subject, String chapterName) {
    if (chapterName.trim().isNotEmpty) return _formatTitle(chapterName);

    switch (subject) {
      case 'physics':
      case 'science':
        return 'General Physics > Mechanics & Wave Motion';
      case 'history':
        return 'Indian History > Modern Indian History';
      case 'polity':
        return 'Indian Polity > Constitutional Framework';
      case 'geography':
        return 'Physical Geography > Earth & Landforms';
      default:
        return 'General Studies > Core Revision';
    }
  }

  static String _formatTitle(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

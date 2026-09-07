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
    // 1. Combine bilingual fields into context
    final StringBuffer buffer = StringBuffer();
    if (qe != null) buffer.write('$qe ');
    if (qh != null) buffer.write('$qh ');
    if (se != null) buffer.write('${se.join(" ")} ');
    if (sh != null) buffer.write('${sh.join(" ")} ');

    final String searchContext = buffer.toString().toLowerCase();

    // 2. Resolve target domain normalized to Taxonomy exact Keys
    String targetTaxonomyKey = _resolveTaxonomyKey(subjectName, searchContext);

    String? bestMatchedChapter;
    String? bestMatchedSubtopic;
    int maxKeywordLength = 0;

    // 3. Scan Taxonomy (Only for the resolved subject domain)
    for (var subjectEntry in SubtopicDictionary.taxonomy.entries) {
      final String currentSubject = subjectEntry.key; // e.g. "History", "Geography"

      // Lock to target domain strictly if resolved
      if (targetTaxonomyKey.isNotEmpty && targetTaxonomyKey != currentSubject) {
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

            // Check containment
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

    // 4. Return subtopic if taxonomy match hit
    if (bestMatchedChapter != null && bestMatchedSubtopic != null) {
      return '$bestMatchedChapter > $bestMatchedSubtopic';
    }

    // 5. Fallback within the exact resolved subject domain
    return _getDefaultByTaxonomy(targetTaxonomyKey, chapterName);
  }

  /// Maps subjectName or keyword presence strictly to Taxonomy Keys:
  /// "Physics", "Chemistry", "Biology", "History", "Polity", "Geography", "Economics"
  static String _resolveTaxonomyKey(String? subjectName, String text) {
    final s = (subjectName ?? '').trim().toLowerCase();

    // Direct match from question/batch subjectName
    if (s.contains('hist') || s.contains('इतिहास')) return 'History';
    if (s.contains('geo') || s.contains('भूगोल')) return 'Geography';
    if (s.contains('pol') || s.contains('संविधान') || s.contains('राजव्यवस्था') || s.contains('civics')) return 'Polity';
    if (s.contains('econ') || s.contains('अर्थशास्त्र')) return 'Economics';
    if (s.contains('phys') || s.contains('भौतिक')) return 'Physics';
    if (s.contains('chem') || s.contains('रसायन')) return 'Chemistry';
    if (s.contains('bio') || s.contains('जीव')) return 'Biology';

    // Weighted keyword resolution if subjectName is empty/general
    int historyScore = 0;
    int geographyScore = 0;
    int polityScore = 0;
    int scienceScore = 0;
    int economicsScore = 0;

    // History keywords
    for (var w in [
      'गांधी', 'कांग्रेस', 'अधिवेशन', 'क्रांति', 'विद्रोह', 'मुगल', '1857',
      'अशोक', 'मौर्य', 'हड़प्पा', 'सत्याग्रह', 'वायसराय', 'गवर्नर', 'आंदोलन',
      'history', 'gandhi', 'congress', 'harappa', 'revolt', 'viceroy'
    ]) {
      if (text.contains(w)) historyScore += 3;
    }

    // Geography keywords (generic terms given lower weight to prevent bleed)
    for (var w in [
      'अक्षांश', 'देशांतर', 'मानसून', 'पर्वतमाला', 'चक्रवात', 'ज्वालामुखी',
      'latitude', 'longitude', 'monsoon', 'cyclone', 'plateau', 'soil'
    ]) {
      if (text.contains(w)) geographyScore += 3;
    }
    if (text.contains('नदी') || text.contains('river')) {
      if (historyScore == 0) geographyScore += 1;
    }

    // Polity keywords
    for (var w in [
      'संविधान', 'अनुच्छेद', 'संसद', 'राष्ट्रपति', 'लोकसभा', 'राज्यसभा',
      'न्यायालय', 'constitution', 'article', 'parliament', 'supreme court'
    ]) {
      if (text.contains(w)) polityScore += 3;
    }

    // Economics keywords
    for (var w in [
      'जीडीपी', 'बजट', 'मुद्रास्फीति', 'आरबीआई', 'राजकोषीय', 'बैंक',
      'gdp', 'inflation', 'rbi', 'fiscal', 'deficit', 'banking'
    ]) {
      if (text.contains(w)) economicsScore += 3;
    }

    // Science keywords
    for (var w in [
      'तरंग', 'ध्वनि', 'प्रकाश', 'विद्युत', 'कोशिका', 'परमाणु', 'वेग',
      'velocity', 'wave', 'cell', 'atom', 'electricity'
    ]) {
      if (text.contains(w)) scienceScore += 3;
    }

    final scores = {
      'History': historyScore,
      'Geography': geographyScore,
      'Polity': polityScore,
      'Economics': economicsScore,
      'Physics': scienceScore,
    };

    var top = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (top.value > 0) return top.key;

    return '';
  }

  static String _getDefaultByTaxonomy(String taxonomyKey, String chapterName) {
    if (chapterName.trim().isNotEmpty && chapterName.toLowerCase() != 'general') {
      return _formatTitle(chapterName);
    }

    switch (taxonomyKey) {
      case 'History':
        return 'Modern India > National Movement';
      case 'Geography':
        return 'Indian Geography > Physiographic Divisions';
      case 'Polity':
        return 'Constitutional Framework > Constitution Making';
      case 'Economics':
        return 'Basic Economic Concepts > National Income';
      case 'Physics':
        return 'Mechanics > Motion And Kinematics';
      case 'Chemistry':
        return 'Basic Concepts Of Chemistry > Atomic Structure';
      case 'Biology':
        return 'Cell Biology > Cell Structure';
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

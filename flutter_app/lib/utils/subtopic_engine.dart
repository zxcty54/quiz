import 'subtopic_dictionary.dart';

class SubtopicEngine {
  /// 🎯 Multi-Statement & Bilingual Compatible Subtopic Extractor
  static String extractSubtopic({
    required String chapterName,
    required String? qe,
    required String? qh,
    List<dynamic>? se,
    List<dynamic>? sh,
  }) {
    // 1. Combine all available question fields into a clean text block
    final StringBuffer buffer = StringBuffer();
    if (qe != null) buffer.write('$qe ');
    if (qh != null) buffer.write('$qh ');
    if (se != null) buffer.write('${se.join(" ")} ');
    if (sh != null) buffer.write('${sh.join(" ")} ');

    final String searchContext = buffer.toString().toLowerCase();
    final String cleanChapter = chapterName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ' ');

    String? bestMatchedChapter;
    String? bestMatchedSubtopic;
    int maxKeywordLength = 0;

    // 2. Scan entire taxonomy
    for (var subjectEntry in SubtopicDictionary.taxonomy.entries) {
      for (var chapterEntry in subjectEntry.value.entries) {
        final String currentChapterKey = chapterEntry.key;
        final String readableChapter = currentChapterKey.replaceAll('_', ' ');

        for (var subtopicEntry in chapterEntry.value.entries) {
          final String subtopicKey = subtopicEntry.key;
          final List<String> keywords = subtopicEntry.value;

          for (var keyword in keywords) {
            final cleanKeyword = keyword.trim().toLowerCase();
            if (cleanKeyword.isEmpty) continue;

            // Check if keyword is found as a distinct phrase in text or chapter path
            if (searchContext.contains(cleanKeyword) || cleanChapter.contains(cleanKeyword)) {
              // Higher weight to longer, more specific multi-word tokens
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

    // 3. Return best matched result
    if (bestMatchedChapter != null && bestMatchedSubtopic != null) {
      return '$bestMatchedChapter > $bestMatchedSubtopic';
    }

    // 4. Fallback if no specific keyword matched
    return chapterName.isNotEmpty ? _formatTitle(chapterName) : 'General Revision';
  }

  /// Helper to convert "reflection_and_mirrors" to "Reflection And Mirrors"
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

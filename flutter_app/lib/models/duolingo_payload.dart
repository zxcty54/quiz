class DuolingoPayload {
  final String microConcept;
  final List<String> steps;
  final String challengeQuestion;
  final Map<String, String> options;
  final String correctAnswer;
  final String explanation;

  DuolingoPayload({
    required this.microConcept,
    required this.steps,
    required this.challengeQuestion,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory DuolingoPayload.fromLlmText(String raw) {
    String concept = "";
    List<String> steps = [];
    String question = "";
    Map<String, String> options = {};
    String correct = "";
    String explanation = "";

    try {
      final lines = raw.split('\n').map((e) => e.trim()).toList();
      String currentSection = "";

      for (var line in lines) {
        if (line.isEmpty) continue;

        if (line.contains("Micro Concept:")) {
          currentSection = "concept";
          continue;
        } else if (line.contains("3-Step Breakdown:")) {
          currentSection = "steps";
          continue;
        } else if (line.contains("Micro Challenge:")) {
          currentSection = "challenge";
          continue;
        }

        switch (currentSection) {
          case "concept":
            if (concept.isEmpty) concept = line;
            break;
          case "steps":
            if (line.startsWith("•") || line.startsWith("-") || line.startsWith("*")) {
              steps.add(line.replaceFirst(RegExp(r'^[•\-\*]\s*'), ''));
            } else if (RegExp(r'^\d+\.').hasMatch(line)) {
              steps.add(line.replaceFirst(RegExp(r'^\d+\.\s*'), ''));
            }
            break;
          case "challenge":
            if (line.startsWith("Q:")) {
              question = line.replaceFirst("Q:", "").trim();
            } else if (line.contains("A)") && line.contains("B)")) {
              // Parse inline or split options
              final regex = RegExp(r'([A-D]\))\s*([^A-D]+)');
              for (final match in regex.allMatches(line)) {
                final key = match.group(1)?.replaceAll(')', '').trim() ?? '';
                final val = match.group(2)?.trim() ?? '';
                if (key.isNotEmpty) options[key] = val;
              }
            } else if (line.startsWith("Correct Answer:")) {
              correct = line.replaceFirst("Correct Answer:", "").trim().toUpperCase();
            } else if (line.startsWith("Explanation:")) {
              explanation = line.replaceFirst("Explanation:", "").trim();
            }
            break;
        }
      }
    } catch (_) {}

    return DuolingoPayload(
      microConcept: concept.isNotEmpty ? concept : raw,
      steps: steps,
      challengeQuestion: question,
      options: options,
      correctAnswer: correct,
      explanation: explanation,
    );
  }
}

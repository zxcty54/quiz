import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class LatexText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const LatexText(this.text, {super.key, this.style});

  // 🎯 EXACT WEBSITE CLEAN & FIX LATEX LOGIC IN DART
  static String cleanAndFixLaTeX(String rawStr) {
    if (rawStr.isEmpty) return "";
    String cleanText = rawStr;

    // 1. Fix double backslashes from JSON escaping (\\\\ -> \)
    cleanText = cleanText.replaceAll(r'\\', r'\');

    // 2. Fix spaces after backslash (\ frac -> \frac, \ theta -> \theta etc.)
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'\\\s+(frac|sqrt|sum|int|alpha|beta|theta|pi|deg|mu|varepsilon|delta|Phi|chi)', caseSensitive: false),
      (match) => '\\${match.group(1)}',
    );

    // 3. Fix text subscripts (\textA_1 -> A_1)
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'text([A-Z][a-z]?)(_?\{?(\d+)\}?)'),
      (match) => '${match.group(1)}_{${match.group(3)}}',
    );

    // 4. Auto-wrap raw LaTeX commands in $...$ if $ symbol is missing
    if (!cleanText.contains('\$')) {
      cleanText = cleanText.replaceAllMapped(
        RegExp(r'([\\](?:frac|sqrt|alpha|beta|theta|pi|mu|varepsilon|Delta|int|sum|delta|Phi|chi)\{[^}]*\}(?:\{[^}]*\})?)'),
        (match) => '\$${match.group(1)}\$',
      );
    }

    // 5. Clean up multiple dollars $$$$ -> $$
    cleanText = cleanText.replaceAll(RegExp(r'\$\$+'), '\$\$');

    return cleanText;
  }

  @override
  Widget build(BuildContext context) {
    // Clean string using Website Sanitizer Algorithm
    final String sanitizedText = cleanAndFixLaTeX(text);

    if (!sanitizedText.contains('\$')) {
      return Text(sanitizedText, style: style);
    }

    // Split text by '$' delimiter to separate normal words and math formulas
    final List<String> parts = sanitizedText.split('\$');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      final String part = parts[i];
      if (part.isEmpty) continue;

      if (i % 2 == 1) {
        // Inline Math Formula Engine (KaTeX/LaTeX)
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Math.tex(
                part.trim(),
                textStyle: style,
                onErrorFallback: (err) => Text('\$$part\$', style: style),
              ),
            ),
          ),
        );
      } else {
        // Plain Text
        spans.add(TextSpan(text: part, style: style));
      }
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: style ?? DefaultTextStyle.of(context).style,
      ),
    );
  }
}

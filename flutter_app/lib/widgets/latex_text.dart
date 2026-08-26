import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class LatexText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const LatexText(this.text, {super.key, this.style});

  // 1. HTML Formatting Cleaner
  static String cleanHtmlFormatting(String str) {
    if (str.isEmpty) return "";
    String cleaned = str;

    // <br>, <br/> ko newline (\n) me convert karein
    cleaned = cleaned.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Selective HTML tags clean karein (comparison symbols < aur > safe rahenge)
    cleaned = cleaned.replaceAll(
      RegExp(r'</?(b|i|u|strong|em|p|div|span|font)[^>]*>', caseSensitive: false),
      '',
    );

    return cleaned;
  }

  // 2. LaTeX Cleaner & Normalizer
  static String cleanAndFixLaTeX(String rawStr) {
    if (rawStr.isEmpty) return "";

    String cleanText = cleanHtmlFormatting(rawStr);

    // Double backslashes fix
    cleanText = cleanText.replaceAll(r'\\', r'\');

    // Fix \t tab character typos (jaise \tmu -> \mu, \ttext -> \text)
    cleanText = cleanText.replaceAll(r'\tmu', r'\mu');
    cleanText = cleanText.replaceAll(r'\ttext', r'\text');

    // Backslash ke baad ke extra spaces remove karein
    cleanText = cleanText.replaceAllMapped(
      RegExp(
        r'\\\s+(frac|sqrt|sum|int|alpha|beta|theta|pi|deg|mu|nu|lambda|varepsilon|delta|Delta|Phi|chi|approx|times|implies|le|ge)',
        caseSensitive: false,
      ),
      (match) => '\\${match.group(1)}',
    );

    // Auto-wrap standalone commands in $...$ agar $ missing ho
    if (!cleanText.contains('\$')) {
      // Bracket wali commands (\frac{a}{b}, \sqrt{x})
      cleanText = cleanText.replaceAllMapped(
        RegExp(
          r'(\\(?:frac|sqrt)\{[^}]*\}\{[^}]*\}|\\(?:sqrt)\{[^}]*\})',
        ),
        (match) => '\$${match.group(1)}\$',
      );

      // Standalone Greek/Math symbols (\mu, \lambda, \theta, \nu, \approx, \times)
      cleanText = cleanText.replaceAllMapped(
        RegExp(
          r'(\\(?:mu|lambda|theta|nu|alpha|beta|pi|Delta|delta|approx|times|implies)(?![a-zA-Z]))',
        ),
        (match) => '\$${match.group(1)}\$',
      );
    }

    // Clean multiple dollars ($$$ -> $$)
    cleanText = cleanText.replaceAll(RegExp(r'\$\$+'), '\$\$');

    return cleanText;
  }

  @override
  Widget build(BuildContext context) {
    final String sanitizedText = cleanAndFixLaTeX(text);

    if (!sanitizedText.contains('\$')) {
      return Text(sanitizedText, style: style);
    }

    final List<String> parts = sanitizedText.split('\$');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      final String part = parts[i];
      if (part.isEmpty) continue;

      if (i % 2 == 1) {
        // LaTeX / Math mode
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Math.tex(
                part.trim(),
                textStyle: style,
                mathStyle: MathStyle.text,
                onErrorFallback: (err) {
                  // Agar parse fail ho toh LaTeX command ko readable Unicode fallback dein
                  String fallback = part
                      .replaceAll(r'\mu', 'μ')
                      .replaceAll(r'\lambda', 'λ')
                      .replaceAll(r'\theta', 'θ')
                      .replaceAll(r'\nu', 'ν')
                      .replaceAll(r'\times', '×')
                      .replaceAll(r'\approx', '≈')
                      .replaceAll(r'\text', '');
                  return Text(fallback, style: style);
                },
              ),
            ),
          ),
        );
      } else {
        // Normal text
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

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathFormattedText extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final TextAlign textAlign;

  const MathFormattedText({
    super.key,
    required this.text,
    this.textStyle,
    this.textAlign = TextAlign.start,
  });

  // 🧹 1. OCR & LaTeX Sanitizer (Fixes broken backslashes, tags, and formatting slips)
  static String sanitizeInput(String raw) {
    if (raw.isEmpty) return "";
    String clean = raw;

    // A. Fix Double-Escaped backslashes
    clean = clean.replaceAll(r'\\\\', r'\').replaceAll(r'\\', r'\');

    // B. Fix HTML entities
    clean = clean.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    // C. Fix OCR forward-slash typos for LaTeX commands (/frac -> \frac, /sqrt -> \sqrt)
    clean = clean.replaceAllMapped(
      RegExp(r'(?:^|\s)/([a-zA-Z]+)'),
      (m) => ' \\${m.group(1)}',
    );

    // D. Fix spaces after backslash (\ frac -> \frac, \ int -> \int)
    clean = clean.replaceAllMapped(
      RegExp(r'\\\s+([a-zA-Z]+)'),
      (m) => '\\${m.group(1)}',
    );

    // E. Fix OCR parentheses instead of braces: \frac(a)(b) -> \frac{a}{b}
    clean = clean.replaceAllMapped(
      RegExp(r'\\frac\s*\(([^)]+)\)\s*\(([^)]+)\)'),
      (m) => '\\frac{${m.group(1)}}{${m.group(2)}}',
    );
    clean = clean.replaceAllMapped(
      RegExp(r'\\sqrt\s*\(([^)]+)\)'),
      (m) => '\\sqrt{${m.group(1)}}',
    );

    // F. Auto-wrap naked LaTeX commands in $...$ if $ delimiters were dropped by OCR
    final List<String> mathKeywords = [
      'frac', 'sqrt', 'int', 'sum', 'Delta', 'delta', 'alpha', 'beta', 'gamma',
      'theta', 'lambda', 'mu', 'pi', 'sigma', 'omega', 'times', 'div', 'rightarrow',
      'leftarrow', 'le', 'ge', 'ne', 'approx', 'pm', 'degree', 'circ', 'text', 'vec'
    ];
    final String pattern = r'(\\(?:' + mathKeywords.join('|') + r')(?:\{[^}]*\}|\s+[a-zA-Z0-9_]+|[a-zA-Z0-9_]*))';
    if (!clean.contains(r'$')) {
      clean = clean.replaceAllMapped(RegExp(pattern), (m) => '\$${m.group(1)}\$');
    }

    return clean;
  }

  // 🧹 2. Unicode Fallback if KaTeX parser encounters a malformed formula
  static String fallbackToUnicode(String input) {
    String res = input;
    res = res.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1] ?? '');
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]}/${m[2]})');
    res = res.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    res = res.replaceAll(r'\Delta', 'Δ');
    res = res.replaceAll(r'\int', '∫');
    res = res.replaceAll(r'\le', '≤');
    res = res.replaceAll(r'\ge', '≥');
    res = res.replaceAll(r'\rightarrow', '→');
    res = res.replaceAll(r'\times', '×');
    res = res.replaceAll(r'\pm', '±');
    res = res.replaceAll(r'\', '').replaceAll(r'$', '');
    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final TextStyle defaultStyle = textStyle ??
        TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF0F172A),
          height: 1.45,
        );

    final String sanitized = sanitizeInput(text);

    final List<InlineSpan> spans = [];

    // RegExp matching Display Math, Inline Math, Markdown Bold, HTML Bold, & Line Breaks
    final RegExp masterRegExp = RegExp(
      r'(\$\$(.*?)\$\$|\$(.*?)\$|\*\*(.*?)\*\*|<br\s*/?>|<b>(.*?)<\/b>|<strong>(.*?)<\/strong>)',
      caseSensitive: false,
    );

    int lastMatchEnd = 0;

    for (final Match match in masterRegExp.allMatches(sanitized)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: sanitized.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      final String fullMatch = match.group(0) ?? '';

      // 1️⃣ Display Math ($$...$$)
      if (fullMatch.startsWith(r'$$') && fullMatch.endsWith(r'$$')) {
        final mathContent = match.group(2) ?? '';
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Math.tex(
              mathContent,
              textStyle: defaultStyle,
              mathStyle: MathStyle.display,
              onErrorFallback: (err) => Text(fallbackToUnicode(mathContent), style: defaultStyle),
            ),
          ),
        ));
      }
      // 2️⃣ Inline Math ($...$)
      else if (fullMatch.startsWith(r'$') && fullMatch.endsWith(r'$')) {
        final mathContent = match.group(3) ?? '';
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Math.tex(
              mathContent,
              textStyle: defaultStyle,
              mathStyle: MathStyle.text,
              onErrorFallback: (err) => Text(fallbackToUnicode(mathContent), style: defaultStyle),
            ),
          ),
        ));
      }
      // 3️⃣ Markdown Bold (**word**)
      else if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        final boldContent = match.group(4) ?? '';
        spans.add(TextSpan(
          text: boldContent,
          style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // 4️⃣ HTML <b> or <strong> tags
      else if (fullMatch.toLowerCase().startsWith('<b>') || fullMatch.toLowerCase().startsWith('<strong>')) {
        final boldContent = match.group(5) ?? match.group(6) ?? '';
        spans.add(TextSpan(
          text: boldContent,
          style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // 5️⃣ HTML Line break (<br> / <br/>)
      else if (fullMatch.toLowerCase().startsWith('<br')) {
        spans.add(const TextSpan(text: '\n'));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < sanitized.length) {
      spans.add(TextSpan(
        text: sanitized.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }
}

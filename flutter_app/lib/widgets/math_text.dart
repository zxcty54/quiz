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

  // 🧹 1. Deep LaTeX & Chemistry Token Normalizer + OCR Sanitizer
  static String sanitizeInput(String raw) {
    if (raw.isEmpty) return "";
    String s = raw;

    // A. Fix escaped newlines & backslashes from JSON
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll(r'\\\\', r'\').replaceAll(r'\\', r'\');

    // B. Fix HTML entities
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    // C. Fix OCR forward slash mistakes (/frac -> \frac, /sqrt -> \sqrt)
    s = s.replaceAllMapped(
      RegExp(r'(?:^|\s)/([a-zA-Z]+)'),
      (m) => ' \\${m.group(1)}',
    );

    // D. Fix spaces after backslash (\ frac -> \frac, \ int -> \int, \ theta -> \theta)
    s = s.replaceAllMapped(
      RegExp(r'\\\s+([a-zA-Z]+)'),
      (m) => '\\${m.group(1)}',
    );

    // E. Fix split dollars and messy spaces: "$ \text{SO}_2$" -> "$\text{SO}_2$"
    s = s.replaceAllMapped(RegExp(r'\$\s+'), (m) => r'$');
    s = s.replaceAllMapped(RegExp(r'\s+\$'), (m) => r'$');

    // F. Fix un-spaced chemical ions: Al^{3+}, Ca^{2+}, Na^+, Al^(3+)
    s = s.replaceAllMapped(
      RegExp(r'([A-Za-z]+)\^\{?([0-9]*[\+\-])\}?'),
      (m) => '${m.group(1)}^{{${m.group(2)}}}',
    );

    // G. Split comma-separated multiple math terms inside single dollar sign:
    // e.g. "$NaCl, KCl, CaCl_2$" -> "$NaCl$, $KCl$, $CaCl_2$"
    s = s.replaceAllMapped(RegExp(r'\$([^\$]+?)\$'), (match) {
      String inside = match.group(1)!;
      if (inside.contains(',') && !inside.contains(r'\frac') && !inside.contains(r'\left')) {
        List<String> parts = inside.split(',').map((p) => p.trim()).toList();
        return parts.map((p) => p.isNotEmpty ? '\$$p\$' : '').join(', ');
      }
      return '\$$inside\$';
    });

    // H. Fix OCR parentheses instead of braces: \frac(a)(b) -> \frac{a}{b}
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\(([^)]+)\)\s*\(([^)]+)\)'),
      (m) => '\\frac{${m.group(1)}}{${m.group(2)}}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\s*\(([^)]+)\)'),
      (m) => '\\sqrt{${m.group(1)}}',
    );

    // I. Auto-wrap common floating chemistry subscripts if naked: e.g. SO_2, CO_2, H_2O, NH_3
    final List<String> chemFormulas = [
      r'SO_2', r'CO_2', r'H_2O', r'NH_3', r'H_2', r'N_2', r'O_2',
      r'CaCl_2', r'AlCl_3', r'Cr_2O_3', r'K_2Cr_2O_7', r'H_2SO_4', r'CH_4', r'CH_3OH'
    ];
    for (String chem in chemFormulas) {
      s = s.replaceAllMapped(
        RegExp('(?<!\\\$)\\b' + RegExp.escape(chem) + '\\b(?!\\s*\\\$|\})'),
        (m) => '\$${m.group(0)}\$',
      );
    }

    // J. Auto-wrap floating naked LaTeX commands in $...$ if $ is missing
    final List<String> mathKeywords = [
      'frac', 'sqrt', 'int', 'sum', 'Delta', 'delta', 'alpha', 'beta', 'gamma',
      'theta', 'lambda', 'mu', 'pi', 'sigma', 'omega', 'times', 'div', 'rightarrow',
      'leftarrow', 'le', 'ge', 'ne', 'approx', 'pm', 'degree', 'circ', 'vec'
    ];
    final String pattern = r'(\\(?:' + mathKeywords.join('|') + r')(?:\{[^}]*\}|\s+[a-zA-Z0-9_]+|[a-zA-Z0-9_]*))';
    if (!s.contains(r'$')) {
      s = s.replaceAllMapped(RegExp(pattern), (m) => '\$${m.group(1)}\$');
    }

    return s;
  }

  // 🧹 2. Graceful Unicode Fallback (Agar KaTeX syntax crash kare toh clean symbols dikhaye)
  static String fallbackToUnicode(String input) {
    String res = input;
    res = res.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1] ?? '');
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]}/${m[2]})');
    res = res.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    res = res.replaceAll(r'\varepsilon_0', 'ε₀');
    res = res.replaceAll(r'\Delta', 'Δ');
    res = res.replaceAll(r'\int', '∫');
    res = res.replaceAll(r'\le', '≤');
    res = res.replaceAll(r'\ge', '≥');
    res = res.replaceAll(r'\rightarrow', '→');
    res = res.replaceAll(r'\times', '×');
    res = res.replaceAll(r'\pm', '±');
    res = res.replaceAll(r'\pi', 'π');
    res = res.replaceAll(r'{', '').replaceAll(r'}', '').replaceAll(r'\', '').replaceAll(r'$', '');
    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final TextStyle defaultStyle = textStyle ??
        TextStyle(
          fontSize: 14.0,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF0F172A),
          height: 1.45,
        );

    final String sanitized = sanitizeInput(text);

    final List<InlineSpan> spans = [];

    // Master Matcher: Display Math ($$), Inline Math ($), Markdown Bold (**), HTML Bold (<b>/<strong>), Line Breaks (<br>)
    final RegExp masterRegExp = RegExp(
      r'(\$\$[\s\S]*?\$\$|\$[^\$]+?\$|\*\*(.*?)\*\*|<br\s*/?>|<b>(.*?)<\/b>|<strong>(.*?)<\/strong>)',
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
        String mathContent = fullMatch.substring(2, fullMatch.length - 2).trim();
        mathContent = mathContent.replaceAllMapped(
          RegExp(r'_\{([a-zA-Z]{2,})\}'),
          (m) => '_{\\text{${m.group(1)}}}',
        );

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
        String mathContent = fullMatch.substring(1, fullMatch.length - 1).trim();
        mathContent = mathContent.replaceAllMapped(
          RegExp(r'_\{([a-zA-Z]{2,})\}'),
          (m) => '_{\\text{${m.group(1)}}}',
        );

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
        final boldContent = match.group(2) ?? '';
        spans.add(TextSpan(
          text: boldContent,
          style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // 4️⃣ HTML <b> or <strong> tags
      else if (fullMatch.toLowerCase().startsWith('<b>') || fullMatch.toLowerCase().startsWith('<strong>')) {
        final boldContent = match.group(3) ?? match.group(4) ?? '';
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

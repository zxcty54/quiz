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

  // 🧹 1. COMPREHENSIVE SANITIZER FOR CHEMISTRY, NUCLEAR & PHYSICS LATEX
  static String sanitizeInput(String raw) {
    if (raw.isEmpty) return "";
    String s = raw;

    // 1️⃣ Normalize JSON Escaping & HTML Entities
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    // 2️⃣ Fix Complex Arrow tags for flutter_math_fork compatibility
    s = s.replaceAllMapped(RegExp(r'\\xrightarrow\{([^}]+)\}'), (m) => r'\overset{\text{' + (m.group(1) ?? '') + r'}}{\longrightarrow}');

    // 3️⃣ Fix Slashes & LaTeX Typos
    s = s.replaceAllMapped(RegExp(r'(?:^|\s)/([a-zA-Z]+)'), (m) => ' \\${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\\frac\s*\(([^)]+)\)\s*\(([^)]+)\)'), (m) => '\\frac{${m.group(1)}}{${m.group(2)}}');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\s*\(([^)]+)\)'), (m) => '\\sqrt{${m.group(1)}}');

    // 4️⃣ Fix Jammed/Glued Math & Words ($K$ya -> $K$ ya)
    s = s.replaceAllMapped(
      RegExp(r'\$([^\$]+?)\$([a-zA-Z\u0900-\u097F]+)'),
      (m) => '\$${m.group(1)}\$ ${m.group(2)}',
    );
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z\u0900-\u097F]+)\$([^\$]+?)\$'),
      (m) => '${m.group(1)} \$${m.group(2)}\$',
    );

    // 5️⃣ Unwrap Math from Bold Tags (**$...$** -> $...$)
    s = s.replaceAllMapped(
      RegExp(r'\*\*\s*(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$)\s*\*\*'),
      (m) => m.group(1) ?? '',
    );
    s = s.replaceAllMapped(
      RegExp(r'<\s*b\s*>\s*(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$)\s*<\s*/\s*b\s*>', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );
    s = s.replaceAllMapped(
      RegExp(r'<\s*strong\s*>\s*(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$)\s*<\s*/\s*strong\s*>', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );

    // 6️⃣ Fix Dollar Boundary Whitespaces ($ formula $ -> $formula$)
    s = s.replaceAllMapped(RegExp(r'\$\s+'), (m) => r'$');
    s = s.replaceAllMapped(RegExp(r'\s+\$'), (m) => r'$');

    // 7️⃣ Separate Comma-separated variables in single dollar ($NaCl, KCl$ -> $NaCl$, $KCl$)
    s = s.replaceAllMapped(RegExp(r'\$([^\$\n]+?)\$'), (match) {
      String inside = match.group(1)!;
      if (inside.contains(',') &&
          !inside.contains(r'\frac') &&
          !inside.contains(r'\left') &&
          !inside.contains('{') &&
          !inside.contains('^') &&
          !inside.contains('_')) {
        List<String> parts = inside.split(',').map((p) => p.trim()).toList();
        return parts.map((p) => p.isNotEmpty ? '\$$p\$' : '').join(', ');
      }
      return '\$$inside\$';
    });

    // 8️⃣ Auto-wrap Common Naked Chemistry & Physics Formulas if not in $ $
    final List<String> nakedFormulas = [
      r'SO_2', r'CO_2', r'H_2O', r'NH_3', r'H_2', r'N_2', r'O_2', r'O_3',
      r'CaCl_2', r'AlCl_3', r'Cr_2O_3', r'K_2Cr_2O_7', r'H_2SO_4', r'CH_4',
      r'Fe_3O_4', r'Fe_2O_3', r'Al_2O_3', r'K_2O', r'P_4O_6', r'P_4O_{10}',
      r'H_3PO_4', r'H_3PO_3', r'H_3PO_2', r'H_2S_2O_8', r'H_2S_2O_7', r'H_2S',
      r'CaCO_3', r'Sb_2S_3', r'KClO_3', r'NaN_3', r'PH_3', r'Ca_3P_2'
    ];
    for (String formula in nakedFormulas) {
      s = s.replaceAllMapped(
        RegExp('(?<!\\\$|\\\\text\\{|\\\\)\\b' + RegExp.escape(formula) + '\\b(?!\\s*\\\$|\\})'),
        (m) => '\$\\text{${m.group(0)}}\$',
      );
    }

    return s;
  }

  // 🧹 2. GRACEFUL UNICODE FALLBACK ENGINE
  static String fallbackToUnicode(String input) {
    String res = input;
    res = res.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1] ?? '');
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]}/${m[2]})');
    res = res.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    res = res.replaceAllMapped(RegExp(r'\\overset\{([^}]+)\}\{\\longrightarrow\}'), (m) => '―(${m[1]})→');
    res = res.replaceAll(r'\longrightarrow', '→');
    res = res.replaceAll(r'\rightarrow', '→');
    res = res.replaceAll(r'\rightleftharpoons', '⇌');
    res = res.replaceAll(r'\equiv', '≡');
    res = res.replaceAll(r'\approx', '≈');
    res = res.replaceAll(r'\sim', '~');
    res = res.replaceAll(r'\Delta', 'Δ');
    res = res.replaceAll(r'\pi', 'π');
    res = res.replaceAll(r'\theta', 'θ');
    res = res.replaceAll(r'\mu', 'μ');
    res = res.replaceAll(r'\nu', 'ν');
    res = res.replaceAll(r'\lambda', 'λ');
    res = res.replaceAll(r'\beta', 'β');
    res = res.replaceAll(r'\bar{\nu}', 'ν̄');
    res = res.replaceAll(r'\uparrow', '↑');
    res = res.replaceAll(r'\downarrow', '↓');
    res = res.replaceAll(r'^\circ\text{C}', '°C');
    res = res.replaceAll(r'^\circ', '°');
    res = res.replaceAll(r'\circ', '°');
    res = res.replaceAll(r'\AA', 'Å');
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
          height: 1.5,
        );

    final String sanitized = sanitizeInput(text);
    final List<InlineSpan> spans = [];

    // Master Matcher: Catches Display Math ($$...$$), Inline Math ($...$), Bold (**...**), and HTML tags
    final RegExp masterRegExp = RegExp(
      r'(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$|\*\*(.*?)\*\*|<br\s*/?>|<b>(.*?)<\/b>|<strong>(.*?)<\/strong>)',
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

      // 1️⃣ Display Math ($$...$$) -> Centered & Scrollable
      if (fullMatch.startsWith(r'$$') && fullMatch.endsWith(r'$$')) {
        String mathContent = fullMatch.substring(2, fullMatch.length - 2).trim();

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                mathContent,
                textStyle: defaultStyle.copyWith(
                  fontSize: (defaultStyle.fontSize ?? 14.0) * 1.05,
                  fontWeight: FontWeight.w600,
                ),
                mathStyle: MathStyle.display,
                onErrorFallback: (err) => Text(
                  fallbackToUnicode(mathContent),
                  style: defaultStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ));
      }
      // 2️⃣ Inline Math ($...$) -> Baseline Aligned
      else if (fullMatch.startsWith(r'$') && fullMatch.endsWith(r'$')) {
        String mathContent = fullMatch.substring(1, fullMatch.length - 1).trim();

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Math.tex(
              mathContent,
              textStyle: defaultStyle.copyWith(
                fontSize: defaultStyle.fontSize ?? 14.0,
              ),
              mathStyle: MathStyle.text,
              onErrorFallback: (err) => Text(
                fallbackToUnicode(mathContent),
                style: defaultStyle,
              ),
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
      // 4️⃣ HTML Bold Tags (<b> or <strong>)
      else if (fullMatch.toLowerCase().startsWith('<b>') || fullMatch.toLowerCase().startsWith('<strong>')) {
        final boldContent = match.group(3) ?? match.group(4) ?? '';
        spans.add(TextSpan(
          text: boldContent,
          style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // 5️⃣ Line Break Tags (<br>)
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

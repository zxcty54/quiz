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

  // 🧹 1. UNIVERSAL COMPREHENSIVE PHYSICS & MATH SANITIZER
  static String sanitizeInput(String raw) {
    if (raw.isEmpty) return "";
    String s = raw;

    // 1️⃣ Normalize JSON Escaping & HTML Entities
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll(r'\\\\', r'\').replaceAll(r'\\', r'\');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    // 2️⃣ Fix OCR Typo Slashes & Spacing
    s = s.replaceAllMapped(RegExp(r'(?:^|\s)/([a-zA-Z]+)'), (m) => ' \\${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\\\s+([a-zA-Z]+)'), (m) => '\\${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\\frac\s*\(([^)]+)\)\s*\(([^)]+)\)'), (m) => '\\frac{${m.group(1)}}{${m.group(2)}}');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\s*\(([^)]+)\)'), (m) => '\\sqrt{${m.group(1)}}');

    // 3️⃣ 🚨 CRITICAL: Fix Jammed/Glued Math & Words ($K$ya -> $K$ ya, $K > 1$hamesha -> $K > 1$ hamesha)
    s = s.replaceAllMapped(
      RegExp(r'\$([^\$]+?)\$([a-zA-Z\u0900-\u097F]+)'),
      (m) => '\$${m.group(1)}\$ ${m.group(2)}',
    );
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z\u0900-\u097F]+)\$([^\$]+?)\$'),
      (m) => '${m.group(1)} \$${m.group(2)}\$',
    );

    // 4️⃣ 🚨 CRITICAL: Unwrap Math from Bold & HTML Tags (**$...$** -> $...$)
    s = s.replaceAllMapped(
      RegExp(r'\*\*\s*(\$\$[\s\S]*?\$\$|\$[^\$]+?\$)\s*\*\*'),
      (m) => m.group(1) ?? '',
    );
    s = s.replaceAllMapped(
      RegExp(r'<\s*b\s*>\s*(\$\$[\s\S]*?\$\$|\$[^\$]+?\$)\s*<\s*/\s*b\s*>', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );
    s = s.replaceAllMapped(
      RegExp(r'<\s*strong\s*>\s*(\$\$[\s\S]*?\$\$|\$[^\$]+?\$)\s*<\s*/\s*strong\s*>', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );

    // 5️⃣ Fix Dollar Boundary Whitespaces ($ formula $ -> $formula$)
    s = s.replaceAllMapped(RegExp(r'\$\s+'), (m) => r'$');
    s = s.replaceAllMapped(RegExp(r'\s+\$'), (m) => r'$');

    // 6️⃣ Separate Comma-separated variables in single dollar ($NaCl, KCl$ -> $NaCl$, $KCl$)
    s = s.replaceAllMapped(RegExp(r'\$([^\$]+?)\$'), (match) {
      String inside = match.group(1)!;
      if (inside.contains(',') && !inside.contains(r'\frac') && !inside.contains(r'\left') && !inside.contains('{')) {
        List<String> parts = inside.split(',').map((p) => p.trim()).toList();
        return parts.map((p) => p.isNotEmpty ? '\$$p\$' : '').join(', ');
      }
      return '\$$inside\$';
    });

    // 7️⃣ Fix Multi-word Subscripts inside Math (E_{inside} -> E_{\text{inside}})
    s = s.replaceAllMapped(
      RegExp(r'_\{([a-zA-Z]{2,})\}'),
      (m) => '_{\\text{${m.group(1)}}}',
    );

    // 8️⃣ Auto-wrap Common Naked Chemistry & Physics Subscripts
    final List<String> nakedFormulas = [
      r'SO_2', r'CO_2', r'H_2O', r'NH_3', r'H_2', r'N_2', r'O_2',
      r'CaCl_2', r'AlCl_3', r'Cr_2O_3', r'K_2Cr_2O_7', r'H_2SO_4', r'CH_4', r'CH_3OH',
      r'T_c', r'E_0', r'E_p', r'V_{\text{surface}}', r'q_{\text{enclosed}}', r'q_{\text{in}}'
    ];
    for (String formula in nakedFormulas) {
      s = s.replaceAllMapped(
        RegExp('(?<!\\\$)\\b' + RegExp.escape(formula) + '\\b(?!\\s*\\\$|\})'),
        (m) => '\$${m.group(0)}\$',
      );
    }

    return s;
  }

  // 🧹 2. GRACEFUL UNICODE FALLBACK ENGINE (In case of extreme TeX syntax corruption)
  static String fallbackToUnicode(String input) {
    String res = input;
    res = res.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1] ?? '');
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]}/${m[2]})');
    res = res.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    res = res.replaceAll(r'\varepsilon_0', 'ε₀');
    res = res.replaceAll(r'\varepsilon_r', 'εᵣ');
    res = res.replaceAll(r'\varepsilon', 'ε');
    res = res.replaceAll(r'\Phi', 'Φ');
    res = res.replaceAll(r'\phi', 'ϕ');
    res = res.replaceAll(r'\Delta', 'Δ');
    res = res.replaceAll(r'\int', '∫');
    res = res.replaceAll(r'\le', '≤');
    res = res.replaceAll(r'\ge', '≥');
    res = res.replaceAll(r'\rightarrow', '→');
    res = res.replaceAll(r'\times', '×');
    res = res.replaceAll(r'\pm', '±');
    res = res.replaceAll(r'\pi', 'π');
    res = res.replaceAll(r'\infty', '∞');
    res = res.replaceAll(r'\theta', 'θ');
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

    // Master Matcher Regex
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
      // 4️⃣ HTML Bold Tags
      else if (fullMatch.toLowerCase().startsWith('<b>') || fullMatch.toLowerCase().startsWith('<strong>')) {
        final boldContent = match.group(3) ?? match.group(4) ?? '';
        spans.add(TextSpan(
          text: boldContent,
          style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // 5️⃣ Line Break Tags
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

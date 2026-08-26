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

  // 🧹 UNIVERSAL ZERO-GLITCH SANITIZER FOR CHEMISTRY & PHYSICS
  static String sanitizeInput(String raw) {
    if (raw.isEmpty) return "";
    String s = raw;

    // 1️⃣ Normalize JSON Escaping & Fix Double Backslashes
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll(r'\\', r'\');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    
    // Fix Tab-corrupted \text & \mu typos from JSON
    s = s.replaceAll(r'\tmu', r'\mu');
    s = s.replaceAll(r'\ttext', r'\text');
    s = s.replaceAll(RegExp(r'(?:\\t|\t|\b)ext\{', caseSensitive: false), r'\text{');

    // 2️⃣ Fix Chemistry Dot Products, Arrows & State Subscripts
    s = s.replaceAll(r'\cdot', ' · ');
    s = s.replaceAll(r'_{(g)}', ' (g)');
    s = s.replaceAll(r'_{(l)}', ' (l)');
    s = s.replaceAll(r'_{(s)}', ' (s)');
    s = s.replaceAll(r'_{(aq)}', ' (aq)');
    s = s.replaceAll(r'\uparrow', '↑');
    s = s.replaceAll(r'\downarrow', '↓');
    s = s.replaceAll(r'\rightarrow', '→');
    s = s.replaceAll(r'\longrightarrow', '→');
    s = s.replaceAll(r'\rightleftharpoons', '⇌');

    // 3️⃣ Fix Complex Arrow Tags & Oversets
    s = s.replaceAllMapped(
      RegExp(r'\\overset\{\s*\\?text\{([^}]+)\}\s*\}\s*\{\s*\\?(?:long)?rightarrow\s*\}'),
      (m) => ' ⎯(${m.group(1)})→ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\xrightarrow\{([^}]+)\}'),
      (m) => ' ⎯(${m.group(1)})→ ',
    );

    // 4️⃣ Fix Broken Dollar Encapsulations like ($NaNO_3$), ($KNO_3$), ($Fe_3O_4 / Fe_2O_3$)
    s = s.replaceAllMapped(RegExp(r'\(\s*\$([^$]+)\$\s*\)'), (m) => '(${m.group(1)})');
    s = s.replaceAllMapped(RegExp(r'\[\s*\$([^$]+)\$\s*\]'), (m) => '[${m.group(1)}]');

    // 5️⃣ Universal Subscript Mapping (For plain text chemistry)
    final Map<String, String> subscriptMap = {
      '_0': '₀', '_1': '₁', '_2': '₂', '_3': '₃', '_4': '₄',
      '_5': '₅', '_6': '₆', '_7': '₇', '_8': '₈', '_9': '₉',
    };

    subscriptMap.forEach((key, val) {
      s = s.replaceAll(key, val);
    });

    // 6️⃣ Clean Leftover Underscores & Brackets in Formulas
    s = s.replaceAllMapped(RegExp(r'([A-Za-z]+)_\{([0-9]+)\}'), (m) {
      String digits = m.group(2)!;
      subscriptMap.forEach((key, val) {
        digits = digits.replaceAll(key.replaceAll('_', ''), val);
      });
      return '${m.group(1)}$digits';
    });

    // 7️⃣ Fix Degree, Enthalpy & Spacing Units
    s = s.replaceAll(r'^\circ\text{C}', '°C');
    s = s.replaceAll(r'^\circ\text{ C}', '°C');
    s = s.replaceAll(r'^\circ C', '°C');
    s = s.replaceAll(r'^\circ', '°');
    s = s.replaceAll(r'\circ', '°');
    s = s.replaceAll(r'\sim', '~');
    s = s.replaceAll(r'\Delta H = -92.4\text{kJ/mol}', 'ΔH = -92.4 kJ/mol');
    s = s.replaceAll(r'\Delta H = -92.4kJ/mol', 'ΔH = -92.4 kJ/mol');
    s = s.replaceAll(r'\Delta', 'Δ');
    s = s.replaceAll(r'\text{kJ/mol}', 'kJ/mol');
    s = s.replaceAll(r'\text{atm}', 'atm');
    s = s.replaceAllMapped(
      RegExp(r'([0-9]+)\s*°\s*C\s*aur\s*~?\s*([0-9]+)\s*atm'),
      (m) => '${m.group(1)}°C aur ~ ${m.group(2)} atm',
    );

    // 8️⃣ Auto-wrap bare math commands if not wrapped inside $...$
    if (!s.contains('\$')) {
      s = s.replaceAllMapped(
        RegExp(r'(\\(?:frac|sqrt)\{[^}]+\}(?:\{[^}]+\})?)'),
        (m) => '\$${m.group(1)}\$',
      );
      s = s.replaceAllMapped(
        RegExp(r'(\\(?:mu|lambda|theta|nu|alpha|beta|pi|times|approx|infty)(?:_[a-zA-Z0-9]+)?)'),
        (m) => '\$${m.group(1)}\$',
      );
    }

    return s;
  }

  // 🧹 COMPREHENSIVE FALLBACK ENGINE FOR FAILING LATEX
  static String fallbackToUnicode(String input) {
    String res = input;
    res = res.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1] ?? '');
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]}/${m[2]})');
    res = res.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    res = res.replaceAll(r'\Delta', 'Δ');
    res = res.replaceAll(r'\pi', 'π');
    res = res.replaceAll(r'\theta', 'θ');
    res = res.replaceAll(r'\mu', 'μ');
    res = res.replaceAll(r'\nu', 'ν');
    res = res.replaceAll(r'\lambda', 'λ');
    res = res.replaceAll(r'\sigma', 'σ');
    res = res.replaceAll(r'\approx', '≈');
    res = res.replaceAll(r'\times', '×');
    res = res.replaceAll(r'\infty', '∞');
    res = res.replaceAll(r'\implies', '⇒');
    res = res.replaceAll(r'\sim', '~');
    res = res.replaceAll(r'^\circ', '°');
    res = res.replaceAll(r'\circ', '°');
    res = res.replaceAll(r'\AA', 'Å');
    res = res.replaceAll('{', '').replaceAll('}', '').replaceAll(r'\', '').replaceAll(r'$', '');
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

    // Master Matcher: Block Math ($$...$$), Inline Math ($...$), Bold (**...**), and HTML tags
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

      // 1️⃣ Display Math ($$...$$)
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
      // 2️⃣ Inline Math ($...$)
      else if (fullMatch.startsWith(r'$') && fullMatch.endsWith(r'$')) {
        String mathContent = fullMatch.substring(1, fullMatch.length - 1).trim();

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
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
      else if (fullMatch.toLowerCase().startsWith('<b>') ||
          fullMatch.toLowerCase().startsWith('<strong>')) {
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

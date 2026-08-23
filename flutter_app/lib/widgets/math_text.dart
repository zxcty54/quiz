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

    // 1️⃣ Normalize JSON Escaping & Tab-corrupted '\text'
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
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

    // 3️⃣ Fix Complex Arrow Tags
    s = s.replaceAllMapped(
      RegExp(r'\\overset\{\s*\\?text\{([^}]+)\}\s*\}\s*\{\s*\\?(?:long)?rightarrow\s*\}'),
      (m) => ' ⎯(${m.group(1)})→ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\xrightarrow\{([^}]+)\}'),
      (m) => ' ⎯(${m.group(1)})→ ',
    );

    // 4️⃣ Fix Single Elemental Names in Dollars ($Al$, $Fe$, $Zn$, $AgBr$)
    s = s.replaceAllMapped(RegExp(r'\$([A-Z][a-z]?)\$'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'\$([A-Z][a-z]?[A-Z][a-z]?)\$'), (m) => m.group(1)!);

    // 5️⃣ Universal Subscript Mapping (Both inside & outside math mode)
    final Map<String, String> subscriptMap = {
      '_0': '₀', '_1': '₁', '_2': '₂', '_3': '₃', '_4': '₄',
      '_5': '₅', '_6': '₆', '_7': '₇', '_8': '₈', '_9': '₉',
    };

    // Replace all broken OCR subscripts like Na_2S_2O_3 -> Na₂S₂O₃, Al_2O_3 -> Al₂O₃, H_2O -> H₂O
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

    // 7️⃣ Unwrap Math & Fix Dollars
    s = s.replaceAll(r'$$', '');
    s = s.replaceAllMapped(RegExp(r'\$\s+'), (m) => r'$');
    s = s.replaceAllMapped(RegExp(r'\s+\$'), (m) => r'$');
    s = s.replaceAllMapped(
      RegExp(r'\*\*\s*(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$)\s*\*\*'),
      (m) => m.group(1) ?? '',
    );

    return s;
  }

  // 🧹 FALLBACK ENGINE FOR EXTREME LATEX SYNTAX CORRUPTION
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
    res = res.replaceAll(r'\sim', '~');
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

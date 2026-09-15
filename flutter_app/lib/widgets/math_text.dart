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

  // 🧹 CLEAN & SAFE SANITIZER (Valid LaTeX ko bina tode space aur syntax fix karega)
  static String sanitizeInput(String raw) {
    if (raw.trim().isEmpty) return "";
    String s = raw;

    // 1. Line breaks aur HTML spaces normalize karein
    s = s.replaceAll(r'\r\n', '\n').replaceAll(r'\n', '\n');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    // 2. Typos & backslash issues fix karein
    s = s.replaceAll(r'\tmu', r'\mu');
    s = s.replaceAll(r'\ttext', r'\text');
    s = s.replaceAll(r'- -', '– ').replaceAll(r'-- ', '– ').replaceAll(r'\text{--}', '–');

    // Double backslash (JSON escaped) ko single LaTeX slash me badlein
    s = s.replaceAllMapped(
      RegExp(r'\\\\([a-zA-Z]+)'),
      (m) => '\\${m.group(1)}',
    );

    // 3. Bracketed Formulas/Isotopes jinme $ missing hai unhe $...$ me wrap karein
    // Example: ( ^{133}_{55} Cs ) ya ( ^{9}_{4} Be )
    s = s.replaceAllMapped(
      RegExp(r'\(\s*(\^\{?\d+\}?[^)]*?)\s*\)'),
      (m) {
        String inner = m.group(1)!.trim();
        if (inner.startsWith(r'$') && inner.endsWith(r'$')) return '($inner)';
        if (inner.contains(r'\rightarrow') || inner.contains('→')) {
          return '\$\$$inner\$\$';
        }
        return '\$$inner\$';
      },
    );

    // 4. Bracketed scientific notation: (1.675 × 10^{-27} kg) -> $1.675 \times 10^{-27}\text{ kg}$
    s = s.replaceAllMapped(
      RegExp(r'\(\s*([\d\.]+\s*(?:\\times|×)\s*10\^\{?-?\d+\}?\s*([A-Za-z/]+)?)\s*\)'),
      (m) {
        final val = m.group(1)!.replaceAll('×', r'\times');
        return '\$$val\$';
      },
    );

    // 5. Math mode ($...$) ke andar ke accidental spaces hatana: "$ C _{60} $" -> "$C_{60}$"
    s = s.replaceAllMapped(
      RegExp(r'\$([^\$]+?)\$'),
      (match) {
        String inner = match.group(1)!.trim();
        inner = inner.replaceAll(RegExp(r'\s*_\s*'), '_');
        inner = inner.replaceAll(RegExp(r'\s*\^\s*'), '^');
        inner = inner.replaceAllMapped(
          RegExp(r'([A-Za-z0-9])\s+([A-Za-z0-9])'),
          (m) => '${m[1]}${m[2]}',
        );
        return '\$$inner\$';
      },
    );

    // 6. Dollar delimiter boundary spacing fix: "$ x $" -> "$x$"
    s = s.replaceAllMapped(
      RegExp(r'\$\s+([^\$]+?)\s+\$'),
      (match) => '\$${match.group(1)?.trim()}\$',
    );

    return s.trim();
  }

  // 🧹 COMPREHENSIVE FALLBACK ENGINE FOR FAILING LATEX
  static String fallbackToUnicode(String input) {
    String res = input;
    res = res.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1] ?? '');
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]} / ${m[2]})');
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
    res = res.replaceAll(r'\cdot', '·');
    res = res.replaceAll(r'\infty', '∞');
    res = res.replaceAll(r'\implies', '⇒');
    res = res.replaceAll(r'\sim', '~');
    res = res.replaceAll(r'^\circ', '°');
    res = res.replaceAll(r'\circ', '°');
    res = res.replaceAll('{', '').replaceAll('}', '').replaceAll(r'\', '').replaceAll(r'$', '');
    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

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
            padding: const EdgeInsets.symmetric(vertical: 4.0),
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
      // 4️⃣ HTML Bold Tags
      else if (fullMatch.toLowerCase().startsWith('<b>') ||
          fullMatch.toLowerCase().startsWith('<strong>')) {
        final boldContent = match.group(3) ?? match.group(4) ?? '';
        spans.add(TextSpan(
          text: boldContent,
          style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // 5️⃣ Line Breaks
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

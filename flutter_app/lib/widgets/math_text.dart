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

  // 🧹 UNIVERSAL ZERO-GLITCH SANITIZER FOR MATH, PHYSICS & CHEMISTRY
  static String sanitizeInput(String raw) {
    if (raw.trim().isEmpty) return "";
    String s = raw;

    // 1️⃣ Protect Greek Nu (\nu) BEFORE Newline replacement
    s = s.replaceAll(r'\\nu', 'ν');
    s = s.replaceAll(r'\nu', 'ν');

    // Normalize JSON Escaping & Fix Double Backslashes
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    // Typos & Corrupted text fixes
    s = s.replaceAll(r'\tmu', 'μ');
    s = s.replaceAll(r'\ttext', r'\text');
    s = s.replaceAll(RegExp(r'(?:\\t|\t|\b)ext\{', caseSensitive: false), r'\text{');

    // 2️⃣ Common Physics & Math Symbols
    s = s.replaceAll(r'\lambda', 'λ').replaceAll(r'\\lambda', 'λ');
    s = s.replaceAll(r'\mu', 'μ').replaceAll(r'\\mu', 'μ');
    s = s.replaceAll(r'\theta', 'θ').replaceAll(r'\\theta', 'θ');
    s = s.replaceAll(r'\alpha', 'α').replaceAll(r'\\alpha', 'α');
    s = s.replaceAll(r'\beta', 'β').replaceAll(r'\\beta', 'β');
    s = s.replaceAll(r'\sigma', 'σ').replaceAll(r'\\sigma', 'σ');
    s = s.replaceAll(r'\cdot', ' · ').replaceAll(r'\\cdot', ' · ');
    s = s.replaceAll(r'\times', ' × ').replaceAll(r'\\times', ' × ');
    s = s.replaceAll(r'\approx', ' ≈ ').replaceAll(r'\\approx', ' ≈ ');
    s = s.replaceAll(r'\implies', ' ⟹ ').replaceAll(r'\\implies', ' ⟹ ').replaceAll('==>', ' ⟹ ');
    s = s.replaceAll(r'\rightarrow', ' → ').replaceAll(r'\\rightarrow', ' → ');
    s = s.replaceAll(r'\rightleftharpoons', ' ⇌ ');
    s = s.replaceAll(r'\uparrow', '↑').replaceAll(r'\downarrow', '↓');
    s = s.replaceAll(r'\\%', '%').replaceAll(r'\%', '%');

    // 3️⃣ Fix \text{...} commands
    s = s.replaceAllMapped(
      RegExp(r'\\+text\{([^}]+)\}'),
      (m) => ' ${m.group(1)?.trim()} ',
    );

    // 4️⃣ Fix Chemistry Dot Products, Arrows & State Subscripts
    s = s.replaceAll(r'_{(g)}', ' (g)');
    s = s.replaceAll(r'_{(l)}', ' (l)');
    s = s.replaceAll(r'_{(s)}', ' (s)');
    s = s.replaceAll(r'_{(aq)}', ' (aq)');

    s = s.replaceAllMapped(
      RegExp(r'\\overset\{\s*\\?text\{([^}]+)\}\s*\}\s*\{\s*\\?(?:long)?rightarrow\s*\}'),
      (m) => ' ⎯(${m.group(1)})→ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\xrightarrow\{([^}]+)\}'),
      (m) => ' ⎯(${m.group(1)})→ ',
    );

    // 5️⃣ Fix Broken Dollar Encapsulations like ($NaNO_3$)
    s = s.replaceAllMapped(RegExp(r'\(\s*\$([^$]+)\$\s*\)'), (m) => '(${m.group(1)})');
    s = s.replaceAllMapped(RegExp(r'\[\s*\$([^$]+)\$\s*\]'), (m) => '[${m.group(1)}]');

    // 6️⃣ Subscripts (₀ - ₉)
    final Map<String, String> subscriptMap = {
      '_0': '₀', '_1': '₁', '_2': '₂', '_3': '₃', '_4': '₄',
      '_5': '₅', '_6': '₆', '_7': '₇', '_8': '₈', '_9': '₉',
    };
    subscriptMap.forEach((key, val) => s = s.replaceAll(key, val));

    s = s.replaceAllMapped(RegExp(r'([A-Za-z]+)_\{([0-9]+)\}'), (m) {
      String digits = m.group(2)!;
      subscriptMap.forEach((key, val) => digits = digits.replaceAll(key.replaceAll('_', ''), val));
      return '${m.group(1)}$digits';
    });

    // 7️⃣ Superscripts & Exponents
    s = s
        .replaceAll(r'^2', '²')
        .replaceAll(r'^3', '³')
        .replaceAll(r'^\circ\text{C}', '°C')
        .replaceAll(r'^\circ C', '°C')
        .replaceAll(r'^\circ\text{F}', '°F')
        .replaceAll(r'^\circ F', '°F')
        .replaceAll(r'^\circ', '°')
        .replaceAll(r'\circ', '°')
        .replaceAll(r'$10^{-3}$', '10⁻³')
        .replaceAll(r'$10^{-6}$', '10⁻⁶')
        .replaceAll(r'$10^3$', '10³')
        .replaceAll(r'$10^5$', '10⁵')
        .replaceAll(r'$10^8$', '10⁸')
        .replaceAll(r'm/s^2', 'm/s²')
        .replaceAll(r'm/s^1', 'm/s')
        .replaceAll(r'cm^3', 'cm³')
        .replaceAll(r'm^3', 'm³');

    // 8️⃣ Clean \frac Everywhere (Converts raw LaTeX fractions to clean readable text)
    s = s.replaceAll(r'\\frac', r'\frac');
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) {
        String num = match.group(1)!.trim();
        String den = match.group(2)!.trim();
        if (num.contains('×') || num.contains('+') || num.contains('-') || num.contains('·')) {
          return '($num) / $den';
        }
        return '$num / $den';
      },
    );

    // Double pass for nested fractions
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) => '(${match.group(1)!.trim()}) / ${match.group(2)!.trim()}',
    );

    // 9️⃣ Remove dangling $ signs when not needed
    s = s.replaceAll(r'$$', '').trim();
    
    return s;
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

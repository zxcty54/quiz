import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathFormattedText extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const MathFormattedText({
    super.key,
    required this.text,
    this.textStyle,
  });

  // 🎯 HTML FORMATTING CLEANER (Fixes <b>, </b>, <br/> raw tags)
  static String _cleanHtmlFormatting(String rawInput) {
    if (rawInput.isEmpty) return "";
    String cleaned = rawInput;

    // 1. <br>, <br/>, <br > ko clean line break (\n) me badlein
    cleaned = cleaned.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // 2. Sirf specific HTML tags (<b>, </b>, <i>, </i>, <span>, <div>, <p>) ko hatayein
    // Note: Isse Physics/Maths ke '<' aur '>' (jaise x < 5) comparison signs SAFE rahenge!
    cleaned = cleaned.replaceAll(
      RegExp(r'</?(b|i|u|strong|em|p|div|span|font)[^>]*>', caseSensitive: false), 
      ''
    );

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    // 🧹 Pehle HTML Tags Safai Karein
    final String cleanText = _cleanHtmlFormatting(text);

    if (!cleanText.contains(r'\') && !cleanText.contains(r'$')) {
      return Text(cleanText, style: textStyle);
    }

    final List<InlineSpan> spans = [];
    final RegExp mathRegExp = RegExp(r'\$(.*?)\$|(\\frac\{.*?\}=\{.*?\}|\\frac\{.*?\}\{.*?\}|\\sqrt\{.*?\}|\\text\{.*?\})');
    
    int lastMatchEnd = 0;

    for (final RegExpMatch match in mathRegExp.allMatches(cleanText)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: cleanText.substring(lastMatchEnd, match.start), style: textStyle));
      }

      String mathExpr = match.group(1) ?? match.group(0) ?? '';
      mathExpr = mathExpr.replaceAll(r'$', '');

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Math.tex(
              mathExpr,
              textStyle: textStyle,
              onErrorFallback: (err) => Text(match.group(0) ?? '', style: textStyle),
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < cleanText.length) {
      spans.add(TextSpan(text: cleanText.substring(lastMatchEnd), style: textStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

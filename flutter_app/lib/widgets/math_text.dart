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

  @override
  Widget build(BuildContext context) {
    if (!text.contains(r'\') && !text.contains(r'$')) {
      return Text(text, style: textStyle);
    }

    final List<InlineSpan> spans = [];
    final RegExp mathRegExp = RegExp(r'\$(.*?)\$|(\\frac\{.*?\}=\{.*?\}|\\frac\{.*?\}\{.*?\}|\\sqrt\{.*?\}|\\text\{.*?\})');
    
    int lastMatchEnd = 0;

    for (final RegExpMatch match in mathRegExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: textStyle));
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

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: textStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

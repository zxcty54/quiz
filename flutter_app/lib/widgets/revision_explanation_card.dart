import 'package:flutter/material.dart';
import '../models/question_model.dart';
import 'math_text.dart';
import 'revision_trick_box.dart';

class RevisionExplanationCard extends StatelessWidget {
  final String rawExplanation;
  final Question currentQ;
  final bool isHindi;
  final bool isDark;
  final String testTitle;
  final int currentIndex;

  const RevisionExplanationCard({
    super.key,
    required this.rawExplanation,
    required this.currentQ,
    required this.isHindi,
    required this.isDark,
    required this.testTitle,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (rawExplanation.trim().isEmpty) return const SizedBox.shrink();

    // Line breaks normalize karein
    final String cleaned = rawExplanation
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .trim();

    // Line blocks ko identify karein bina math environments ($$) ko tode
    final rawLines = cleaned
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final List<String> distinctBlocks = [];
    String currentBlock = '';
    bool insideBlockMath = false;

    for (final line in rawLines) {
      final countOfDoubleDollar = RegExp(r'\$\$').allMatches(line).length;
      if (countOfDoubleDollar % 2 != 0) {
        insideBlockMath = !insideBlockMath;
      }

      final isNewBlockHeader = !insideBlockMath &&
          (line.startsWith('•') ||
              line.startsWith('-') ||
              line.toLowerCase().startsWith('option') ||
              line.toLowerCase().startsWith('statement') ||
              line.startsWith('📌') ||
              line.toLowerCase().startsWith('key takeaway') ||
              line.toLowerCase().startsWith('conclusion') ||
              line.toLowerCase().startsWith('method') ||
              RegExp(r'^[0-9]{1,2}[\.\)]\s').hasMatch(line));

      if (isNewBlockHeader && currentBlock.isNotEmpty) {
        distinctBlocks.add(currentBlock.trim());
        currentBlock = line;
      } else {
        if (currentBlock.isEmpty) {
          currentBlock = line;
        } else {
          currentBlock += '\n$line';
        }
      }
    }
    if (currentBlock.isNotEmpty) distinctBlocks.add(currentBlock.trim());

    final List<String> primaryCorrectBlocks = [];
    final List<String> trapOptionBlocks = [];
    final List<String> takeawayBlocks = [];

    for (final block in distinctBlocks) {
      final lower = block.trim().toLowerCase();
      final firstLine = lower.split('\n').first;

      final isExplicitCorrect = firstLine.contains('is correct') ||
          firstLine.contains('sahi hai') ||
          firstLine.contains('bilkul sahi');

      final isExplicitIncorrect = (firstLine.contains('is incorrect') ||
              firstLine.contains('galat hai') ||
              firstLine.contains('is false') ||
              firstLine.startsWith('trap')) &&
          (firstLine.startsWith('option') ||
              firstLine.startsWith('(') ||
              firstLine.startsWith('trap'));

      final isTakeaway = firstLine.startsWith('key takeaway') ||
          firstLine.startsWith('summary') ||
          firstLine.startsWith('📌') ||
          firstLine.startsWith('exam takeaway') ||
          firstLine.startsWith('conclusion');

      if (isTakeaway) {
        takeawayBlocks.add(block);
      } else if (isExplicitIncorrect && !isExplicitCorrect) {
        trapOptionBlocks.add(block);
      } else {
        primaryCorrectBlocks.add(block);
      }
    }

    final cardBg = isDark ? const Color(0xFF172033) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solution Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withOpacity(0.28) : const Color(0xFFECFDF5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text('💡', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Text(
                  isHindi ? 'मुख्य व्याख्या' : 'Detailed Solution',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Solution Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (primaryCorrectBlocks.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101827) : const Color(0xFFFAFFFC),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: primaryCorrectBlocks.map((block) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MathFormattedText(
                            text: block,
                            textStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              height: 1.6,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                ...takeawayBlocks.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: MathFormattedText(
                      text: point,
                      textStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                // Option Traps Expansion Box
                if (trapOptionBlocks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF101827) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: ExpansionTile(
                        dense: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: const Icon(Icons.alt_route_rounded, size: 19, color: Color(0xFF2563EB)),
                        title: Text(
                          isHindi ? 'बाकी विकल्प गलत क्यों हैं?' : 'Why other options are incorrect?',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: trapOptionBlocks.map((item) {
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF172033) : Colors.white,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(Icons.cancel_outlined, size: 15, color: Colors.red),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: MathFormattedText(
                                          text: item,
                                          textStyle: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                // Trick Submission Component
                RevisionTrickSubmitBox(
                  testTitle: testTitle,
                  qIndex: currentIndex,
                  questionSnippet: currentQ.getText(isHindi),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

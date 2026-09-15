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

    String cleaned = rawExplanation
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\text', r'\text')
        .replaceAll(r'\\mu', 'μ')
        .replaceAll(r'\\lambda', 'λ')
        .replaceAll(r'\\nu', 'ν')
        .replaceAll(r'\\theta', 'θ')
        .replaceAll(r'\\rho', 'ρ')
        .replaceAll(r'\\approx', '≈')
        .replaceAll(r'\\rightarrow', '→')
        .replaceAll(r'\\implies', ' ⟹ ')
        .replaceAll(r'\implies', ' ⟹ ')
        .replaceAll(r'==>', ' ⟹ ')
        .replaceAll(r'\\times', '×')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\\%', '%')
        .replaceAll(r'\%', '%');

    // 🎯 1. Double backslash aur single backslash dono types ke \frac ko normalize karein
    cleaned = cleaned.replaceAll(r'\\frac', r'\frac');

    // 🎯 2. Robust Fraction Cleaner (Fractions ko readable bracket/slash format me convert karega)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) {
        String num = match.group(1)!.trim();
        String den = match.group(2)!.trim();

        if (num.contains('×') || num.contains('+') || num.contains('-') || num.contains('*')) {
          return '($num) / $den';
        } else {
          return '$num / $den';
        }
      },
    );

    // Agar nested fraction reh gaya ho toh second pass clean
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) => '(${match.group(1)!.trim()}) / ${match.group(2)!.trim()}',
    );

    // 🧪 3. Chemistry Subscripts
    final Map<String, String> chemSubscripts = {
      r'($CO_2$)': 'CO₂', r'$CO_2$': 'CO₂', r'CO_2': 'CO₂',
      r'($H_2O$)': 'H₂O', r'$H_2O$': 'H₂O', r'H_2O': 'H₂O',
      r'($CH_4$)': 'CH₄', r'$CH_4$': 'CH₄', r'CH_4': 'CH₄',
      r'($O_2$)': 'O₂', r'$O_2$': 'O₂', r'O_2': 'O₂',
      r'($O_3$)': 'O₃', r'$O_3$': 'O₃', r'O_3': 'O₃',
      r'($N_2$)': 'N₂', r'$N_2$': 'N₂', r'N_2': 'N₂',
      r'($H_2$)': 'H₂', r'$H_2$': 'H₂', r'H_2': 'H₂',
      r'($Cl_2$)': 'Cl₂', r'$Cl_2$': 'Cl₂', r'Cl_2': 'Cl₂',
      r'($NO_2$)': 'NO₂', r'$NO_2$': 'NO₂', r'NO_2': 'NO₂',
      r'($SO_2$)': 'SO₂', r'$SO_2$': 'SO₂', r'SO_2': 'SO₂',
      r'($H_2SO_4$)': 'H₂SO₄', r'$H_2SO_4$': 'H₂SO₄', r'H_2SO_4': 'H₂SO₄',
      r'($HNO_3$)': 'HNO₃', r'$HNO_3$': 'HNO₃', r'HNO_3': 'HNO₃',
      r'($CaCO_3$)': 'CaCO₃', r'$CaCO_3$': 'CaCO₃', r'CaCO_3': 'CaCO₃',
      r'($NH_3$)': 'NH₃', r'$NH_3$': 'NH₃', r'NH_3': 'NH₃',
      r'($C_6H_{12}O_6$)': 'C₆H₁₂O₆', r'$C_6H_{12}O_6$': 'C₆H₁₂O₆', r'C_6H_{12}O_6': 'C₆H₁₂O₆',
      r'($Fe_2O_3$)': 'Fe₂O₃', r'$Fe_2O_3$': 'Fe₂O₃', r'Fe_2O_3': 'Fe₂O₃',
      r'($Al_2O_3$)': 'Al₂O₃', r'$Al_2O_3$': 'Al₂O₃', r'Al_2O_3': 'Al₂O₃',
      r'($KMnO_4$)': 'KMnO₄', r'$KMnO_4$': 'KMnO₄', r'KMnO_4': 'KMnO₄',
      r'($Na_2CO_3$)': 'Na₂CO₃', r'$Na_2CO_3$': 'Na₂CO₃',
      r'($NaHCO_3$)': 'NaHCO₃', r'$NaHCO_3$': 'NaHCO₃',
      r'($Si$)': 'Si', r'$Si$': 'Si',
      r'($Ge$)': 'Ge', r'$Ge$': 'Ge',
      r'($Ga$)': 'Ga', r'$Ga$': 'Ga',
      r'($GaAs$)': 'GaAs', r'$GaAs$': 'GaAs',
    };
    chemSubscripts.forEach((key, val) => cleaned = cleaned.replaceAll(key, val));

    // Exponents & Units Clean
    cleaned = cleaned
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
        .replaceAll(r'm^3', 'm³')
        .replaceAll(r'cm^2', 'cm²')
        .replaceAll(r'm^2', 'm²')
        .replaceAll(r'$$', '')
        .trim();

    final rawLines = cleaned
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final List<String> distinctBlocks = [];
    String currentBlock = '';

    for (final line in rawLines) {
      final isNewBlockHeader =
          line.startsWith('•') ||
          line.startsWith('-') ||
          line.toLowerCase().startsWith('option') ||
          line.toLowerCase().startsWith('statement') ||
          line.startsWith('📌') ||
          line.toLowerCase().startsWith('key takeaway') ||
          line.toLowerCase().startsWith('conclusion') ||
          line.toLowerCase().startsWith('method') ||
          RegExp(r'^[0-9]{1,2}[\.\)]\s').hasMatch(line);

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
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
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

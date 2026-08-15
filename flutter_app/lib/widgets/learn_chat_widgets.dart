import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/learn_models.dart';
import '../utils/learn_effects.dart';
import 'latex_text.dart';

// ==========================================
// 📖 1. INTERACTIVE WORD / GLOSSARY PARSER
// ==========================================
class InteractiveWordText extends StatelessWidget {
  final String rawText;
  final TextStyle baseStyle;
  final bool isTeacher;

  const InteractiveWordText({
    super.key,
    required this.rawText,
    required this.baseStyle,
    this.isTeacher = false,
  });

  void _showDefinitionModal(BuildContext context, String word, String meaning) {
    LearnEffects.playTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📖 ', style: TextStyle(fontSize: 12)),
                        Text(
                          'Key Term & Concept',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Text(
                word,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Divider(height: 10, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 6),
              Text(
                meaning,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF334155),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RegExp regExp = RegExp(r'\[\[(.*?)\|(.*?)\]\]');
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final Match match in regExp.allMatches(rawText)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: rawText.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final String term = match.group(1)!.trim();
      final String meaning = match.group(2)!.trim();

      spans.add(
        TextSpan(
          text: term,
          style: baseStyle.copyWith(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: const Color(0xFF2563EB),
            decorationThickness: 2.0,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _showDefinitionModal(context, term, meaning),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

// ==========================================
// 🔀 2. POLYMORPHIC CARD RENDERER
// ==========================================
class LearnCardRenderer extends StatelessWidget {
  final LearnCardModel card;
  final Map<String, LearnCharacter> characters;
  final int visibleCount;
  final bool isTyping;
  final ScrollController scrollController;

  const LearnCardRenderer({
    super.key,
    required this.card,
    required this.characters,
    required this.visibleCount,
    required this.isTyping,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    switch (card.type) {
      case 'intro':
        return IntroCardWidget(card: card);
      case 'chat':
        return ModernChatCard(
          card: card,
          characters: characters,
          visibleCount: visibleCount,
          isTyping: isTyping,
          scrollController: scrollController,
        );
      case 'guess':
      case 'quiz':
      case 'final_quiz':
        return QuizCard(card: card);
      case 'summary':
        return SummaryCard(card: card);
      default:
        return Center(child: Text('Unknown Card Type: ${card.type}'));
    }
  }
}

// ==========================================
// 🌟 3. INTRO / COVER CARD WIDGET
// ==========================================
class IntroCardWidget extends StatelessWidget {
  final LearnCardModel card;

  const IntroCardWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final payload = card.introPayload ?? {};
    final String title = payload['title'] ?? 'Welcome to Chapter';
    final String subtitle = payload['subtitle'] ?? 'Interactive Learning Module';
    final List outcomes = payload['outcomes'] ?? payload['learning_outcomes'] ?? [];
    final List targetExams = payload['target_exams'] ?? [];

    return Container(
      width: double.infinity,
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                payload['icon_emoji'] ?? payload['icon'] ?? '🧬',
                style: const TextStyle(fontSize: 56),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFFC7D2FE)),
            ),
            const SizedBox(height: 20),
            if (targetExams.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: targetExams.map((exam) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    exam.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )).toList(),
              ),
            const SizedBox(height: 28),
            if (outcomes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.yellowAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Aaj Hum Kya Padhne Waale Hain?",
                          style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...outcomes.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("✔  ", style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 13)),
                          Expanded(
                            child: Text(
                              item.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 💬 4. MODERN CHAT CARD (WITH GLOSSARY SUPPORT)
// ==========================================
class ModernChatCard extends StatelessWidget {
  final LearnCardModel card;
  final Map<String, LearnCharacter> characters;
  final int visibleCount;
  final bool isTyping;
  final ScrollController scrollController;

  const ModernChatCard({
    super.key,
    required this.card,
    required this.characters,
    required this.visibleCount,
    required this.isTyping,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    List<LearnChatMessage> msgs = card.messages ?? [];
    int countToShow = visibleCount.clamp(0, msgs.length);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: countToShow + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == countToShow && isTyping) {
          return _buildTypingDotsBubble(context);
        }

        final msg = msgs[index];
        final char = characters[msg.speaker] ?? LearnCharacter(name: msg.speaker, role: 'student', avatar: '👦');
        final isTeacher = char.role == 'teacher' || msg.speaker == 'aman';

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: isTeacher ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isTeacher) ...[
                  _buildAvatarBadge(char, isTeacher: false),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isTeacher ? const Color(0xFFEEF2FF) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isTeacher ? 16 : 4),
                        bottomRight: Radius.circular(isTeacher ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isTeacher ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              char.name.isNotEmpty ? char.name : (isTeacher ? 'Aman Sir' : 'Raju'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isTeacher ? const Color(0xFF3730A3) : const Color(0xFFEA580C),
                              ),
                            ),
                            if (msg.emotion != null) ...[
                              const SizedBox(width: 4),
                              Text(msg.emotion!, style: const TextStyle(fontSize: 12)),
                            ],
                            if (isTeacher) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF4F46E5)),
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // 📖 INTERACTIVE GLOSSARY OR LATEX TEXT
                        msg.text.contains('[[') && msg.text.contains(']]')
                            ? InteractiveWordText(
                                rawText: msg.text,
                                baseStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                  height: 1.4,
                                ),
                                isTeacher: isTeacher,
                              )
                            : LatexText(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                  height: 1.4,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                if (isTeacher) ...[
                  const SizedBox(width: 8),
                  _buildAvatarBadge(char, isTeacher: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingDotsBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BouncingTypingDots(),
                SizedBox(width: 8),
                Text("Aman Sir is typing...", style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildAvatarBadge(LearnCharacter(name: "Aman Sir", role: "teacher", avatar: "👨‍🏫"), isTeacher: true),
        ],
      ),
    );
  }

  Widget _buildAvatarBadge(LearnCharacter char, {required bool isTeacher}) {
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTeacher ? const Color(0xFF4F46E5) : const Color(0xFFFFEDD5),
            border: Border.all(
              color: isTeacher ? const Color(0xFF818CF8) : const Color(0xFFFDBA74),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              char.avatar.isNotEmpty ? char.avatar : (isTeacher ? '👨‍🏫' : '👦'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        if (isTeacher)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// 💬 5. BOUNCING TYPING DOTS ANIMATION
// ==========================================
class BouncingTypingDots extends StatefulWidget {
  const BouncingTypingDots({super.key});

  @override
  State<BouncingTypingDots> createState() => _BouncingTypingDotsState();
}

class _BouncingTypingDotsState extends State<BouncingTypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double value = sin((_controller.value * 2 * pi) - (index * 0.6));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 5,
              height: 5 + (value.abs() * 4),
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ==========================================
// 🧠 6. QUIZ & GUESS CARD WITH SHAKE ANIMATION
// ==========================================
class QuizCard extends StatefulWidget {
  final LearnCardModel card;
  const QuizCard({super.key, required this.card});

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> with SingleTickerProviderStateMixin {
  String? selectedOptionId;
  bool isSubmitted = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.card.quizPayload!;
    final List options = (payload['options'] as List)
        .map((o) => LearnQuizOption.fromJson(o))
        .toList();
    final String correctId = payload['correct_option_id'] ?? '';
    final bool isGuessType = widget.card.type == 'guess';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final double offset = sin(_shakeController.value * pi * 4) * 8;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGuessType ? const Color(0xFFE0E7FF) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isGuessType ? '🤔 Quick Guess' : '🧠 Quick Check',
                    style: TextStyle(
                      color: isGuessType ? const Color(0xFF3730A3) : const Color(0xFFD97706),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LatexText(
                  payload['question'] ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  bool isCorrect = opt.id == correctId;
                  bool isSelected = opt.id == selectedOptionId;
                  Color btnColor = Colors.white;
                  Color borderColor = const Color(0xFFE2E8F0);

                  if (isSubmitted) {
                    if (isCorrect) {
                      btnColor = const Color(0xFFDCFCE7);
                      borderColor = const Color(0xFF22C55E);
                    }
                    if (isSelected && !isCorrect) {
                      btnColor = const Color(0xFFFEE2E2);
                      borderColor = const Color(0xFFEF4444);
                    }
                  } else if (isSelected) {
                    borderColor = const Color(0xFF4F46E5);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: btnColor,
                        padding: const EdgeInsets.all(14),
                        alignment: Alignment.centerLeft,
                        side: BorderSide(color: borderColor, width: isSelected ? 1.5 : 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (isSubmitted) return;

                        setState(() {
                          selectedOptionId = opt.id;
                          isSubmitted = true;
                        });

                        if (opt.id == correctId) {
                          LearnEffects.playCorrect();
                        } else {
                          LearnEffects.playWrong();
                          _shakeController.forward(from: 0.0);
                        }
                      },
                      child: LatexText('${opt.id}) ${opt.text}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B))),
                    ),
                  );
                }),
                if (isSubmitted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: LatexText(
                      '💡 Explanation: ${payload['explanation']}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📜 7. SUMMARY CARD
// ==========================================
class SummaryCard extends StatelessWidget {
  final LearnCardModel card;
  const SummaryCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final payload = card.summaryPayload!;
    final List points = payload['revision_points'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            payload['title'] ?? 'Summary',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: points.length,
              itemBuilder: (context, idx) {
                final pt = points[idx];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pt['topic'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(height: 6),
                        LatexText(pt['point'] ?? '', style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🏆 8. MILESTONE CELEBRATION CARD WIDGET
// ==========================================
class MilestoneCardWidget extends StatelessWidget {
  final Map<String, dynamic> payload;
  final VoidCallback onContinue;

  const MilestoneCardWidget({super.key, required this.payload, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LearnEffects.playSuccess();
    });

    return Container(
      color: const Color(0xFF4F46E5),
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(payload['badge_emoji'] ?? '🎉', style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            payload['title'] ?? 'GREAT JOB!',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.yellowAccent),
          ),
          const SizedBox(height: 8),
          Text(
            payload['completed_topic'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '⚡ +${payload['xp_earned'] ?? 50} XP  |  ${payload['milestone_progress'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            payload['motivational_quote'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              LearnEffects.playTap();
              onContinue();
            },
            child: const Text(
              'Continue to Next Sub-Topic ➔',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}

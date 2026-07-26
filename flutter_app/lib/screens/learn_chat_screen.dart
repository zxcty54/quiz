import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📳 Ultra-Light Haptic & System Sound Engine
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/latex_text.dart';

// ==========================================
// 🔊 SOFT SOUND & SUBTLE HAPTIC ENGINE
// ==========================================
class LearnEffects {
  // 👆 Next Button Tap / Screen Tap ("tick" + ultra-light selection click)
  static void playTap() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  // 📨 Chat Bubble Reveal ("pop" + subtle click)
  static void playMessagePop() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  // ✅ Correct Answer ("ding" + light impact)
  static void playCorrect() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  // ❌ Wrong Answer ("thuk" + single light impact)
  static void playWrong() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.lightImpact();
  }

  // 🎉 Chapter / Milestone Complete ("success" + light impact)
  static void playSuccess() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.lightImpact();
  }
}

// ==========================================
// 1. DATA MODELS
// ==========================================

class LearnCharacter {
  final String name;
  final String role;
  final String avatar;

  LearnCharacter({required this.name, required this.role, required this.avatar});

  factory LearnCharacter.fromJson(Map<String, dynamic> json) {
    return LearnCharacter(
      name: json['name'] ?? '',
      role: json['role'] ?? 'student',
      avatar: json['avatar'] ?? '👤',
    );
  }
}

class LearnChatMessage {
  final String speaker;
  final String text;
  final String? emotion;

  LearnChatMessage({required this.speaker, required this.text, this.emotion});

  factory LearnChatMessage.fromJson(Map<String, dynamic> json) {
    return LearnChatMessage(
      speaker: json['speaker'] ?? '',
      text: json['text'] ?? '',
      emotion: json['emotion'],
    );
  }
}

class LearnQuizOption {
  final String id;
  final String text;

  LearnQuizOption({required this.id, required this.text});

  factory LearnQuizOption.fromJson(Map<String, dynamic> json) {
    return LearnQuizOption(id: json['id'] ?? '', text: json['text'] ?? '');
  }
}

class LearnCardModel {
  final String cardSlug;
  final String type; // 'chat', 'guess', 'quiz', 'summary', 'final_quiz', 'milestone'
  final String conceptId;
  final int level;
  final int currentProgress;
  final int totalProgress;
  final List<LearnChatMessage>? messages;
  final Map<String, dynamic>? quizPayload;
  final Map<String, dynamic>? summaryPayload;
  final Map<String, dynamic>? milestonePayload;
  final String? nextSlug;
  final String? buttonText;

  LearnCardModel({
    required this.cardSlug,
    required this.type,
    required this.conceptId,
    required this.level,
    required this.currentProgress,
    required this.totalProgress,
    this.messages,
    this.quizPayload,
    this.summaryPayload,
    this.milestonePayload,
    this.nextSlug,
    this.buttonText,
  });

  factory LearnCardModel.fromJson(Map<String, dynamic> json) {
    List<LearnChatMessage>? msgs;
    if (json['messages'] != null) {
      msgs = (json['messages'] as List)
          .map((m) => LearnChatMessage.fromJson(m))
          .toList();
    }

    return LearnCardModel(
      cardSlug: json['card_slug'] ?? '',
      type: json['type'] ?? 'chat',
      conceptId: json['concept_id'] ?? '',
      level: json['level'] ?? 1,
      currentProgress: json['progress']?['current'] ?? 1,
      totalProgress: json['progress']?['total'] ?? 1,
      messages: msgs,
      quizPayload: json['quiz_payload'] ?? json['final_quiz_payload'] ?? json['guess_payload'],
      summaryPayload: json['summary_payload'],
      milestonePayload: json['milestone_payload'],
      nextSlug: json['navigation']?['next'],
      buttonText: json['navigation']?['button_text'],
    );
  }
}

class LearnChapterData {
  final String id;
  final String title;
  final int totalCards;
  final Map<String, LearnCharacter> characters;
  final Map<String, LearnCardModel> cardsMap;
  final String firstCardSlug;

  LearnChapterData({
    required this.id,
    required this.title,
    required this.totalCards,
    required this.characters,
    required this.cardsMap,
    required this.firstCardSlug,
  });

  factory LearnChapterData.fromJson(Map<String, dynamic> json) {
    Map<String, LearnCharacter> chars = {};
    if (json['characters'] != null) {
      (json['characters'] as Map<String, dynamic>).forEach((key, val) {
        chars[key] = LearnCharacter.fromJson(val);
      });
    }

    Map<String, LearnCardModel> cards = {};
    List cardList = json['cards'] ?? [];
    for (var c in cardList) {
      LearnCardModel model = LearnCardModel.fromJson(c);
      cards[model.cardSlug] = model;
    }

    return LearnChapterData(
      id: json['chapter']?['id'] ?? 'bio_cell',
      title: json['chapter']?['title'] ?? 'Chapter',
      totalCards: json['chapter']?['total_cards'] ?? cardList.length,
      characters: chars,
      cardsMap: cards,
      firstCardSlug: cardList.isNotEmpty ? cardList[0]['card_slug'] : '',
    );
  }
}

// ==========================================
// 2. MAIN SCREEN
// ==========================================

class LearnChatScreen extends StatefulWidget {
  final String? jsonUrl;
  final String? chapterTitle;

  const LearnChatScreen({super.key, this.jsonUrl, this.chapterTitle});

  @override
  State<LearnChatScreen> createState() => _LearnChatScreenState();
}

class _LearnChatScreenState extends State<LearnChatScreen> {
  LearnChapterData? chapterData;
  String currentCardSlug = '';
  int visibleMessageCount = 1;
  bool isTyping = false;
  bool isLoading = true;
  String? errorMessage;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchChapterJson();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChapterJson() async {
    final url = widget.jsonUrl ??
        'https://raw.githubusercontent.com/zxcty54/quiz/refs/heads/main/learn/biology/cell.json';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> parsedJson = json.decode(utf8.decode(response.bodyBytes));
        LearnChapterData data = LearnChapterData.fromJson(parsedJson);

        final prefs = await SharedPreferences.getInstance();
        String savedSlug = prefs.getString('progress_${data.id}') ?? data.firstCardSlug;
        if (!data.cardsMap.containsKey(savedSlug)) savedSlug = data.firstCardSlug;

        if (mounted) {
          setState(() {
            chapterData = data;
            currentCardSlug = savedSlug;
            visibleMessageCount = 1;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "Error ${response.statusCode}: Data load nahi ho paya.";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Network Error: Internet connection check karein.";
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProgress(String slug) async {
    if (chapterData == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('progress_${chapterData!.id}', slug);
  }

  void _handleNextTap(LearnCardModel currentCard) {
    if (isTyping) return;
    
    // 👆 Soft Tap Effect
    LearnEffects.playTap();

    if (currentCard.type == 'chat') {
      int totalMsgs = currentCard.messages?.length ?? 0;
      if (visibleMessageCount < totalMsgs) {
        setState(() {
          isTyping = true;
        });

        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) {
            setState(() {
              isTyping = false;
              visibleMessageCount++;
            });
            // 📨 Subtle Message Pop Effect
            LearnEffects.playMessagePop();
            _scrollToBottom();
          }
        });
        return;
      }
    }

    if (currentCard.nextSlug != null &&
        currentCard.nextSlug != "FINISH" &&
        chapterData!.cardsMap.containsKey(currentCard.nextSlug)) {
      String next = currentCard.nextSlug!;
      _saveProgress(next);
      setState(() {
        currentCardSlug = next;
        visibleMessageCount = 1;
        isTyping = false;
      });
    } else {
      _saveProgress(chapterData!.firstCardSlug);
      // 🎉 Soft Chapter Completion Effect
      LearnEffects.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Chapter Completed! Excellent Job!')),
      );
      Navigator.pop(context);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(widget.chapterTitle ?? 'Loading Chapter...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF4F46E5),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4F46E5)),
              SizedBox(height: 14),
              Text("Preparing Interactive Session...", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null || chapterData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error'), backgroundColor: const Color(0xFF4F46E5)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("⚠️", style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(errorMessage ?? "Could not load data", textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });
                    _fetchChapterJson();
                  },
                  child: const Text("Retry", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      );
    }

    LearnCardModel currentCard = chapterData!.cardsMap[currentCardSlug]!;

    if (currentCard.type == 'milestone') {
      return Scaffold(
        body: SafeArea(
          child: MilestoneCardWidget(
            payload: currentCard.milestonePayload ?? {},
            onContinue: () => _handleNextTap(currentCard),
          ),
        ),
      );
    }

    int totalMsgs = currentCard.messages?.length ?? 0;
    bool isAllMessagesRevealed = (visibleMessageCount >= totalMsgs && !isTyping) || currentCard.type != 'chat';

    String buttonLabel = 'Tap to Read Next 💬';
    if (isTyping) {
      buttonLabel = 'Aman Sir is typing...';
    } else if (isAllMessagesRevealed) {
      buttonLabel = currentCard.buttonText ?? 'Next Card ➔';
    } else if (currentCard.messages != null && visibleMessageCount < totalMsgs) {
      final nextMsg = currentCard.messages![visibleMessageCount];
      final char = chapterData!.characters[nextMsg.speaker];
      if (char != null && char.role == 'student') {
        buttonLabel = '💬 "${nextMsg.text}"';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapterData!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: currentCard.currentProgress / currentCard.totalProgress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                minHeight: 5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentCard.currentProgress}/${currentCard.totalProgress}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
          )
        ],
      ),
      body: GestureDetector(
        onTap: () => _handleNextTap(currentCard),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<String>(currentCardSlug),
                  child: _LearnCardRenderer(
                    card: currentCard,
                    characters: chapterData!.characters,
                    visibleCount: visibleMessageCount,
                    isTyping: isTyping,
                    scrollController: _scrollController,
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAllMessagesRevealed ? const Color(0xFF4F46E5) : const Color(0xFF2563EB),
                    minimumSize: const Size.fromHeight(52),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _handleNextTap(currentCard),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isAllMessagesRevealed ? Icons.arrow_forward_rounded : Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// POLYMORPHIC CARD RENDERER
class _LearnCardRenderer extends StatelessWidget {
  final LearnCardModel card;
  final Map<String, LearnCharacter> characters;
  final int visibleCount;
  final bool isTyping;
  final ScrollController scrollController;

  const _LearnCardRenderer({
    required this.card,
    required this.characters,
    required this.visibleCount,
    required this.isTyping,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    switch (card.type) {
      case 'chat':
        return _ModernChatCard(
          card: card,
          characters: characters,
          visibleCount: visibleCount,
          isTyping: isTyping,
          scrollController: scrollController,
        );
      case 'guess':
      case 'quiz':
      case 'final_quiz':
        return _QuizCard(card: card);
      case 'summary':
        return _SummaryCard(card: card);
      default:
        return Center(child: Text('Unknown Card Type: ${card.type}'));
    }
  }
}

// MODERN CHAT CARD
class _ModernChatCard extends StatelessWidget {
  final LearnCardModel card;
  final Map<String, LearnCharacter> characters;
  final int visibleCount;
  final bool isTyping;
  final ScrollController scrollController;

  const _ModernChatCard({
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
        final char = characters[msg.speaker] ?? LearnCharacter(name: msg.speaker, role: 'student', avatar: '👤');
        final isTeacher = char.role == 'teacher';

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
                              char.name,
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
                        LatexText(
                          msg.text,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.4),
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
                _BouncingTypingDots(),
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
              char.avatar,
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

// 💬 3-DOTS BOUNCING ANIMATION
class _BouncingTypingDots extends StatefulWidget {
  const _BouncingTypingDots();

  @override
  State<_BouncingTypingDots> createState() => _BouncingTypingDotsState();
}

class _BouncingTypingDotsState extends State<_BouncingTypingDots> with SingleTickerProviderStateMixin {
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

// QUIZ & GUESS CARD WITH SOFT HAPTICS & SOUND
class _QuizCard extends StatefulWidget {
  final LearnCardModel card;
  const _QuizCard({required this.card});

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> with SingleTickerProviderStateMixin {
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

                        // 🎯 Trigger Soft Sounds & Light Haptics
                        if (opt.id == correctId) {
                          LearnEffects.playCorrect(); // ✅ Soft Click + Light Haptic
                        } else {
                          LearnEffects.playWrong(); // ❌ Soft Alert + Light Haptic
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

// SUMMARY CARD
class _SummaryCard extends StatelessWidget {
  final LearnCardModel card;
  const _SummaryCard({required this.card});

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

// 🏆 MILESTONE CELEBRATION CARD WIDGET
class MilestoneCardWidget extends StatelessWidget {
  final Map<String, dynamic> payload;
  final VoidCallback onContinue;

  const MilestoneCardWidget({Key? key, required this.payload, required this.onContinue}) : super(key: key);

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

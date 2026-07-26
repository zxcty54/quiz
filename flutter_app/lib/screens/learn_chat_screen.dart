import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/latex_text.dart';

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

  LearnChatMessage({required this.speaker, required this.text});

  factory LearnChatMessage.fromJson(Map<String, dynamic> json) {
    return LearnChatMessage(
      speaker: json['speaker'] ?? '',
      text: json['text'] ?? '',
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
  final String type;
  final String conceptId;
  final int level;
  final int currentProgress;
  final int totalProgress;
  final List<LearnChatMessage>? messages;
  final Map<String, dynamic>? quizPayload;
  final Map<String, dynamic>? summaryPayload;
  final String? nextSlug;

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
    this.nextSlug,
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
      quizPayload: json['quiz_payload'] ?? json['final_quiz_payload'],
      summaryPayload: json['summary_payload'],
      nextSlug: json['navigation']?['next'],
    );
  }
}

class LearnChapterData {
  final String title;
  final int totalCards;
  final Map<String, LearnCharacter> characters;
  final Map<String, LearnCardModel> cardsMap;
  final String firstCardSlug;

  LearnChapterData({
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
        setState(() {
          chapterData = LearnChapterData.fromJson(parsedJson);
          currentCardSlug = chapterData!.firstCardSlug;
          visibleMessageCount = 1;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Error ${response.statusCode}: Chapter data load nahi ho paya.";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Network Error: Internet connection check karein.";
        isLoading = false;
      });
    }
  }

  void _handleNextTap(LearnCardModel currentCard) {
    if (currentCard.type == 'chat') {
      int totalMsgs = currentCard.messages?.length ?? 0;
      if (visibleMessageCount < totalMsgs) {
        setState(() {
          visibleMessageCount++;
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
        return;
      }
    }

    if (currentCard.nextSlug != null && chapterData!.cardsMap.containsKey(currentCard.nextSlug)) {
      setState(() {
        currentCardSlug = currentCard.nextSlug!;
        visibleMessageCount = 1;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Chapter Completed!')),
      );
      Navigator.pop(context);
    }
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
    int totalMsgs = currentCard.messages?.length ?? 0;
    bool isAllMessagesRevealed = visibleMessageCount >= totalMsgs || currentCard.type != 'chat';

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
              'Card ${currentCard.currentProgress}/${currentCard.totalProgress}',
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
              child: _LearnCardRenderer(
                card: currentCard,
                characters: chapterData!.characters,
                visibleCount: visibleMessageCount,
                scrollController: _scrollController,
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
                      Text(
                        isAllMessagesRevealed ? 'Next Card ➔' : 'Tap to Read Next 💬',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isAllMessagesRevealed ? Icons.arrow_forward_rounded : Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 20,
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
  final ScrollController scrollController;

  const _LearnCardRenderer({
    required this.card,
    required this.characters,
    required this.visibleCount,
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
          scrollController: scrollController,
        );
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
  final ScrollController scrollController;

  const _ModernChatCard({
    required this.card,
    required this.characters,
    required this.visibleCount,
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
      itemCount: countToShow,
      itemBuilder: (context, index) {
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

  Widget _buildAvatarBadge(LearnCharacter char, {required bool isTeacher}) {
    return Container(
      width: 36,
      height: 36,
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
    );
  }
}

// QUIZ CARD
class _QuizCard extends StatefulWidget {
  final LearnCardModel card;
  const _QuizCard({required this.card});

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  String? selectedOptionId;
  bool isSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final payload = widget.card.quizPayload!;
    final List options = (payload['options'] as List)
        .map((o) => LearnQuizOption.fromJson(o))
        .toList();
    final String correctId = payload['correct_option_id'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                child: const Text('🧠 Quick Check', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12)),
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
                      setState(() {
                        selectedOptionId = opt.id;
                        isSubmitted = true;
                      });
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

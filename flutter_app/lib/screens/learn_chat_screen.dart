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
// 2. MAIN SCREEN (FETCHES LIVE GITHUB JSON)
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
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchChapterJson();
  }

  Future<void> _fetchChapterJson() async {
    final url = widget.jsonUrl ?? 'https://raw.githubusercontent.com/zxcty54/quiz/refs/heads/main/learn/biology/cell.json';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> parsedJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          chapterData = LearnChapterData.fromJson(parsedJson);
          currentCardSlug = chapterData!.firstCardSlug;
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
        errorMessage = "Network Error: Please check your internet connection.";
        isLoading = false;
      });
    }
  }

  void _goToNextCard(String? nextSlug) {
    if (nextSlug != null && chapterData!.cardsMap.containsKey(nextSlug)) {
      setState(() {
        currentCardSlug = nextSlug;
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
        appBar: AppBar(
          title: Text(widget.chapterTitle ?? 'Loading Chapter...', style: const TextStyle(fontSize: 16)),
          backgroundColor: const Color(0xFF075E54),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF075E54)),
              SizedBox(height: 12),
              Text("Loading Cell Chapter JSON...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null || chapterData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
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
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });
                    _fetchChapterJson();
                  },
                  child: const Text("Retry"),
                )
              ],
            ),
          ),
        ),
      );
    }

    LearnCardModel currentCard = chapterData!.cardsMap[currentCardSlug]!;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapterData!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: currentCard.currentProgress / currentCard.totalProgress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
                minHeight: 4,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${currentCard.currentProgress}/${currentCard.totalProgress}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _LearnCardRenderer(
              card: currentCard,
              characters: chapterData!.characters,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _goToNextCard(currentCard.nextSlug),
              child: Text(
                currentCard.nextSlug == "CHAPTER_COMPLETED" ? 'Finish Chapter 🎉' : 'Next Card ➔',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// POLYMORPHIC CARD RENDERER
class _LearnCardRenderer extends StatelessWidget {
  final LearnCardModel card;
  final Map<String, LearnCharacter> characters;

  const _LearnCardRenderer({required this.card, required this.characters});

  @override
  Widget build(BuildContext context) {
    switch (card.type) {
      case 'chat':
        return _WhatsAppChatCard(card: card, characters: characters);
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

// WHATSAPP CHAT CARD
class _WhatsAppChatCard extends StatelessWidget {
  final LearnCardModel card;
  final Map<String, LearnCharacter> characters;

  const _WhatsAppChatCard({required this.card, required this.characters});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      itemCount: card.messages?.length ?? 0,
      itemBuilder: (context, index) {
        final msg = card.messages![index];
        final char = characters[msg.speaker] ?? LearnCharacter(name: msg.speaker, role: 'student', avatar: '👤');
        final isTeacher = char.role == 'teacher';

        return Align(
          alignment: isTeacher ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isTeacher ? const Color(0xFFE7FFDB) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isTeacher ? 12 : 0),
                bottomRight: Radius.circular(isTeacher ? 0 : 12),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isTeacher) Text(char.avatar, style: const TextStyle(fontSize: 16)),
                if (!isTeacher) const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        char.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isTeacher ? const Color(0xFF075E54) : Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 2),
                      LatexText(
                        msg.text,
                        style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (isTeacher) const SizedBox(width: 6),
                if (isTeacher) Text(char.avatar, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
            child: const Text('🧠 Quick Check', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          LatexText(
            payload['question'] ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            bool isCorrect = opt.id == correctId;
            bool isSelected = opt.id == selectedOptionId;
            Color btnColor = Colors.white;

            if (isSubmitted) {
              if (isCorrect) btnColor = Colors.green.shade100;
              if (isSelected && !isCorrect) btnColor = Colors.red.shade100;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: btnColor,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerLeft,
                  side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade300),
                ),
                onPressed: () {
                  setState(() {
                    selectedOptionId = opt.id;
                    isSubmitted = true;
                  });
                },
                child: LatexText('${opt.id}) ${opt.text}', style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
              ),
            );
          }),
          if (isSubmitted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: LatexText(
                '💡 Explanation: ${payload['explanation']}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
            )
          ]
        ],
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
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: points.length,
              itemBuilder: (context, idx) {
                final pt = points[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pt['topic'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                      const SizedBox(height: 4),
                      LatexText(pt['point'] ?? '', style: const TextStyle(fontSize: 13.5)),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

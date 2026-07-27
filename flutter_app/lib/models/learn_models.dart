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
  final String cardId;
  final String cardSlug;
  final String type; // 'intro', 'chat', 'guess', 'quiz', 'summary', 'milestone'
  final String conceptId;
  final int level;
  final int currentProgress;
  final int totalProgress;
  final List<LearnChatMessage>? messages;
  final Map<String, dynamic>? introPayload;
  final Map<String, dynamic>? quizPayload;
  final Map<String, dynamic>? summaryPayload;
  final Map<String, dynamic>? milestonePayload;
  final String? nextSlug;
  final String? buttonText;

  LearnCardModel({
    required this.cardId,
    required this.cardSlug,
    required this.type,
    required this.conceptId,
    required this.level,
    required this.currentProgress,
    required this.totalProgress,
    this.messages,
    this.introPayload,
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
      cardId: json['card_id'] ?? json['card_slug'] ?? '',
      cardSlug: json['card_slug'] ?? json['card_id'] ?? '',
      type: json['type'] ?? 'chat',
      conceptId: json['concept_id'] ?? '',
      level: json['level'] ?? 1,
      currentProgress: json['progress']?['current'] ?? 1,
      totalProgress: json['progress']?['total'] ?? 1,
      messages: msgs,
      introPayload: json['intro_payload'],
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
  final List<LearnCardModel> cardsList;
  final Map<String, LearnCardModel> cardsMap;

  LearnChapterData({
    required this.id,
    required this.title,
    required this.totalCards,
    required this.characters,
    required this.cardsList,
    required this.cardsMap,
  });

  factory LearnChapterData.fromJson(Map<String, dynamic> json) {
    Map<String, LearnCharacter> chars = {};
    if (json['characters'] != null) {
      (json['characters'] as Map<String, dynamic>).forEach((key, val) {
        chars[key] = LearnCharacter.fromJson(val);
      });
    }

    List<LearnCardModel> cardList = [];
    Map<String, LearnCardModel> map = {};

    if (json['cards'] != null) {
      for (var c in (json['cards'] as List)) {
        LearnCardModel model = LearnCardModel.fromJson(c);
        cardList.add(model);
        if (model.cardId.isNotEmpty) map[model.cardId] = model;
        if (model.cardSlug.isNotEmpty) map[model.cardSlug] = model;
      }
    }

    return LearnChapterData(
      id: json['topic_id'] ?? json['chapter']?['id'] ?? 'bio_cell',
      title: json['topic_title'] ?? json['chapter']?['title'] ?? 'Chapter',
      // 🔑 DYNAMIC FIX: Actual loaded cards ki length hi real count mani jayegi
      totalCards: cardList.length,
      characters: chars,
      cardsList: cardList,
      cardsMap: map,
    );
  }
}

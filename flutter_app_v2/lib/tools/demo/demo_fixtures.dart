import 'package:mocktester_v2/core/models/question_model.dart';
import 'package:mocktester_v2/features/learn/domain/duolingo_payload.dart';
import 'package:mocktester_v2/features/learn/domain/learn_models.dart';

/// Small, self-contained data set so every screen can be opened in the demo
/// build without touching the network.
class DemoFixtures {
  DemoFixtures._();

  // ------------------------------------------------------------- questions --
  static final List<Question> questions = <Question>[
    Question(
      qe: 'Which Article of the Indian Constitution provides for the Right to '
          'Constitutional Remedies?',
      qh: 'भारतीय संविधान का कौन सा अनुच्छेद संवैधानिक उपचारों का अधिकार देता है?',
      options: const <String>[
        'Article 19',
        'Article 21',
        'Article 32',
        'Article 44',
      ],
      oe: const <String>['Article 19', 'Article 21', 'Article 32', 'Article 44'],
      oh: const <String>['अनुच्छेद 19', 'अनुच्छेद 21', 'अनुच्छेद 32', 'अनुच्छेद 44'],
      answerIndex: 2,
      explanation:
          'Article 32 empowers a citizen to move the Supreme Court directly '
          'for the enforcement of Fundamental Rights. Dr. Ambedkar called it '
          'the "heart and soul" of the Constitution.',
      ee: 'Article 32 lets a citizen approach the Supreme Court directly when a '
          'Fundamental Right is violated.',
      eh: 'अनुच्छेद 32 नागरिक को मूल अधिकार हनन पर सीधे सर्वोच्च न्यायालय जाने का अधिकार देता है।',
    ),
    Question(
      qe: 'The revolt of 1857 began from which cantonment town?',
      options: const <String>['Meerut', 'Jhansi', 'Kanpur', 'Barrackpore'],
      answerIndex: 0,
      explanation:
          'The sepoys of Meerut revolted on 10 May 1857, which is treated as '
          'the starting point of the First War of Indian Independence.',
    ),
    Question(
      qe: 'Which Bihar district has the highest literacy rate as per the last census?',
      options: const <String>['Patna', 'Rohtas', 'Gaya', 'Muzaffarpur'],
      answerIndex: 1,
      explanation:
          'Rohtas recorded the highest literacy rate among Bihar districts, '
          'closely followed by Patna. Recheck with the latest census release.',
    ),
  ];

  /// The dictionary shape that [Question.fromJson] also supports.
  static List<Map<String, dynamic>> get rawQuestions =>
      questions.map((Question q) => q.toJson()).toList();

  // --------------------------------------------------------------- mapping --
  static const Map<String, dynamic> subjectMapping = <String, dynamic>{
    'phy_mapping': <Map<String, String>>[
      {'title': 'Light — Reflection & Refraction', 'path': 'static/physics/light.json'},
      {'title': 'Motion & Force', 'path': 'static/physics/motion.json'},
    ],
    'bio_mapping': <Map<String, String>>[
      {'title': 'Cell Structure', 'path': 'static/biology/cell.json'},
      {'title': 'Human Diseases', 'path': 'static/biology/disease.json'},
    ],
    'chem_mapping': <Map<String, String>>[
      {'title': 'Acids, Bases & Salts', 'path': 'static/chemistry/acidbase.json'},
    ],
    'polity_mapping': <Map<String, String>>[
      {'title': 'Fundamental Rights', 'path': 'static/polity/rights.json'},
      {'title': 'Parliament of India', 'path': 'static/polity/parliament.json'},
    ],
    'history_mapping': <Map<String, String>>[
      {'title': 'Revolt of 1857', 'path': 'static/history/ancient.json'},
    ],
    'aptitude_mapping': <Map<String, String>>[
      {'title': 'Percentage', 'path': 'aptitude/set1.json'},
    ],
  };

  static const Map<String, dynamic> sectionalData = <String, dynamic>{
    'bpsc': <Map<String, String>>[
      {'title': 'BPSC Prelims Mock 1', 'path': 'static/history/ancient.json'},
      {'title': 'BPSC Prelims Mock 2', 'path': 'static/polity/rights.json'},
    ],
    'ssc': <Map<String, String>>[
      {'title': 'SSC GK Mock 1', 'path': 'static/geography/mapping.json'},
    ],
  };

  static const Map<String, dynamic> appConfig = <String, dynamic>{
    'today_update': <String, dynamic>{
      'show': true,
      'title': 'Demo build — remote config working',
      'text': 'Demo build',
      'url': 'https://www.mocktester.online',
    },
    'launch_roadmap': <Map<String, String>>[
      {'text': '🔥 Demo: widget gallery + API smoke report', 'color': '0xFF2563EB'},
      {'text': '✅ Demo: every screen openable', 'color': '0xFF059669'},
    ],
  };

  static const Map<String, dynamic> homeData = <String, dynamic>{
    'hero': <String, dynamic>{
      'title': 'Demo Home Data',
      'subtitle': 'Loaded from fixtures, not the network',
    },
  };

  // ------------------------------------------------------------ learn data --
  /// Keyed by speaker name: the learn widgets look characters up with
  /// `characters[message.speaker]`.
  static final Map<String, LearnCharacter> characters = <String, LearnCharacter>{
    'Aarav': LearnCharacter(name: 'Aarav', role: 'teacher', avatar: '👨‍🏫'),
    'Meera': LearnCharacter(name: 'Meera', role: 'student', avatar: '👩‍🎓'),
  };

  /// `ChapterSelectScreen` wants chapter title → JSON path, which is a
  /// different shape from [subjectMapping] (subject → mapping file).
  static const Map<String, String> chapterMapping = <String, String>{
    'Modern History — Set 1': 'History/modern_set1.json',
    'Indian Polity — Set 1': 'Polity/polity_set1.json',
    'Bihar Special — Set 1': 'Bihar/bihar_set1.json',
  };

  static final LearnCardModel chatCard = LearnCardModel(
    cardId: 'demo-chat-1',
    cardSlug: 'demo-chat-1',
    type: 'chat',
    conceptId: 'demo',
    level: 1,
    currentProgress: 1,
    totalProgress: 4,
    messages: <LearnChatMessage>[
      LearnChatMessage(
        speaker: 'Aarav',
        text: 'Namaste! Aaj hum light ke reflection ko samjhenge.',
        emotion: 'happy',
      ),
      LearnChatMessage(
        speaker: 'Meera',
        text: 'Sir, mirror me image ulti kyun dikhti hai?',
        emotion: 'curious',
      ),
    ],
  );

  static final LearnCardModel introCard = LearnCardModel(
    cardId: 'demo-intro-1',
    cardSlug: 'demo-intro-1',
    type: 'intro',
    conceptId: 'demo',
    level: 1,
    currentProgress: 1,
    totalProgress: 4,
    introPayload: const <String, dynamic>{
      'title': 'Reflection of Light',
      'subtitle': 'Concept 1 of 4',
      'description': 'Demo payload for the intro card renderer.',
      'icon': '🔆',
    },
  );

  static final LearnCardModel quizCard = LearnCardModel(
    cardId: 'demo-quiz-1',
    cardSlug: 'demo-quiz-1',
    type: 'quiz',
    conceptId: 'demo',
    level: 1,
    currentProgress: 3,
    totalProgress: 4,
    quizPayload: const <String, dynamic>{
      'question': 'Angle of incidence is always equal to …',
      'options': <Map<String, String>>[
        {'id': 'A', 'text': 'Angle of reflection'},
        {'id': 'B', 'text': 'Angle of refraction'},
      ],
      'correct': 'A',
      'explanation': 'Second law of reflection.',
    },
  );

  static final DuolingoPayload duolingoPayload = DuolingoPayload(
    microConcept: 'Reflection follows two simple laws: the angle of incidence '
        'equals the angle of reflection, and the incident ray, normal and '
        'reflected ray stay in one plane.',
    steps: const <String>[
      'Light travels in a straight line until it meets a surface.',
      'A mirror bounces it back at exactly the same angle.',
      'That is why a plane mirror forms a virtual, laterally inverted image.',
    ],
    challengeQuestion: 'A ray hits a mirror at 30°. What is the angle of reflection?',
    options: const <String, String>{'A': '30°', 'B': '60°', 'C': '90°'},
    correctAnswer: 'A',
    explanation: 'Angle of incidence (30°) = angle of reflection (30°).',
  );

  // ---------------------------------------------------------------- others --
  static const Map<String, dynamic> communityPost = <String, dynamic>{
    'id': 'demo-post-1',
    'author_name': 'Demo Aspirant',
    'author_handle': 'demo',
    'post_text': 'Demo post rendered by CommunityPostCard — '
        'no network required.',
    'likes_count': 12,
    'comments_count': 3,
    'is_poll': false,
  };

  static const Map<String, dynamic> batchData = <String, dynamic>{
    'id': 'demo-batch-1',
    'batch_name': 'Demo Batch — BPSC 71st',
    'coaching_name': 'MockTester Demo Coaching',
    'target_exam': 'BPSC',
    'tests': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'demo-test-1',
        'title': 'Demo Batch Test 1',
        'questions_json': <Map<String, dynamic>>[
          <String, dynamic>{
            'qe': 'Demo batch question?',
            'options': <String>['A', 'B', 'C', 'D'],
            'answerIndex': 1,
            'explanation': 'Fixture answer.',
          },
        ],
      },
    ],
  };

  static const List<Map<String, dynamic>> responseBreakdown =
      <Map<String, dynamic>>[
    <String, dynamic>{'question': 'Q1', 'is_correct': true, 'selected_option': 'A', 'time_spent': 31},
    <String, dynamic>{'question': 'Q2', 'is_correct': false, 'selected_option': 'C', 'time_spent': 52},
    <String, dynamic>{'question': 'Q3', 'is_correct': false, 'selected_option': null, 'time_spent': 12},
  ];
}

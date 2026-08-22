import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorProfileScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _mocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCreatorData();
  }

  Future<void> _fetchCreatorData() async {
    try {
      final client = Supabase.instance.client;

      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      final mocksRes = await client
          .from('creator_mocks')
          .select()
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _mocks = mocksRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openTelegram(String? urlOrHandle) async {
    if (urlOrHandle == null || urlOrHandle.isEmpty) return;
    String cleanUrl = urlOrHandle.startsWith('http') ? urlOrHandle : 'https://t.me/$urlOrHandle';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startMockTest(Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions in this test!')));
      return;
    }

    List<Question> parsedQuestions = [];
    for (var item in rawList) {
      if (item is Map) {
        parsedQuestions.add(Question.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    if (parsedQuestions.isEmpty) return;

    Supabase.instance.client
        .from('creator_mocks')
        .update({'attempts_count': (mock['attempts_count'] ?? 0) + 1})
        .eq('id', mock['id'])
        .then((_) {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Mock Test', // 👈 Fixed parameter name
          questions: parsedQuestions,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Creator Profile not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_profile!['name'] ?? 'Educator Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        (_profile!['name'] ?? 'E')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile!['name'] ?? '',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _profile!['subject_specialty'] ?? 'Mentor / Educator',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          if (_profile!['telegram_handle'] != null && _profile!['telegram_handle'].toString().isNotEmpty)
                            GestureDetector(
                              onTap: () => _openTelegram(_profile!['telegram_handle']),
                              child: Row(
                                children: const [
                                  Icon(Icons.telegram, color: Color(0xFF0088CC), size: 18),
                                  SizedBox(width: 4),
                                  Text('Join Channel', style: TextStyle(color: Color(0xFF0088CC), fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Created Mock Tests (${_mocks.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_mocks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No mock tests published yet.'),
                ),
              )
            else
              ..._mocks.map((m) {
                final List qList = m['questions_json'] ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                m['subject'] ?? 'General',
                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                                const SizedBox(width: 3),
                                Text('${m['attempts_count'] ?? 0} Attempts', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(m['title'] ?? 'Mock Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('${qList.length} Questions  •  ${m['duration_mins'] ?? 10} Mins', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () => _startMockTest(m),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('⚡ Start Free Mock Test', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

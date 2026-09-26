import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import 'batch_classroom_screen.dart';
import 'sectional_cbt_screen.dart';

// ---------------------------------------------------------------------------
// 📦 1. BATCHES TAB (Live Classroom Batches - Screenshot Matching Design)
// ---------------------------------------------------------------------------
class CreatorBatchesTab extends StatelessWidget {
  final List<dynamic> batches;
  final bool isDarkMode;

  const CreatorBatchesTab({super.key, required this.batches, required this.isDarkMode});

  static const Color _primaryBlue = Color(0xFF2563EB);

  void _openUnlockBatchDialog(BuildContext context, Map<String, dynamic> batch) {
    final codeCtrl = TextEditingController();
    final cardSurface = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          batch['batch_name'] ?? 'Unlock Classroom Batch',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admission/Fee receipt par diya gaya secret batch code enter karein:',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. PATNA100',
                labelText: 'Batch Secret Code',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final entered = codeCtrl.text.trim();
              final actual = (batch['batch_code'] ?? '').toString().trim();
              Navigator.pop(ctx);

              if (entered.isNotEmpty && entered.toUpperCase() == actual.toUpperCase()) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('unlocked_batch_${batch['id']}', true);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Batch Unlocked! Entering Classroom...'),
                    backgroundColor: Color(0xFF16A34A),
                    duration: Duration(seconds: 1),
                  ),
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchClassroomScreen(
                      batchData: batch,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                );
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Incorrect Batch Code. Please contact coaching.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Unlock Batch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.class_outlined, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text('No active batches listed yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                'Classroom test series and notes batches will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          itemCount: batches.length,
          itemBuilder: (context, idx) {
            final b = batches[idx];
            final String batchId = b['id']?.toString() ?? '';
            final bool isUnlocked = prefs?.getBool('unlocked_batch_$batchId') ?? false;

            final int testsCount = (b['tests_count'] as int?) ?? ((b['batch_tests'] as List?)?.length ?? 0);
            final String targetExam = (b['target_exam'] ?? b['target_pattern'] ?? '').toString().trim();
            final feeAmount = b['fee_amount'];
            final String feeType = (b['fee_type'] ?? 'FREE').toString();
            final String batchCode = (b['batch_code'] ?? '').toString().trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Batch Name + Target Exam Badge + Fee/Price Tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['batch_name'] ?? 'Classroom Batch',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            if (targetExam.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  targetExam,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF60A5FA),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            feeAmount != null && feeAmount > 0 ? '₹$feeAmount' : feeType,
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUnlocked ? const Color(0xFF16A34A).withOpacity(0.2) : Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isUnlocked ? 'ENROLLED' : 'LOCKED',
                              style: TextStyle(
                                color: isUnlocked ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFF334155)),
                  const SizedBox(height: 10),

                  // Row 2: Code Details + Copy Code / Unlock Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Code: $batchCode • $testsCount Mocks',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          if (batchCode.isNotEmpty)
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: batchCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Batch Code copied to clipboard!'),
                                    backgroundColor: Color(0xFF16A34A),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  'Copy Code 📋',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              if (isUnlocked) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BatchClassroomScreen(
                                      batchData: b,
                                      isDarkMode: isDarkMode,
                                    ),
                                  ),
                                );
                              } else {
                                _openUnlockBatchDialog(context, b);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isUnlocked ? const Color(0xFF16A34A) : _primaryBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isUnlocked ? 'Enter 🚀' : 'Unlock 🔑',
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 🎯 2. FREE MOCKS TAB (Existing CBT Launcher Code)
// ---------------------------------------------------------------------------
class CreatorFreeMocksTab extends StatelessWidget {
  final List<dynamic> mocks;
  final bool isDarkMode;

  const CreatorFreeMocksTab({super.key, required this.mocks, required this.isDarkMode});

  static const Color _primaryBlue = Color(0xFF2563EB);

  void _launchAttachedMock(BuildContext context, Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) return;

    List<Question> qList = [];
    for (var item in rawList) {
      if (item is Map) {
        qList.add(Question.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    if (qList.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Mock Drill',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardSurface = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (mocks.isEmpty) {
      return Center(
        child: Text('No open practice mocks available.', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: mocks.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
      itemBuilder: (context, idx) {
        final m = mocks[idx];
        final totalQs = (m['questions_json'] as List?)?.length ?? 0;
        final duration = m['duration_mins'] ?? 15;
        final attempts = m['attempts_count'] ?? 0;

        return Container(
          color: cardSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (m['subject'] ?? 'General').toString().toUpperCase(),
                      style: const TextStyle(color: _primaryBlue, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('$attempts attempts', style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m['title'] ?? 'Practice Mock Test',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalQs Questions • $duration mins • Instant Result',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _launchAttachedMock(context, m),
                  child: const Text('Start Mock →', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 🏆 3. WALL OF FAME TAB (Screenshot Matching Gold Frame & Horizontal Cards)
// ---------------------------------------------------------------------------
class CreatorWallOfFameTab extends StatelessWidget {
  final List<dynamic> selections;
  final bool isDarkMode;

  const CreatorWallOfFameTab({super.key, required this.selections, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    if (selections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.military_tech_rounded, size: 42, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 14),
              Text(
                'Wall of Fame is Empty',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Star achievers, qualifying ranks & student testimonials will be highlighted here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'HALL OF FAME SELECTIONS',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${selections.length}+ Selections',
                  style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Horizontal Scrollable Topper Cards
            SizedBox(
              height: 145,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selections.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, idx) {
                  final s = selections[idx];
                  final String name = (s['student_name'] ?? '').toString().trim();
                  final String post = (s['post_cleared'] ?? '').toString().trim();
                  final String exam = (s['target_exam'] ?? '').toString().trim();
                  final String photo = (s['photo_url'] ?? '').toString().trim();

                  return Container(
                    width: 125,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF59E0B),
                          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: photo.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name.isNotEmpty ? name : 'Candidate',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        if (exam.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            exam,
                            maxLines: 1,
                            style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 10),
                          ),
                        ],
                        if (post.isNotEmpty)
                          Text(
                            post,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🏫 4. ABOUT & CAMPUS TAB (Faculty, Facilities & Info - Existing Code)
// ---------------------------------------------------------------------------
class CreatorAboutCampusTab extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? coaching;
  final List<dynamic> galleryImages;
  final bool isDarkMode;

  const CreatorAboutCampusTab({
    super.key,
    required this.profile,
    required this.coaching,
    required this.galleryImages,
    required this.isDarkMode,
  });

  static const Color _primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final cardSurface = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final aboutText = coaching?['description'] ??
        profile?['bio'] ??
        'Premier preparation institute providing focused guidance and test series for competitive exams.';
    final fullAddress = coaching?['landmark_address'] ?? coaching?['landmark'] ?? 'Bihar, India';
    final establishedYear = coaching?['established_year'] ?? 'Active';
    final List facultyList = (coaching?['faculty_list'] as List?) ?? [];

    return SingleChildScrollView(
      child: Container(
        color: cardSurface,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('About the Institute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              aboutText,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDarkMode ? Colors.grey[300] : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 20),

            // 👨‍🏫 Faculty & Mentors Section
            if (facultyList.isNotEmpty) ...[
              const Text('Our Faculty & Mentors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: facultyList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final f = facultyList[i];
                    final String name = f['name'] ?? 'Faculty';
                    final String subject = f['subject'] ?? 'Mentor';
                    final String exp = (f['exp'] ?? '').toString().trim();
                    final String photo = (f['photo_url'] ?? '').toString().trim();

                    return Container(
                      width: 200,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dividerColor, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _primaryBlue.withOpacity(0.12),
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryBlue),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(subject, style: const TextStyle(fontSize: 11, color: _primaryBlue, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (exp.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(exp.contains('Yr') ? exp : '$exp Yrs Exp', style: TextStyle(fontSize: 10.5, color: Colors.grey[500]), maxLines: 1),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Classroom & Campus Facilities
            if (galleryImages.isNotEmpty) ...[
              const Text('Classroom & Campus Facilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: galleryImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        galleryImages[i].toString(),
                        width: 180,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 180,
                          color: Colors.grey.withOpacity(0.1),
                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            Divider(height: 1, thickness: 0.8, color: dividerColor),
            const SizedBox(height: 14),
            _buildInfoRow(Icons.pin_drop_outlined, 'Address', fullAddress),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today_outlined, 'Serving Since', establishedYear.toString()),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.shield_outlined, 'Status', 'Registered Coaching Centre'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _primaryBlue),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

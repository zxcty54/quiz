import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'selection_proof_system.dart';

class HallOfFameCarouselWidget extends StatefulWidget {
  final bool isDarkMode;

  const HallOfFameCarouselWidget({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<HallOfFameCarouselWidget> createState() => HallOfFameCarouselWidgetState();
}

class HallOfFameCarouselWidgetState extends State<HallOfFameCarouselWidget> {
  List<Map<String, dynamic>> _hallOfFameList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHallOfFame();
  }

  // 🔄 Public refresh method for Pull-to-refresh
  Future<void> fetchHallOfFame() async {
    try {
      final res = await Supabase.instance.client
          .from('coaching_selections')
          .select('*, coachings(name)')
          .eq('is_verified', true)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _hallOfFameList = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DEBUG] Hall of Fame fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🎯 Auto Fetch Enrolled Coaching and Open Claim Sheet
  Future<void> _openClaimSelectionModal() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    String targetCoachingId = '';
    String targetCoachingName = 'Coaching Institute';

    if (user != null) {
      try {
        final recentSub = await client
            .from('batch_submissions')
            .select('batch_tests(batches(coaching_id, coachings(id, name)))')
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle();

        if (recentSub != null && recentSub['batch_tests'] != null) {
          final cData = recentSub['batch_tests']['batches']['coachings'];
          if (cData != null) {
            targetCoachingId = cData['id'].toString();
            targetCoachingName = cData['name']?.toString() ?? 'Coaching Institute';
          }
        }
      } catch (_) {}
    }

    if (targetCoachingId.isEmpty) {
      try {
        final coachings = await client.from('coachings').select('id, name').limit(1).maybeSingle();
        if (coachings != null) {
          targetCoachingId = coachings['id'].toString();
          targetCoachingName = coachings['name'].toString();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (targetCoachingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filhal koi coaching registered nahi mili.')),
      );
      return;
    }

    StudentClaimSelectionSheet.show(
      context,
      coachingId: targetCoachingId,
      coachingName: targetCoachingName,
      isDarkMode: widget.isDarkMode,
      onSuccess: fetchHallOfFame,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CLAIM BANNER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDarkMode
                  ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.military_tech_rounded, color: Color(0xFF6366F1), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crack Kiya Koi Exam? 🎓',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Apna selection claim karein aur coaching ko credit dein.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openClaimSelectionModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'Claim →',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),

        // 2. TESTIMONIALS CAROUSEL (Agar data ho toh hi dikhayega)
        if (!_isLoading && _hallOfFameList.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Hall of Fame 🏆',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '100% VERIFIED',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _hallOfFameList.length,
              itemBuilder: (ctx, i) {
                final item = _hallOfFameList[i];
                final coachingName = item['coachings']?['name'] ?? 'Mentored Coaching';
                final studentName = item['student_name'] ?? 'Candidate';
                final post = item['post_cleared'] ?? 'Officer';
                final exam = item['target_exam'] ?? 'Competitive Exam';
                final quote = item['testimonial_text'] ?? '';

                return Container(
                  width: 270,
                  margin: const EdgeInsets.only(right: 12, bottom: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(widget.isDarkMode ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
                            child: Text(
                              studentName.isNotEmpty ? studentName[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        studentName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                                  ],
                                ),
                                Text(
                                  '$post ($exam)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          quote.isNotEmpty ? '“$quote”' : 'Proud student cracked $exam under mentorship.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                coachingName,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

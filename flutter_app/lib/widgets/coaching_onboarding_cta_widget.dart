import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/creator_auth_screen.dart';
import '../screens/creator_dashboard_screen.dart';

class CoachingOnboardingCtaWidget extends StatelessWidget {
  final bool isDarkMode;

  const CoachingOnboardingCtaWidget({super.key, required this.isDarkMode});

  Future<void> _handleDirectOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHandle = prefs.getString('logged_in_creator_handle');

    // 1. Agar teacher pehle se logged in hai -> Direct Studio Dashboard
    if (savedHandle != null && savedHandle.isNotEmpty && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatorDashboardScreen(
            creatorHandle: savedHandle,
            isDarkMode: isDarkMode,
          ),
        ),
      );
      return;
    }

    // 2. Naya teacher/coaching hai -> Direct Register Modal Popup Open
    if (context.mounted) {
      _openDirectRegisterDialog(context);
    }
  }

  void _openDirectRegisterDialog(BuildContext context) {
    final regNameCtrl = TextEditingController();
    final regHandleCtrl = TextEditingController();
    final regPinCtrl = TextEditingController();
    final regSubjectCtrl = TextEditingController(text: 'BPSC & BSSC Specialist');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🏫 Create Free Digital Classroom',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Institute / Director Name',
                    hintText: 'e.g. Apex Coaching Center',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regHandleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unique Studio Handle (without @)',
                    hintText: 'e.g. apex_patna',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regSubjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Exam / Subject Specialty',
                    hintText: 'e.g. BPSC, BSSC, Daroga, Railway',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Create 4-Digit Security PIN',
                    hintText: 'Enter 4-digit PIN',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = regNameCtrl.text.trim();
                            final h = regHandleCtrl.text.trim().toLowerCase().replaceAll('@', '');
                            final p = regPinCtrl.text.trim();
                            final sub = regSubjectCtrl.text.trim();

                            if (name.isEmpty || h.isEmpty || p.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sabhi details bharein!')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            try {
                              final existing = await Supabase.instance.client
                                  .from('creator_profiles')
                                  .select('handle_id')
                                  .eq('handle_id', h)
                                  .limit(1);

                              if (existing.isNotEmpty) {
                                setModalState(() => isSubmitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Handle ID pehle se registered hai! Doosra chunein.')),
                                  );
                                }
                                return;
                              }

                              // 1. Insert Creator Profile
                              await Supabase.instance.client.from('creator_profiles').insert({
                                'handle_id': h,
                                'name': name,
                                'subject_specialty': sub,
                                'security_pin': p,
                                'followers_count': 0,
                                'is_blocked': false,
                              });

                              // 2. Insert Coaching Entry
                              await Supabase.instance.client.from('coachings').insert({
                                'name': name,
                                'owner_name': h,
                                'district': 'Patna',
                                'city': 'Musallahpur Hat',
                              });

                              // 3. Save Session
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('logged_in_creator_handle', h);

                              if (ctx.mounted) Navigator.pop(ctx);

                              // 4. Direct Entry into Creator Studio
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreatorDashboardScreen(
                                      creatorHandle: h,
                                      isDarkMode: isDarkMode,
                                    ),
                                  ),
                                );
                              }
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Registration Error: $err')),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Launch Coaching Studio 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatorAuthScreen(isDarkMode: isDarkMode),
                        ),
                      );
                    },
                    child: const Text(
                      'Already registered? Login with PIN →',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🏫', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you a teacher or coaching institute?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create your free digital classroom.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Feature Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem('Create Mock Tests', isDarkMode),
                    const SizedBox(height: 6),
                    _buildFeatureItem('Private Batch Tests', isDarkMode),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem('Publish Notes', isDarkMode),
                    const SizedBox(height: 6),
                    _buildFeatureItem('Student Performance Analytics', isDarkMode),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // CTA Action Button (Direct Creator Menu)
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onPressed: () => _handleDirectOnboarding(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Coaching →',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

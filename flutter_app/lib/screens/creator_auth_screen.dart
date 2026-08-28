import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_control_hub_screen.dart';
import 'creator_dashboard_screen.dart';

class CreatorAuthScreen extends StatefulWidget {
  final bool isDarkMode;
  const CreatorAuthScreen({super.key, required this.isDarkMode});

  @override
  State<CreatorAuthScreen> createState() => _CreatorAuthScreenState();
}

class _CreatorAuthScreenState extends State<CreatorAuthScreen> {
  final _handleCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyAndLogin() async {
    final handle = _handleCtrl.text.trim().toLowerCase().replaceAll('@', '');
    final pin = _pinCtrl.text.trim();

    if (handle.isEmpty || pin.isEmpty) {
      setState(() => _errorMessage = 'Handle ID aur Security PIN dono enter karein.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 🛡️ 1. Master Admin Check
      final adminRes = await Supabase.instance.client
          .from('admin_config')
          .select()
          .eq('admin_handle', handle)
          .eq('master_pin', pin)
          .maybeSingle();

      if (adminRes != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_in_creator_handle', 'admin');

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminControlHubScreen(isDarkMode: widget.isDarkMode),
            ),
          );
        }
        return;
      }

      // 👤 2. Regular Creator / Coaching Verification
      final res = await Supabase.instance.client
          .from('creator_profiles')
          .select()
          .eq('handle_id', handle)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Handle "@$handle" registered nahi mila. Niche register karein.';
        });
        return;
      }

      // Block/Ban Check
      if (res['is_blocked'] == true) {
        setState(() {
          _isLoading = false;
          _errorMessage = '🚫 Yeh account temporarily suspend/block kar diya gaya hai.';
        });
        return;
      }

      final String? storedPin = res['security_pin']?.toString();

      // PIN Check
      if (storedPin != null && storedPin.isNotEmpty && storedPin != pin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid PIN! Kripya sahi PIN enter karein.';
        });
        return;
      }

      // 🏫 Auto-Link Coaching Table
      final coachingRes = await Supabase.instance.client
          .from('coachings')
          .select('id')
          .eq('owner_name', handle)
          .maybeSingle();

      if (coachingRes == null) {
        await Supabase.instance.client.from('coachings').insert({
          'name': res['name'] ?? handle,
          'owner_name': handle,
        });
      }

      // Save Session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_creator_handle', handle);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorDashboardScreen(
              creatorHandle: handle,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification failed: $e';
      });
    }
  }

  // 📝 Instant Coaching / Creator Registration Modal
  void _openRegisterDialog() {
    final regNameCtrl = TextEditingController();
    final regHandleCtrl = TextEditingController();
    final regPinCtrl = TextEditingController();
    final regSubjectCtrl = TextEditingController(text: 'General Studies');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    const Text('🏫 Register Coaching / Mentor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regNameCtrl,
                  decoration: const InputDecoration(labelText: 'Institute / Director Name', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regHandleCtrl,
                  decoration: const InputDecoration(labelText: 'Unique Handle ID (without @)', hintText: 'e.g. apex_patna', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regSubjectCtrl,
                  decoration: const InputDecoration(labelText: 'Target Exam / Subject Specialty', hintText: 'e.g. BPSC & BSSC Specialist', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Create 4-Digit Security PIN', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = regNameCtrl.text.trim();
                            final h = regHandleCtrl.text.trim().toLowerCase().replaceAll('@', '');
                            final p = regPinCtrl.text.trim();
                            final sub = regSubjectCtrl.text.trim();

                            if (name.isEmpty || h.isEmpty || p.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sabhi details bharein!')));
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            try {
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
                              });

                              if (ctx.mounted) Navigator.pop(ctx);

                              _handleCtrl.text = h;
                              _pinCtrl.text = p;
                              _verifyAndLogin();
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Error: $err')));
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Register & Access Studio 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Creator & Coaching Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Institute Studio Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Manage Batches, Mocks & Analytics', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 28),

                TextField(
                  controller: _handleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Handle ID',
                    hintText: 'e.g. mentor_rahul or admin',
                    prefixText: '@ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Security PIN',
                    hintText: 'Enter 4 or 6 digit PIN',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _verifyAndLogin,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Unlock Studio Dashboard 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),

                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.app_registration_rounded, size: 18),
                    label: const Text('New Institute? Register Handle ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _openRegisterDialog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

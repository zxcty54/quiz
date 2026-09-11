import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_telegram_alert.dart';
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
      // 🛡️ 1. Master Admin Check (Via Secure Server-Side RPC Function)
      final bool isMasterAdmin = await Supabase.instance.client.rpc(
        'verify_admin_pin',
        params: {'input_handle': handle, 'input_pin': pin},
      );

      if (isMasterAdmin) {
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

      // 👤 2. Regular Creator Check
      final resList = await Supabase.instance.client
          .from('creator_profiles')
          .select()
          .eq('handle_id', handle)
          .limit(1);

      if (resList.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Handle "@$handle" registered nahi mila. Niche register karein.';
        });
        return;
      }

      final res = resList.first;

      if (res['is_blocked'] == true) {
        setState(() {
          _isLoading = false;
          _errorMessage = '🚫 Yeh account temporarily suspend/block kar diya gaya hai.';
        });
        return;
      }

      // 🔑 PIN verification using secret_pin (with security_pin fallback)
      final String? storedPin = (res['secret_pin'] ?? res['security_pin'])?.toString();
      if (storedPin != null && storedPin.isNotEmpty && storedPin != pin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid PIN! Admin dwara provide kiya gaya sahi PIN enter karein.';
        });
        return;
      }

      // 🛑 3. Approval Check
      final bool isApproved = res['is_approved'] ?? false;
      if (!isApproved) {
        setState(() {
          _isLoading = false;
          _errorMessage = '⏳ Aapka account abhi Admin review ke liye pending hai.';
        });
        return;
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

  // 📝 Register Modal
  void _openRegisterDialog() {
    final regNameCtrl = TextEditingController();
    final regHandleCtrl = TextEditingController();
    final regAddressCtrl = TextEditingController();

    final List<String> examCategories = [
      'BPSC CCE / PCS Exams',
      'BSSC CGL & Inter Level',
      'Bihar Daroga (SI) & Police Constable',
      'BPSC TRE (Teacher Recruitment)',
      'Railway (NTPC, Group D, ALP)',
      'SSC (CGL, CHSL, MTS, GD)',
      'Banking (IBPS, SBI PO / Clerk)',
      'Defence (NDA, CDS, AFCAT)',
      'UPSC Civil Services',
      'Foundation / All-in-One General Studies',
    ];
    String selectedCategory = examCategories.first;
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
                const SizedBox(height: 12),

                TextField(
                  controller: regNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Coaching Title / Director Name',
                    hintText: 'e.g. Paramount Coaching Hub',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: regAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Address / Landmark',
                    hintText: 'e.g. Musallahpur Hat, Near Main Gate, Patna',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: regHandleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unique Handle ID',
                    hintText: 'e.g. paramount_patna',
                    prefixText: '@ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 4),

                // Handle format hint
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isDarkMode ? Colors.white12 : const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Only lowercase letters (a-z), numbers (0-9) and underscore (_). No spaces or symbols. (3-25 chars)',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Target Exam Specialty',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: examCategories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = regNameCtrl.text.trim();
                            final address = regAddressCtrl.text.trim();
                            final h = regHandleCtrl.text.trim().toLowerCase().replaceAll('@', '');

                            if (name.isEmpty || h.isEmpty || address.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Coaching Title, Address aur Handle bharein!')),
                              );
                              return;
                            }

                            final handleRegex = RegExp(r'^[a-z0-9_]{3,25}$');
                            if (!handleRegex.hasMatch(h)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Handle format invalid! Sirf a-z, 0-9 aur _ use karein (No spaces/symbols).'),
                                  backgroundColor: Colors.red,
                                ),
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

                              final randomPin = (1000 + Random().nextInt(9000)).toString();

                              await Supabase.instance.client.from('creator_profiles').insert({
                                'handle_id': h,
                                'name': name,
                                'subject_specialty': selectedCategory,
                                'secret_pin': randomPin,
                                'followers_count': 0,
                                'is_blocked': false,
                                'is_approved': false,
                              });

                              await Supabase.instance.client.from('coachings').insert({
                                'name': name,
                                'owner_name': h,
                                'landmark_address': address,
                                'city': 'Patna',
                                'is_approved': false,
                              });

                              await AdminTelegramAlert.sendCreatorApprovalRequest(
                                name: name,
                                handle: h,
                                address: address,
                                specialty: selectedCategory,
                                generatedPin: randomPin,
                                imageUrl: '',
                              );

                              if (ctx.mounted) Navigator.pop(ctx);

                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                                        SizedBox(width: 8),
                                        Text('Request Submitted!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Aapki registration request submit ho gayi hai.\n\nVerification complete karne aur Login PIN prapt karne ke liye apni Coaching Billboard aur Classroom ki photos WhatsApp par bhejein.',
                                          style: TextStyle(fontSize: 13, height: 1.4),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Assigned Handle: @$h',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: const Text('Later'),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF16A34A),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.chat_rounded, size: 16),
                                        label: const Text('Send on WhatsApp'),
                                        onPressed: () async {
                                          Navigator.pop(dCtx);
                                          const String whatsappNumber = '91XXXXXXXXXX';
                                          final String text = Uri.encodeComponent(
                                            'Hello MockTester Team, maine coaching register ki hai.\n'
                                            'Handle ID: @$h\n'
                                            'Coaching: $name\n\n'
                                            'Main yahan classroom aur board ki photos bhej raha hoon. Kripya verification karke Studio PIN share karein.',
                                          );
                                          final Uri url = Uri.parse('https://wa.me/$whatsappNumber?text=$text');
                                          try {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            debugPrint('WhatsApp launch error: $e');
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Error: $err')));
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Registration for Review 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                    hintText: 'Enter 4-digit PIN provided by Admin',
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
                    label: const Text('New Institute? Request Creator Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

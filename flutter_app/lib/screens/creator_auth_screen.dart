import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      // 🛡️ 1. Master Admin Check
      final adminResList = await Supabase.instance.client
          .from('admin_config')
          .select()
          .eq('admin_handle', handle)
          .eq('master_pin', pin)
          .limit(1);

      if (adminResList.isNotEmpty) {
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

      final String? storedPin = res['security_pin']?.toString();
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

  // 📝 Register Modal With Image, Title & Address
  void _openRegisterDialog() {
    final regNameCtrl = TextEditingController();
    final regHandleCtrl = TextEditingController();
    final regAddressCtrl = TextEditingController();
    final regSubjectCtrl = TextEditingController(text: 'General Studies');
    File? selectedCoachingImage;
    bool isSubmitting = false;
    final picker = ImagePicker();

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
                const SizedBox(height: 8),

                // 📸 Coaching Photo Picker Container
                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (picked != null) {
                      setModalState(() => selectedCoachingImage = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.35)),
                    ),
                    child: selectedCoachingImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(selectedCoachingImage!, fit: BoxFit.cover, width: double.infinity),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 34, color: Color(0xFF2563EB)),
                              SizedBox(height: 4),
                              Text(
                                'Upload Coaching Banner / Board Image 📷',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                              Text('Photo showing institute name & banner', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                  ),
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
                    labelText: 'Unique Handle ID (without @)',
                    hintText: 'e.g. paramount_patna',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: regSubjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Exam Specialty',
                    hintText: 'e.g. BPSC, BSSC, Daroga Specialist',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
                            final address = regAddressCtrl.text.trim();
                            final h = regHandleCtrl.text.trim().toLowerCase().replaceAll('@', '');
                            final sub = regSubjectCtrl.text.trim();

                            if (name.isEmpty || h.isEmpty || address.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Coaching Title, Address aur Handle bharein!')),
                              );
                              return;
                            }

                            if (selectedCoachingImage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kripya coaching banner/board ki photo upload karein!')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            try {
                              // Check handle existence
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

                              // 📤 1. Upload Photo to Supabase Storage
                              final bytes = await selectedCoachingImage!.readAsBytes();
                              final fileExt = selectedCoachingImage!.path.split('.').last;
                              final fileName = 'onboarding_${h}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                              await Supabase.instance.client.storage
                                  .from('coaching_assets')
                                  .uploadBinary(
                                    fileName,
                                    bytes,
                                    fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
                                  );

                              final imageUrl = Supabase.instance.client.storage
                                  .from('coaching_assets')
                                  .getPublicUrl(fileName);

                              // 🎲 2. Generate Random PIN
                              final randomPin = (1000 + Random().nextInt(9000)).toString();

                              // 3. Insert Profile
                              await Supabase.instance.client.from('creator_profiles').insert({
                                'handle_id': h,
                                'name': name,
                                'subject_specialty': sub,
                                'security_pin': randomPin,
                                'followers_count': 0,
                                'is_blocked': false,
                                'is_approved': false,
                              });

                              // 4. Insert Coaching with Image & Address
                              await Supabase.instance.client.from('coachings').insert({
                                'name': name,
                                'owner_name': h,
                                'banner_url': imageUrl,
                                'landmark_address': address,
                                'city': 'Patna',
                                'is_approved': false,
                              });

                              // 5. Send Photo with Details & PIN to Telegram Admin
                              await AdminTelegramAlert.sendCreatorApprovalRequest(
                                name: name,
                                handle: h,
                                address: address,
                                specialty: sub,
                                generatedPin: randomPin,
                                imageUrl: imageUrl,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);

                              // 6. Show Confirmation Dialog
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.mark_email_read_outlined, color: Color(0xFF16A34A), size: 24),
                                        SizedBox(width: 8),
                                        Text('Request Sent with Image!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    content: const Text(
                                      'Aapki coaching image, title aur address admin ke paas verification ke liye bhej di gayi hai.\n\nApproval milne ke baad aapko PIN provide kiya jayega jisse aap Studio me login kar sakenge.',
                                      style: TextStyle(fontSize: 13, height: 1.4),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: const Text('Understood 👍'),
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
                        : const Text('Submit Photo & Request 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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

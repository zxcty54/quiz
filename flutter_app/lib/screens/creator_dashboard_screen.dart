import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_telegram_alert.dart';
import '../utils/bihar_location_data.dart';
import 'creator_mock_builder_screen.dart';
import 'creator_profile_screen.dart';

class CreatorDashboardScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorDashboardScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _coachingData;
  List<dynamic> _batches = [];
  bool _isLoading = true;

  int _totalViews = 0;
  int _totalMockAttempts = 0;
  int _totalBatchStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadCompleteAnalytics();
  }

  Future<void> _loadCompleteAnalytics() async {
    try {
      final client = Supabase.instance.client;

      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', widget.creatorHandle)
          .maybeSingle();

      final coachingRes = await client
          .from('coachings')
          .select()
          .eq('owner_name', widget.creatorHandle)
          .maybeSingle();

      List<dynamic> batchesRes = [];
      int batchStudentsCount = 0;
      if (coachingRes != null) {
        batchesRes = await client
            .from('batches')
            .select('*, batch_tests(id, test_title)')
            .eq('coaching_id', coachingRes['id'])
            .order('created_at', ascending: false);

        if (batchesRes.isNotEmpty) {
          final batchIds = batchesRes.map((b) => b['id']).toList();
          final submissions = await client
              .from('batch_submissions')
              .select('student_identifier')
              .inFilter('batch_id', batchIds);

          final uniqueStudents = <String>{};
          for (var s in (submissions as List? ?? [])) {
            if (s['student_identifier'] != null) uniqueStudents.add(s['student_identifier']);
          }
          batchStudentsCount = uniqueStudents.length;
        }
      }

      final postsRes = await client
          .from('community_posts')
          .select('views_count')
          .eq('creator_id', widget.creatorHandle);

      final mocksRes = await client
          .from('creator_mocks')
          .select('attempts_count')
          .eq('creator_id', widget.creatorHandle);

      int views = 0;
      for (var p in (postsRes as List? ?? [])) {
        views += (p['views_count'] as int? ?? 0);
      }

      int attempts = 0;
      for (var m in (mocksRes as List? ?? [])) {
        attempts += (m['attempts_count'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _coachingData = coachingRes;
          _batches = batchesRes;
          _totalViews = views;
          _totalMockAttempts = attempts;
          _totalBatchStudents = batchStudentsCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🖼️ MODULAR 1: Sirf Banner / Poster Update Sheet
  void _openBannerModifierSheet() {
    File? newImage;
    bool isSaving = false;
    final picker = ImagePicker();
    final currentUrl = _coachingData?['banner_url'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🖼️ Modify Institute Poster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Recommended: 1200 x 675 px (16:9 Ratio). High quality photo of billboard/toppers.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () async {
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (picked != null) {
                    setModalState(() => newImage = File(picked.path));
                  }
                },
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                  ),
                  child: newImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(newImage!, fit: BoxFit.cover))
                      : (currentUrl.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(currentUrl, fit: BoxFit.cover))
                          : const Center(child: Text('Tap to pick image from gallery 📷', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)))),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: (isSaving || newImage == null)
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            final bytes = await newImage!.readAsBytes();
                            final fileExt = newImage!.path.split('.').last;
                            final fileName = 'banner_${widget.creatorHandle}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                            await Supabase.instance.client.storage
                                .from('coaching_assets')
                                .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true));

                            final updatedUrl = Supabase.instance.client.storage.from('coaching_assets').getPublicUrl(fileName);

                            await Supabase.instance.client
                                .from('coachings')
                                .update({'banner_url': updatedUrl})
                                .eq('owner_name', widget.creatorHandle);

                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadCompleteAnalytics();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Banner Updated!'), backgroundColor: Color(0xFF16A34A)));
                          } catch (e) {
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save New Poster 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📍 MODULAR 2: Sirf Details, Location & Contact Update Sheet
  void _openDetailsModifierSheet() {
    final nameCtrl = TextEditingController(text: _coachingData?['name'] ?? _profile?['name'] ?? '');
    final landmarkCtrl = TextEditingController(text: _coachingData?['landmark_address'] ?? '');
    final contactCtrl = TextEditingController(text: _coachingData?['contact_number'] ?? '');

    String selectedDistrict = _coachingData?['district'] ?? 'Patna';
    if (!kBiharDistrictCityMap.containsKey(selectedDistrict)) selectedDistrict = 'Patna';
    List<String> availableCities = kBiharDistrictCityMap[selectedDistrict] ?? ['Other / Rural Area'];
    String selectedCity = _coachingData?['city'] ?? availableCities.first;
    if (!availableCities.contains(selectedCity)) selectedCity = availableCities.first;

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📍 Modify Coaching Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Coaching Title', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  decoration: const InputDecoration(labelText: 'District (38 Districts)', border: OutlineInputBorder(), isDense: true),
                  items: kBiharDistrictCityMap.keys.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedDistrict = val;
                        availableCities = kBiharDistrictCityMap[val] ?? ['Other / Rural Area'];
                        selectedCity = availableCities.first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedCity,
                  decoration: const InputDecoration(labelText: 'Town / Education Hub', border: OutlineInputBorder(), isDense: true),
                  items: availableCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setModalState(() => selectedCity = val!),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: landmarkCtrl,
                        decoration: const InputDecoration(labelText: 'Landmark / Area', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Helpline No.', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              final updatedName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : (_coachingData?['name'] ?? widget.creatorHandle);

                              await Supabase.instance.client.from('coachings').update({
                                'name': updatedName,
                                'district': selectedDistrict,
                                'city': selectedCity,
                                'landmark_address': landmarkCtrl.text.trim(),
                                'contact_number': contactCtrl.text.trim(),
                              }).eq('owner_name', widget.creatorHandle);

                              await Supabase.instance.client
                                  .from('creator_profiles')
                                  .update({'name': updatedName})
                                  .eq('handle_id', widget.creatorHandle);

                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Details Saved!'), backgroundColor: Color(0xFF16A34A)));
                            } catch (_) {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Details 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // 🏫 MODULAR 3: Manage Batches & Status
  void _openBatchManagerModal() {
    final batchNameCtrl = TextEditingController();
    final batchCodeCtrl = TextEditingController();
    String newBatchStatus = 'LIVE';
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🏫 Manage Classroom Batches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                ...List.generate(_batches.length, (idx) {
                  final b = _batches[idx];
                  final List tests = b['batch_tests'] ?? [];
                  final String bStatus = b['status'] ?? 'LIVE';
                  final bool isHidden = bStatus == 'HIDDEN';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHidden ? Colors.grey.withOpacity(0.1) : (widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b['batch_name'] ?? 'Batch', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('CODE: ${b['batch_code']} • ${tests.length} CBT Tests', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        // Copy Code
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF16A34A)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: b['batch_code']));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied Code: ${b['batch_code']}')));
                          },
                        ),
                        // Status Switcher
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (val) async {
                            await Supabase.instance.client.from('batches').update({'status': val}).eq('id', b['id']);
                            _loadCompleteAnalytics();
                            Navigator.pop(ctx);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'LIVE', child: Text('🟢 Set LIVE')),
                            const PopupMenuItem(value: 'UPCOMING', child: Text('⏳ Set UPCOMING')),
                            const PopupMenuItem(value: 'HIDDEN', child: Text('⚪ HIDE Batch')),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 20),
                const Text('+ Add New Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),

                TextField(controller: batchNameCtrl, decoration: const InputDecoration(labelText: 'Batch Name', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: batchCodeCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Join Code (Password)', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    onPressed: isCreating
                        ? null
                        : () async {
                            final bName = batchNameCtrl.text.trim();
                            final bCode = batchCodeCtrl.text.trim().toUpperCase();
                            if (bName.isEmpty || bCode.isEmpty) return;

                            setModalState(() => isCreating = true);
                            try {
                              await Supabase.instance.client.from('batches').insert({
                                'coaching_id': _coachingData?['id'],
                                'batch_name': bName,
                                'batch_code': bCode,
                                'status': newBatchStatus,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();
                            } catch (_) {
                              setModalState(() => isCreating = false);
                            }
                          },
                    child: const Text('Create Batch Code 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(backgroundColor: bgSurface, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Institute Studio & Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'View Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatorProfileScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_coachingData?['name'] ?? 'Coaching Hub', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('@${widget.creatorHandle} • ${_coachingData?['city'] ?? "Bihar"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Students', '$_totalBatchStudents', Icons.groups_outlined),
                      _buildMetricItem('Batches', '${_batches.length}', Icons.class_outlined),
                      _buildMetricItem('Attempts', '$_totalMockAttempts', Icons.bolt_rounded),
                      _buildMetricItem('Views', '$_totalViews', Icons.remove_red_eye_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🎯 SEPARATE MODULAR MODIFIERS
            const Text('Modify Institute & Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Modify Banner / Poster 🖼️',
              subtitle: 'Change 16:9 billboard photo without affecting address or details.',
              icon: Icons.photo_library_outlined,
              color: const Color(0xFF2563EB),
              onTap: _openBannerModifierSheet,
            ),

            _buildActionCard(
              title: 'Edit Location & Details 📍',
              subtitle: 'Update district, education hub, landmark address or helpline number.',
              icon: Icons.edit_location_alt_outlined,
              color: const Color(0xFF16A34A),
              onTap: _openDetailsModifierSheet,
            ),

            _buildActionCard(
              title: 'Manage Batches & Codes 🏫',
              subtitle: 'Add new batch, toggle LIVE / UPCOMING / HIDE, copy secret code.',
              icon: Icons.vpn_key_outlined,
              color: const Color(0xFFEA580C),
              onTap: _openBatchManagerModal,
            ),
            const SizedBox(height: 14),

            // CBT Tools
            const Text('CBT Mock & Content Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Create CBT Mock Test ⚡',
              subtitle: 'Build timed CBT tests for public feed or private batches.',
              icon: Icons.assignment_add,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreatorMockBuilderScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark)),
              ).then((_) => _loadCompleteAnalytics()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

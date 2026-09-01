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
  List<dynamic> _posts = [];
  List<dynamic> _mocks = [];
  List<dynamic> _batches = [];
  bool _isLoading = true;

  int _totalViews = 0;
  int _totalUpvotes = 0;
  int _totalBookmarks = 0;
  int _totalShares = 0;
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
            if (s['student_identifier'] != null) {
              uniqueStudents.add(s['student_identifier']);
            }
          }
          batchStudentsCount = uniqueStudents.length;
        }
      }

      final postsRes = await client
          .from('community_posts')
          .select('*, post_comments(id)')
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      final mocksRes = await client
          .from('creator_mocks')
          .select()
          .eq('creator_id', widget.creatorHandle)
          .order('created_at', ascending: false);

      int views = 0;
      int upvotes = 0;
      int bookmarks = 0;
      int shares = 0;

      for (var p in (postsRes as List? ?? [])) {
        views += (p['views_count'] as int? ?? 0);
        upvotes += (p['upvotes'] as int? ?? 0);
        bookmarks += (p['bookmarks_count'] as int? ?? 0);
        shares += (p['shares_count'] as int? ?? 0);
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
          _posts = postsRes ?? [];
          _mocks = mocksRes ?? [];
          _totalViews = views;
          _totalUpvotes = upvotes;
          _totalBookmarks = bookmarks;
          _totalShares = shares;
          _totalMockAttempts = attempts;
          _totalBatchStudents = batchStudentsCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics load error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📝 Batch Edit & Status Dialog
  void _openEditBatchDialog(Map<String, dynamic> batch) {
    final nameCtrl = TextEditingController(text: batch['batch_name'] ?? '');
    final codeCtrl = TextEditingController(text: batch['batch_code'] ?? '');
    String status = batch['status'] ?? 'LIVE';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Modify Batch Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Batch Name', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Batch Code', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 14),
                const Text('Batch Visibility & Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('🟢 Live Batch'),
                      selected: status == 'LIVE',
                      selectedColor: const Color(0xFF16A34A).withOpacity(0.2),
                      labelStyle: TextStyle(color: status == 'LIVE' ? const Color(0xFF16A34A) : Colors.grey, fontWeight: FontWeight.bold),
                      onSelected: (v) => setDialogState(() => status = 'LIVE'),
                    ),
                    ChoiceChip(
                      label: const Text('⏳ Upcoming'),
                      selected: status == 'UPCOMING',
                      selectedColor: Colors.amber.withOpacity(0.25),
                      labelStyle: TextStyle(color: status == 'UPCOMING' ? Colors.amber.shade800 : Colors.grey, fontWeight: FontWeight.bold),
                      onSelected: (v) => setDialogState(() => status = 'UPCOMING'),
                    ),
                    ChoiceChip(
                      label: const Text('⚪ Hide / Grey'),
                      selected: status == 'HIDDEN',
                      selectedColor: Colors.grey.withOpacity(0.25),
                      labelStyle: TextStyle(color: status == 'HIDDEN' ? Colors.black87 : Colors.grey, fontWeight: FontWeight.bold),
                      onSelected: (v) => setDialogState(() => status = 'HIDDEN'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await Supabase.instance.client.from('batches').update({
                          'batch_name': nameCtrl.text.trim(),
                          'batch_code': codeCtrl.text.trim().toUpperCase(),
                          'status': status,
                        }).eq('id', batch['id']);

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadCompleteAnalytics();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Batch updated successfully!'), backgroundColor: Color(0xFF16A34A)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: const Text('Save Changes 🚀'),
            ),
          ],
        ),
      ),
    );
  }

  // 🏫 Complete Batch Manager Modal (Live, Upcoming, Hide & Edit)
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
                    const Text('🏫 Manage & Modify Batches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                if (_batches.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('No batches found. Create your first batch below!', style: TextStyle(fontSize: 12.5))),
                  )
                else
                  ...List.generate(_batches.length, (idx) {
                    final b = _batches[idx];
                    final List tests = b['batch_tests'] ?? [];
                    final String bStatus = b['status'] ?? 'LIVE';
                    final bool isHidden = bStatus == 'HIDDEN';

                    Color statusColor = const Color(0xFF16A34A);
                    String statusLabel = 'LIVE';
                    if (bStatus == 'UPCOMING') {
                      statusColor = Colors.amber.shade800;
                      statusLabel = 'UPCOMING';
                    } else if (isHidden) {
                      statusColor = Colors.grey;
                      statusLabel = 'HIDDEN / GREY';
                    }

                    return Opacity(
                      opacity: isHidden ? 0.6 : 1.0,
                      child: Container(
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          b['batch_name'] ?? 'Class Batch',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            decoration: isHidden ? TextDecoration.lineThrough : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 9.5)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                        child: Text('CODE: ${b['batch_code']}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${tests.length} CBT Tests Scheduled', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Edit Action
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF2563EB)),
                              tooltip: 'Modify Batch',
                              onPressed: () => _openEditBatchDialog(b),
                            ),
                            // Copy Code Action
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF16A34A)),
                              tooltip: 'Copy Code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: b['batch_code']));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied Batch Code: ${b['batch_code']}')),
                                );
                              },
                            ),
                            // Delete Action
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Delete Batch',
                              onPressed: () async {
                                try {
                                  await Supabase.instance.client.from('batches').delete().eq('id', b['id']);
                                  setState(() => _batches.removeAt(idx));
                                  setModalState(() {});
                                  _loadCompleteAnalytics();
                                } catch (err) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $err')));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const Divider(height: 24),
                const Text('+ Add New Coaching Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 10),
                TextField(
                  controller: batchNameCtrl,
                  decoration: const InputDecoration(labelText: 'Batch Name (e.g. BSSC CGL 2026 Target)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: batchCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Unique Join Code (e.g. PATNA100)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Initial Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🟢 Live', style: TextStyle(fontSize: 11)),
                      selected: newBatchStatus == 'LIVE',
                      onSelected: (v) => setModalState(() => newBatchStatus = 'LIVE'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('⏳ Upcoming', style: TextStyle(fontSize: 11)),
                      selected: newBatchStatus == 'UPCOMING',
                      onSelected: (v) => setModalState(() => newBatchStatus = 'UPCOMING'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    onPressed: isCreating
                        ? null
                        : () async {
                            final bName = batchNameCtrl.text.trim();
                            final bCode = batchCodeCtrl.text.trim().toUpperCase();

                            if (bName.isEmpty || bCode.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch Name aur Code dono bharein!')));
                              return;
                            }

                            setModalState(() => isCreating = true);
                            try {
                              String? coachingId = _coachingData?['id'];
                              if (coachingId == null) {
                                final existing = await Supabase.instance.client
                                    .from('coachings')
                                    .select('id')
                                    .eq('owner_name', widget.creatorHandle)
                                    .maybeSingle();

                                if (existing != null) {
                                  coachingId = existing['id'];
                                } else {
                                  final newCoaching = await Supabase.instance.client.from('coachings').insert({
                                    'name': _profile?['name'] ?? widget.creatorHandle,
                                    'owner_name': widget.creatorHandle,
                                    'district': 'Patna',
                                    'city': 'Musallahpur Hat',
                                  }).select('id').single();
                                  coachingId = newCoaching['id'];
                                }
                              }

                              await Supabase.instance.client.from('batches').insert({
                                'coaching_id': coachingId,
                                'batch_name': bName,
                                'batch_code': bCode,
                                'status': newBatchStatus,
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadCompleteAnalytics();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Batch "$bName" ($bCode) successfully created!'),
                                    backgroundColor: const Color(0xFF16A34A),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isCreating = false);
                            }
                          },
                    child: isCreating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create Batch Code 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // 🎨 Institute Customizer Modal (Poster Upload with Dimensions & Guidelines)
  void _openInstituteCustomizerModal() {
    final nameCtrl = TextEditingController(text: _coachingData?['name'] ?? _profile?['name'] ?? '');
    final landmarkCtrl = TextEditingController(text: _coachingData?['landmark_address'] ?? _coachingData?['area_locality'] ?? '');
    final contactCtrl = TextEditingController(text: _coachingData?['contact_number'] ?? '');

    String selectedDistrict = _coachingData?['district'] ?? _coachingData?['city'] ?? 'Patna';
    if (!kBiharDistrictCityMap.containsKey(selectedDistrict)) {
      selectedDistrict = 'Patna';
    }

    List<String> availableCities = kBiharDistrictCityMap[selectedDistrict] ?? ['Other / Rural Area'];
    String selectedCity = _coachingData?['city'] ?? availableCities.first;
    if (!availableCities.contains(selectedCity)) {
      selectedCity = availableCities.first;
    }

    File? selectedBannerFile;
    String currentBannerUrl = _coachingData?['banner_url'] ?? '';
    bool isSaving = false;
    final picker = ImagePicker();

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
                    const Text('🎨 Coaching Poster & Branding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 4),

                // 📐 Banner Aspect Ratio & Size Guidelines Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.aspect_ratio_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Recommended Size: 1200 x 675 px (16:9 Ratio, Max 5MB)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 📸 High-Visibility Banner Container (170px Height)
                GestureDetector(
                  onTap: () async {
                    try {
                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (picked != null) {
                        setModalState(() => selectedBannerFile = File(picked.path));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
                    }
                  },
                  child: Container(
                    height: 170, // 👈 Expanded height for crisp banner preview
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4), width: 1.2),
                    ),
                    child: selectedBannerFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(selectedBannerFile!, fit: BoxFit.cover, width: double.infinity),
                          )
                        : (currentBannerUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  currentBannerUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) => const Center(child: Text('Image load failed')),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: Color(0xFF2563EB)),
                                  SizedBox(height: 6),
                                  Text(
                                    'Tap to upload Coaching Poster / Billboard 📷',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                  SizedBox(height: 2),
                                  Text('Clear photo of coaching board, toppers or classroom', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Coaching / Institute Name', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),

                // 📍 1. Bihar 38 Districts Dropdown
                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  decoration: const InputDecoration(
                    labelText: 'Select Bihar District (38 Districts)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.location_city_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  items: kBiharDistrictCityMap.keys.map((dist) {
                    return DropdownMenuItem<String>(
                      value: dist,
                      child: Text(dist, style: const TextStyle(fontSize: 13.5)),
                    );
                  }).toList(),
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

                // 🏙️ 2. Hub Town Dropdown (Cascading)
                DropdownButtonFormField<String>(
                  value: selectedCity,
                  decoration: const InputDecoration(
                    labelText: 'Select City / Educational Hub Town',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.pin_drop_outlined, color: Color(0xFF16A34A), size: 20),
                  ),
                  items: availableCities.map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city, style: const TextStyle(fontSize: 13.5)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedCity = val);
                    }
                  },
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: landmarkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Street / Landmark Address',
                          hintText: 'e.g. Near Bus Stand, 2nd Floor',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact / WhatsApp',
                          hintText: '9876543210',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

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
                              String bannerUrlToSave = currentBannerUrl;

                              if (selectedBannerFile != null) {
                                final bytes = await selectedBannerFile!.readAsBytes();
                                final fileExt = selectedBannerFile!.path.split('.').last;
                                final fileName = 'banner_${widget.creatorHandle}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                                await Supabase.instance.client.storage
                                    .from('coaching_assets')
                                    .uploadBinary(
                                      fileName,
                                      bytes,
                                      fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
                                    );

                                bannerUrlToSave = Supabase.instance.client.storage
                                    .from('coaching_assets')
                                    .getPublicUrl(fileName);
                              }

                              final payload = {
                                'name': nameCtrl.text.trim().isEmpty ? widget.creatorHandle : nameCtrl.text.trim(),
                                'owner_name': widget.creatorHandle,
                                'banner_url': bannerUrlToSave,
                                'district': selectedDistrict,
                                'city': selectedCity,
                                'landmark_address': landmarkCtrl.text.trim(),
                                'contact_number': contactCtrl.text.trim(),
                              };

                              await Supabase.instance.client
                                  .from('coachings')
                                  .upsert(payload, onConflict: 'owner_name');

                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadCompleteAnalytics();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Institute profile & branding successfully saved! 🚀'),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Publish Branding 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Creator Creation Modal (Daily Quiz & PDF Notes)
  void _openCreationModal(String type) {
    final textCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final opCtrl1 = TextEditingController();
    final opCtrl2 = TextEditingController();
    final opCtrl3 = TextEditingController();
    final opCtrl4 = TextEditingController();
    int correctIdx = 0;
    bool isPoll = type == 'quiz';
    bool isPublishing = false;

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
                    Text(
                      isPoll ? '⚡ Publish Daily Rapid Quiz' : '📚 Share PDF Notes & Handouts',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  maxLines: isPoll ? 2 : 3,
                  decoration: InputDecoration(
                    hintText: isPoll ? 'Type Quiz Question text here...' : 'Explain topic or notes headline...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (isPoll) ...[
                  const Text('Options & Correct Answer (Tap letter to set correct):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ...List.generate(4, (idx) {
                    final controllers = [opCtrl1, opCtrl2, opCtrl3, opCtrl4];
                    final isCorrect = correctIdx == idx;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => correctIdx = idx),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCorrect ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                              child: Text(
                                String.fromCharCode(65 + idx),
                                style: TextStyle(fontSize: 12, color: isCorrect ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers[idx],
                              decoration: InputDecoration(hintText: 'Option ${String.fromCharCode(65 + idx)}', isDense: true, border: const OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(labelText: 'Explanation (Optional)', isDense: true, border: OutlineInputBorder()),
                  ),
                ],
                if (type == 'note') ...[
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(labelText: 'Google Drive / Telegram PDF Link (https://...)', isDense: true, border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: isPublishing
                        ? null
                        : () async {
                            final text = textCtrl.text.trim();
                            if (text.isEmpty) return;

                            setModalState(() => isPublishing = true);
                            String content = text;
                            if (type == 'note' && linkCtrl.text.trim().isNotEmpty) content += '\n\n${linkCtrl.text.trim()}';

                            Map<String, dynamic>? pollJson;
                            if (isPoll) {
                              final rawOptions = [opCtrl1.text.trim(), opCtrl2.text.trim(), opCtrl3.text.trim(), opCtrl4.text.trim()].where((o) => o.isNotEmpty).toList();
                              pollJson = {
                                'options': rawOptions,
                                'correct_idx': correctIdx < rawOptions.length ? correctIdx : 0,
                                'votes': List.filled(rawOptions.length, 0),
                                'exp': expCtrl.text.trim().isNotEmpty ? expCtrl.text.trim() : 'Explained by @${widget.creatorHandle}',
                              };
                            }

                            try {
                              String targetTag = isPoll ? 'Daily Quiz ⚡' : 'Current Affairs 📰';
                              final authorName = _profile?['name'] ?? widget.creatorHandle;

                              final inserted = await Supabase.instance.client.from('community_posts').insert({
                                'creator_id': widget.creatorHandle,
                                'author_name': authorName,
                                'content': content,
                                'tag': targetTag,
                                'poll_data': pollJson,
                                'views_count': 1,
                                'is_approved': false,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

                              AdminTelegramAlert.sendForInteractiveApproval(
                                postId: inserted['id'] ?? 0,
                                authorName: authorName,
                                authorHandle: widget.creatorHandle,
                                tag: targetTag,
                                content: content,
                                hasPoll: isPoll,
                              ).catchError((_) => false);

                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();
                            } catch (err) {
                              setModalState(() => isPublishing = false);
                            }
                          },
                    child: isPublishing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit for Review 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
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

    if (_isLoading) {
      return Scaffold(backgroundColor: bgSurface, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Coaching Studio & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'View Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatorProfileScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📊 1. Performance Overview Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_coachingData?['name'] ?? _profile?['name'] ?? 'Coaching Hub', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('INSTITUTE', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  Text('@${widget.creatorHandle} • ${_coachingData?['city'] ?? _profile?['subject_specialty'] ?? 'Exam Mentor'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Students', '$_totalBatchStudents', Icons.groups_outlined),
                      _buildMetricItem('Batches', '${_batches.length}', Icons.class_outlined),
                      _buildMetricItem('CBT Attempts', '$_totalMockAttempts', Icons.bolt_rounded),
                      _buildMetricItem('Public Views', '$_totalViews', Icons.remove_red_eye_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🏫 2. Coaching & Batch Management Hub
            const Text('Coaching & Batch Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Create & Manage Batches 🏫',
              subtitle: 'Edit batches, set Live/Upcoming status, copy join codes, or hide batches.',
              icon: Icons.add_business_outlined,
              color: const Color(0xFF0D9488),
              onTap: _openBatchManagerModal,
            ),

            _buildActionCard(
              title: 'Customize Institute Poster & Location 🎨',
              subtitle: 'Upload 16:9 banner from gallery, set district, city & WhatsApp helpline.',
              icon: Icons.photo_library_outlined,
              color: const Color(0xFFEA580C),
              onTap: _openInstituteCustomizerModal,
            ),
            const SizedBox(height: 12),

            // 🚀 3. Studio Creation Tools
            const Text('CBT Mock & Content Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'CBT Mock Test Builder ⚡',
              subtitle: 'Create timed tests for private batches or public marketing feed.',
              icon: Icons.assignment_add,
              color: const Color(0xFF2563EB),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorMockBuilderScreen(creatorHandle: widget.creatorHandle, isDarkMode: isDark),
                ),
              ).then((_) => _loadCompleteAnalytics()),
            ),

            _buildActionCard(
              title: 'Interactive Daily Quiz Card 🎯',
              subtitle: 'Post instant 4-option poll with solution directly to feed.',
              icon: Icons.poll_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => _openCreationModal('quiz'),
            ),

            _buildActionCard(
              title: 'Publish PDF Notes & Mindmaps 📚',
              subtitle: 'Link Google Drive or Telegram notes without server upload load.',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFF059669),
              onTap: () => _openCreationModal('note'),
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
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
      padding: const EdgeInsets.only(bottom: 12),
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
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11.5, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

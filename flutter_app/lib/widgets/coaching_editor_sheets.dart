import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bihar_location_data.dart';

class CoachingEditorSheets {
  // 🖼️ 1. Poster Modification Modal
  static void openBannerModifierSheet({
    required BuildContext context,
    required String? coachingId,
    required String? currentUrl,
    required String creatorHandle,
    required bool isDarkMode,
    required VoidCallback onSaved,
  }) {
    File? newImage;
    bool isSaving = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  const Text('🖼️ Modify Institute Poster',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Recommended: 1200 x 675 px (16:9 Ratio). High quality photo of billboard.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey)),
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
                      : (currentUrl != null && currentUrl.isNotEmpty
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
                            final fileName = 'banner_${creatorHandle}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                            await Supabase.instance.client.storage
                                .from('coaching_assets')
                                .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true));

                            final updatedUrl = Supabase.instance.client.storage
                                .from('coaching_assets')
                                .getPublicUrl(fileName);

                            await Supabase.instance.client.from('coachings').update({'banner_url': updatedUrl}).eq('id', coachingId!);

                            if (ctx.mounted) Navigator.pop(ctx);
                            onSaved();
                          } catch (e) {
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save New Poster 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📍 2. Location Details Modification Modal
  static void openDetailsModifierSheet({
    required BuildContext context,
    required Map<String, dynamic>? coachingData,
    required String creatorHandle,
    required bool isDarkMode,
    required VoidCallback onSaved,
  }) {
    final nameCtrl = TextEditingController(text: coachingData?['name'] ?? '');
    final landmarkCtrl = TextEditingController(text: coachingData?['landmark_address'] ?? coachingData?['landmark'] ?? '');
    final contactCtrl = TextEditingController(text: coachingData?['contact_number'] ?? coachingData?['phone'] ?? '');
    final taglineCtrl = TextEditingController(text: coachingData?['tagline'] ?? '');
    final yearCtrl = TextEditingController(text: coachingData?['established_year']?.toString() ?? '');
    final descCtrl = TextEditingController(text: coachingData?['description'] ?? '');

    String selectedDistrict = coachingData?['district'] ?? 'Patna';
    if (!kBiharDistrictCityMap.containsKey(selectedDistrict)) selectedDistrict = 'Patna';
    List<String> availableCities = kBiharDistrictCityMap[selectedDistrict] ?? ['Other / Rural Area'];
    String selectedCity = coachingData?['city'] ?? availableCities.first;
    if (!availableCities.contains(selectedCity)) selectedCity = availableCities.first;

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Coaching Title', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Tagline / Specialty (e.g. BPSC & Bihar SI Hub)', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder(), isDense: true),
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
                    Expanded(child: TextField(controller: landmarkCtrl, decoration: const InputDecoration(labelText: 'Landmark / Area', border: OutlineInputBorder(), isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: yearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Serving Since (Yr)', border: OutlineInputBorder(), isDense: true))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'About the Institute', border: OutlineInputBorder(), isDense: true)),
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
                              final updatedName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : (coachingData?['name'] ?? creatorHandle);

                              await Supabase.instance.client.from('coachings').update({
                                'name': updatedName,
                                'district': selectedDistrict,
                                'city': selectedCity,
                                'landmark_address': landmarkCtrl.text.trim(),
                                'tagline': taglineCtrl.text.trim(),
                                'established_year': yearCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                              }).eq('id', coachingData?['id']);

                              await Supabase.instance.client.from('creator_profiles').update({'name': updatedName}).eq('handle_id', creatorHandle);

                              if (ctx.mounted) Navigator.pop(ctx);
                              onSaved();
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

  // 🌐 3. Social & Direct Connect Links Modifier
  static void openSocialLinksModifierSheet({
    required BuildContext context,
    required Map<String, dynamic>? coachingData,
    required bool isDarkMode,
    required VoidCallback onSaved,
  }) {
    final phoneCtrl = TextEditingController(text: coachingData?['phone'] ?? coachingData?['contact_number'] ?? '');
    final tgCtrl = TextEditingController(text: coachingData?['telegram_link'] ?? '');
    final ytCtrl = TextEditingController(text: coachingData?['youtube_url'] ?? '');
    final fbCtrl = TextEditingController(text: coachingData?['facebook_url'] ?? '');
    final webCtrl = TextEditingController(text: coachingData?['website_url'] ?? '');

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
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
                    const Text('🌐 Social & Connect Links', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Text('Ye links creator profile par student connect pills mein dikhte hain.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Call & WhatsApp Number', hintText: 'e.g. 9876543210', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: tgCtrl, decoration: const InputDecoration(labelText: 'Telegram Channel / Group Link', hintText: 'e.g. https://t.me/patna_ias', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: ytCtrl, decoration: const InputDecoration(labelText: 'YouTube Channel Link / Handle', hintText: 'e.g. @BiharSiddhiClasses', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: fbCtrl, decoration: const InputDecoration(labelText: 'Facebook Page URL', hintText: 'e.g. https://facebook.com/myinstitute', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: webCtrl, decoration: const InputDecoration(labelText: 'Official Website (Optional)', hintText: 'e.g. www.mycoaching.com', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              if (coachingData?['id'] != null) {
                                await Supabase.instance.client.from('coachings').update({
                                  'phone': phoneCtrl.text.trim(),
                                  'contact_number': phoneCtrl.text.trim(),
                                  'telegram_link': tgCtrl.text.trim(),
                                  'youtube_url': ytCtrl.text.trim(),
                                  'facebook_url': fbCtrl.text.trim(),
                                  'website_url': webCtrl.text.trim(),
                                }).eq('id', coachingData!['id']);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              onSaved();
                            } catch (_) {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Social Links 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // 👨‍🏫 4. Faculty & Mentors Modifier
  static void openFacultyModifierSheet({
    required BuildContext context,
    required dynamic coachingId,
    required dynamic currentFaculty,
    required bool isDarkMode,
    required VoidCallback onSaved,
  }) {
    List<dynamic> facultyList = List<dynamic>.from(currentFaculty is List ? currentFaculty : []);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👨‍🏫 Manage Faculty & Mentors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Mentor'),
                    onPressed: () {
                      final nCtrl = TextEditingController();
                      final sCtrl = TextEditingController();
                      final eCtrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Add Faculty Mentor'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'Teacher Name (e.g. Anand Sir)', border: OutlineInputBorder(), isDense: true)),
                              const SizedBox(height: 10),
                              TextField(controller: sCtrl, decoration: const InputDecoration(labelText: 'Subject (e.g. Modern History)', border: OutlineInputBorder(), isDense: true)),
                              const SizedBox(height: 10),
                              TextField(controller: eCtrl, decoration: const InputDecoration(labelText: 'Experience (e.g. 10+ Yrs Exp)', border: OutlineInputBorder(), isDense: true)),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                if (nCtrl.text.trim().isNotEmpty) {
                                  setModalState(() {
                                    facultyList.add({
                                      'name': nCtrl.text.trim(),
                                      'subject': sCtrl.text.trim(),
                                      'exp': eCtrl.text.trim(),
                                      'photo_url': '',
                                    });
                                  });
                                }
                                Navigator.pop(dCtx);
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Text('Yeh teachers "About & Campus" tab ke Star Mentors section mein show hote hain.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              const SizedBox(height: 10),
              if (facultyList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No faculty added yet. Tap "+ Add Mentor" above.', style: TextStyle(color: Colors.grey))),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: facultyList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final f = facultyList[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                          child: Text(
                            (f['name'] != null && f['name'].toString().isNotEmpty) ? f['name'][0].toUpperCase() : 'T',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                        title: Text(f['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${f['subject'] ?? ''} • ${f['exp'] ?? ''}', style: const TextStyle(fontSize: 11.5)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          onPressed: () => setModalState(() => facultyList.removeAt(idx)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            if (coachingId != null) {
                              await Supabase.instance.client
                                  .from('coachings')
                                  .update({'faculty_list': facultyList})
                                  .eq('id', coachingId);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            onSaved();
                          } catch (_) {
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Faculty List 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 🏆 5. Wall of Fame & Campus Gallery Modifier
  static void openWallOfFameModifierSheet({
    required BuildContext context,
    required dynamic coachingId,
    required dynamic currentGallery,
    required bool isDarkMode,
    required VoidCallback onSaved,
  }) {
    List<dynamic> gallery = List<dynamic>.from(currentGallery is List ? currentGallery : []);
    bool isSaving = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
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
                    const Text('🏆 Wall of Fame & Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706)),
                  ),
                  icon: const Icon(Icons.military_tech_outlined, size: 18),
                  label: const Text('Add Star Selection / Result 🎓', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final nCtrl = TextEditingController();
                    final eCtrl = TextEditingController();
                    final pCtrl = TextEditingController();
                    final tCtrl = TextEditingController();

                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Add Star Selection Result'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'Student Name (e.g. Rahul Kumar)', border: OutlineInputBorder(), isDense: true)),
                              const SizedBox(height: 10),
                              TextField(controller: eCtrl, decoration: const InputDecoration(labelText: 'Exam Cleared (e.g. BPSC 70th)', border: OutlineInputBorder(), isDense: true)),
                              const SizedBox(height: 10),
                              TextField(controller: pCtrl, decoration: const InputDecoration(labelText: 'Post / Rank (e.g. Revenue Officer)', border: OutlineInputBorder(), isDense: true)),
                              const SizedBox(height: 10),
                              TextField(controller: tCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Student Feedback Quote', border: OutlineInputBorder(), isDense: true)),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                            onPressed: () async {
                              if (nCtrl.text.trim().isNotEmpty && coachingId != null) {
                                await Supabase.instance.client.from('coaching_selections').insert({
                                  'coaching_id': coachingId,
                                  'student_name': nCtrl.text.trim(),
                                  'target_exam': eCtrl.text.trim(),
                                  'post_cleared': pCtrl.text.trim(),
                                  'testimonial_text': tCtrl.text.trim(),
                                  'is_verified': true,
                                  'verified_by': 'TEACHER_DIRECT',
                                });
                              }
                              if (dCtx.mounted) Navigator.pop(dCtx);
                              onSaved();
                            },
                            child: const Text('Publish Result'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Classroom & Campus Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text('Upload Photo'),
                      onPressed: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (picked != null) {
                          setModalState(() => isSaving = true);
                          try {
                            final bytes = await File(picked.path).readAsBytes();
                            final ext = picked.path.split('.').last;
                            final fileName = 'campus_${DateTime.now().millisecondsSinceEpoch}.$ext';

                            await Supabase.instance.client.storage
                                .from('coaching_assets')
                                .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));

                            final url = Supabase.instance.client.storage.from('coaching_assets').getPublicUrl(fileName);
                            setModalState(() {
                              gallery.add(url);
                              isSaving = false;
                            });
                          } catch (_) {
                            setModalState(() => isSaving = false);
                          }
                        }
                      },
                    ),
                  ],
                ),
                if (gallery.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No classroom photos yet. Upload classroom or library photos for students.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: gallery.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(gallery[i], width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                        ),
                        title: Text('Facility Photo ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          onPressed: () => setModalState(() => gallery.removeAt(i)),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              if (coachingId != null) {
                                await Supabase.instance.client
                                    .from('coachings')
                                    .update({'gallery_images': gallery})
                                    .eq('id', coachingId);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              onSaved();
                            } catch (_) {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Gallery Photos 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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
}

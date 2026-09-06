import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. STAR SELECTION CARD (Wall of Fame Item)
// ==========================================
class StarSelectionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDarkMode;

  const StarSelectionCard({
    super.key,
    required this.data,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['student_name'] ?? 'Candidate';
    final post = data['post_cleared'] ?? 'Officer';
    final exam = data['target_exam'] ?? 'Competitive Exam';
    final quote = data['testimonial_text'] ?? '';
    final isVerified = data['is_verified'] == true;
    final proofUrl = data['proof_file_url'];

    final bgCard = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDarkMode ? Colors.white60 : const Color(0xFF64748B);
    final borderColor = isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? const Color(0xFF16A34A).withOpacity(0.3) : borderColor,
          width: isVerified ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$post • $exam',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'VERIFIED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
            ],
          ),
          if (quote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                '“$quote”',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: secondaryText,
                ),
              ),
            ),
          ],
          if (proofUrl != null && proofUrl.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  'Scorecard / Admit card backed proof',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: secondaryText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================================
// 2. PREMIUM STUDENT CLAIM SELECTION MODAL (BOTTOM SHEET)
// ==========================================================
class StudentClaimSelectionSheet extends StatefulWidget {
  final String coachingId;
  final String coachingName;
  final bool isDarkMode;
  final VoidCallback onSuccess;

  const StudentClaimSelectionSheet({
    super.key,
    required this.coachingId,
    required this.coachingName,
    required this.isDarkMode,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String coachingId,
    required String coachingName,
    required bool isDarkMode,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentClaimSelectionSheet(
        coachingId: coachingId,
        coachingName: coachingName,
        isDarkMode: isDarkMode,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<StudentClaimSelectionSheet> createState() => _StudentClaimSelectionSheetState();
}

class _StudentClaimSelectionSheetState extends State<StudentClaimSelectionSheet> {
  final _nameCtrl = TextEditingController();
  final _postCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _testimonialCtrl = TextEditingController();

  final List<String> _examOptions = [
    'BPSC 70th Prelims/Mains',
    'Bihar Daroga (SI)',
    'BSSC CGL',
    'SSC CGL',
    'Railway NTPC',
    'Other Competitive Exam',
  ];

  late String _selectedExam;
  File? _pickedProofFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedExam = _examOptions.first;
    _prefillCurrentUser();
  }

  void _prefillCurrentUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata?['name'] != null) {
      _nameCtrl.text = user.userMetadata!['name'].toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _postCtrl.dispose();
    _rollCtrl.dispose();
    _testimonialCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedProofFile = File(picked.path));
    }
  }

  Future<void> _handleSubmit() async {
    final name = _nameCtrl.text.trim();
    final post = _postCtrl.text.trim();

    if (name.isEmpty) {
      _showToast('Kripya apna poora naam likhein.');
      return;
    }
    if (post.isEmpty) {
      _showToast('Kripya apni selected post likhein (e.g. Revenue Officer).');
      return;
    }

    setState(() => _isUploading = true);
    HapticFeedback.mediumImpact();

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      String? proofUrl;

      // 1. Upload proof file to Supabase Storage if provided
      if (_pickedProofFile != null) {
        final bytes = await _pickedProofFile!.readAsBytes();
        final ext = _pickedProofFile!.path.split('.').last;
        final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storagePath = 'proofs/$fileName';

        await client.storage.from('selection_proofs').uploadBinary(storagePath, bytes);
        proofUrl = client.storage.from('selection_proofs').getPublicUrl(storagePath);
      }

      // 2. Trigger auto verification database function
      bool isAutoVerified = false;
      try {
        final autoRes = await client.rpc('check_and_auto_verify_selection', params: {
          'p_user_id': currentUser?.id,
          'p_coaching_id': widget.coachingId,
          'p_student_name': name,
        });
        isAutoVerified = autoRes == true;
      } catch (e) {
        debugPrint('[AutoVerify RPC Error]: $e');
      }

      // 3. Save selection record
      await client.from('coaching_selections').insert({
        'coaching_id': widget.coachingId,
        'user_id': currentUser?.id,
        'student_name': name,
        'target_exam': _selectedExam,
        'post_cleared': post,
        'roll_number': _rollCtrl.text.trim().isNotEmpty ? _rollCtrl.text.trim() : null,
        'proof_file_url': proofUrl,
        'testimonial_text': _testimonialCtrl.text.trim(),
        'is_verified': isAutoVerified,
        'verified_by': isAutoVerified ? 'AUTO_SYSTEM' : 'PENDING',
        'verified_at': isAutoVerified ? DateTime.now().toIso8601String() : null,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        _showSuccessSheet(isAutoVerified, name, post);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showToast('Error: $e');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF0F172A)),
    );
  }

  void _showSuccessSheet(bool isVerified, String name, String post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isVerified ? const Color(0xFF16A34A) : const Color(0xFF2563EB)).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                size: 38,
                color: isVerified ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isVerified ? 'Selection Verified Instantly! 🎓' : 'Claim Submitted to Coaching! ⏳',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isVerified
                  ? 'Aapka batch record match ho gaya hai. Coaching ko points credit ho gaye hain.'
                  : 'Aapka proof ${widget.coachingName} ko bhej diya gaya hai. Teacher ke 1-tap approval ke baad badge live ho jayega.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: widget.isDarkMode ? Colors.white70 : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Back to Coaching Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.military_tech_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Claim Your Selection',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryText),
                      ),
                      Text(
                        'Credit your success to ${widget.coachingName}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _buildLabel('STUDENT FULL NAME *', isDark),
            TextField(
              controller: _nameCtrl,
              decoration: _inputStyle(hint: 'e.g. Rahul Kumar', fill: inputBg, border: borderColor),
            ),
            const SizedBox(height: 14),

            _buildLabel('EXAM CRACKED *', isDark),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedExam,
                  dropdownColor: inputBg,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryText),
                  items: _examOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedExam = val!),
                ),
              ),
            ),
            const SizedBox(height: 14),

            _buildLabel('POST / DESIGNATION ACHIEVED *', isDark),
            TextField(
              controller: _postCtrl,
              decoration: _inputStyle(hint: 'e.g. Revenue Officer (RO) / Sub-Inspector', fill: inputBg, border: borderColor),
            ),
            const SizedBox(height: 14),

            _buildLabel('ROLL NUMBER (OPTIONAL / PRIVATE)', isDark),
            TextField(
              controller: _rollCtrl,
              decoration: _inputStyle(hint: 'Used only for authentic validation', fill: inputBg, border: borderColor),
            ),
            const SizedBox(height: 14),

            _buildLabel('SCORECARD / ADMIT CARD PROOF', isDark),
            InkWell(
              onTap: _pickProofImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pickedProofFile != null ? const Color(0xFF16A34A) : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickedProofFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                      color: _pickedProofFile != null ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedProofFile != null ? 'Document Attached ✓' : 'Upload Scorecard / Admit Card',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _pickedProofFile != null ? const Color(0xFF16A34A) : primaryText,
                            ),
                          ),
                          Text(
                            _pickedProofFile != null
                                ? _pickedProofFile!.path.split('/').last
                                : 'Select JPG or PNG from gallery for 100% trust',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            _buildLabel('TESTIMONIAL (HOW DID COACHING HELP YOU?)', isDark),
            TextField(
              controller: _testimonialCtrl,
              maxLines: 3,
              decoration: _inputStyle(
                hint: 'Sir ke daily 50 questions ke mock drills ne speed banayi...',
                fill: inputBg,
                border: borderColor,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isUploading ? null : _handleSubmit,
                child: _isUploading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Submit Verification Proof 🚀',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: isDark ? Colors.white60 : const Color(0xFF475569),
        ),
      ),
    );
  }

  InputDecoration _inputStyle({required String hint, required Color fill, required Color border}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }
}

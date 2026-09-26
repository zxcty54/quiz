import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExamPhotoResizerScreen extends StatefulWidget {
  final bool isDark;
  const ExamPhotoResizerScreen({super.key, required this.isDark});

  @override
  State<ExamPhotoResizerScreen> createState() => _ExamPhotoResizerScreenState();
}

class _ExamPhotoResizerScreenState extends State<ExamPhotoResizerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _targetInputController = TextEditingController(text: '50');

  Uint8List? _imageBytes;
  String? _cachedFilePath;
  int _originalSizeKB = 0;
  bool _isProcessing = false;
  int _selectedTargetKB = 50;
  final List<String> _tempFilesToCleanup = [];

  final List<Map<String, dynamic>> _examPresets = [
    {'label': 'BPSC / BSSC Sign', 'kb': 20, 'icon': Icons.draw_rounded},
    {'label': 'Bihar Govt Photo', 'kb': 50, 'icon': Icons.badge_rounded},
    {'label': 'Admit Card / Doc', 'kb': 100, 'icon': Icons.description_rounded},
    {'label': 'Identity Proof', 'kb': 200, 'icon': Icons.fingerprint_rounded},
  ];

  static const int _maxAllowedBytes = 8 * 1024 * 1024; // 8 MB limit

  @override
  void dispose() {
    _targetInputController.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  void _cleanupTempFiles() {
    for (final filePath in _tempFilesToCleanup) {
      try {
        final f = File(filePath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }
    _tempFilesToCleanup.clear();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;
      await _processImageSafe(picked.path);
    } catch (e) {
      if (mounted) _showToast('Gallery error: $e');
    }
  }

  Future<void> _processImageSafe(String rawPath) async {
    setState(() => _isProcessing = true);

    try {
      final File initialFile = File(rawPath);
      if (!await initialFile.exists()) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final totalBytes = await initialFile.length();
      if (totalBytes > _maxAllowedBytes) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showToast('Image 8 MB se badi hai. Kripya choti image chunein.');
        }
        return;
      }

      final Uint8List? safeBytes = await FlutterImageCompress.compressWithFile(
        rawPath,
        minWidth: 1000,
        minHeight: 1000,
        quality: 80,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (safeBytes == null || !mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safePath = '${tempDir.path}/exam_orig_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final safeFile = File(safePath);
      await safeFile.writeAsBytes(safeBytes, flush: true);
      _tempFilesToCleanup.add(safePath);

      if (mounted) {
        setState(() {
          _imageBytes = safeBytes;
          _cachedFilePath = safePath;
          _originalSizeKB = (safeBytes.lengthInBytes / 1024).round();
          _isProcessing = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showToast('Error loading image: $e');
      }
    }
  }

  Future<File?> _compressToTargetFile(int targetKB) async {
    if (_cachedFilePath == null) return null;

    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/exam_opt_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int minQ = 10;
    int maxQ = 90;
    int currentDim = 900;
    Uint8List? bestBytes;

    // 1. Fast Binary Search Quality Loop
    for (int i = 0; i < 4; i++) {
      final midQ = (minQ + maxQ) ~/ 2;
      final result = await FlutterImageCompress.compressWithFile(
        _cachedFilePath!,
        minWidth: currentDim,
        minHeight: currentDim,
        quality: midQ,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (result == null) break;
      final currentKB = (result.lengthInBytes / 1024).round();

      if (currentKB <= targetKB) {
        bestBytes = result;
        minQ = midQ + 1;
      } else {
        maxQ = midQ - 1;
      }

      if (minQ > maxQ) break;
    }

    // 2. Fallback: Aggressive Step-Down for Dimension & Quality (Especially for <20KB Signatures)
    if (bestBytes == null || (bestBytes.lengthInBytes / 1024) > targetKB) {
      const dimensions = [650, 480, 350, 240];
      const qualities = [65, 45, 30, 18];

      for (final dim in dimensions) {
        for (final q in qualities) {
          final result = await FlutterImageCompress.compressWithFile(
            _cachedFilePath!,
            minWidth: dim,
            minHeight: dim,
            quality: q,
            format: CompressFormat.jpeg,
            keepExif: false,
          );

          if (result != null && (result.lengthInBytes / 1024) <= targetKB) {
            bestBytes = result;
            break;
          }
        }
        if (bestBytes != null) break;
      }
    }

    if (bestBytes != null) {
      final finalFile = File(targetPath);
      await finalFile.writeAsBytes(bestBytes, flush: true);
      _tempFilesToCleanup.add(targetPath);
      return finalFile;
    }
    return null;
  }

  Future<void> _handleSaveOrShare() async {
    if (_cachedFilePath == null || _isProcessing) return;

    final targetKB = int.tryParse(_targetInputController.text.trim()) ?? _selectedTargetKB;
    if (targetKB < 10) {
      _showToast('Target size kam se kam 10 KB honi chahiye.');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final compressed = await _compressToTargetFile(targetKB);
      if (compressed == null) {
        _showToast('Image ko itna chota nahi kiya ja saka. Target badhayein.');
        return;
      }

      final compressedKB = (compressed.lengthSync() / 1024).round();
      final xFile = XFile(compressed.path, name: 'Exam_Photo_${compressedKB}KB.jpg');

      await Share.shareXFiles(
        [xFile],
        text: 'Exam Ready Photo (${compressedKB} KB)',
      );

      if (mounted) {
        _showToast('✅ Photo optimize ho gayi! File save/share karein.');
      }
    } catch (e) {
      _showToast('Error saving file: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Exam Photo & Sign Resizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: cardBg,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload & Preview Card
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
                ),
                child: _imageBytes != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_imageBytes!, height: 180, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Original: $_originalSizeKB KB',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                              ),
                              const Text('Change Photo ↺', style: TextStyle(fontSize: 12, color: Colors.blue)),
                            ],
                          ),
                        ],
                      )
                    : const Column(
                        children: [
                          SizedBox(height: 12),
                          Icon(Icons.photo_library_rounded, size: 42, color: Color(0xFFD97706)),
                          SizedBox(height: 8),
                          Text('Select Photo from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('Passport photo or signature', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          SizedBox(height: 12),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // Exam Presets with Horizontal Scroll (Prevents Small Screen Overflow)
            const Text('Select Exam Target Standard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _examPresets.map((p) {
                  final isSel = _selectedTargetKB == p['kb'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTargetKB = p['kb'];
                          _targetInputController.text = p['kb'].toString();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFD97706) : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? const Color(0xFFD97706) : borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              p['icon'],
                              size: 16,
                              color: isSel ? Colors.white : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${p['label']} (<${p['kb']}KB)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Custom Target Input Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Text('Custom Target: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _targetInputController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        suffixText: 'KB',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Button
            if (_imageBytes != null)
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleSaveOrShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_done_rounded),
                label: Text(
                  _isProcessing ? 'Optimizing...' : 'Save / Export Compressed JPG',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

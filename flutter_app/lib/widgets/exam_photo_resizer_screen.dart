import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

class ExamPhotoResizerScreen extends StatefulWidget {
  final bool isDark;

  const ExamPhotoResizerScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<ExamPhotoResizerScreen> createState() => _ExamPhotoResizerScreenState();
}

class _ExamPhotoResizerScreenState extends State<ExamPhotoResizerScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _cachedFilePath;
  int _originalSizeKB = 0;
  bool _isProcessing = false;
  int _selectedTargetKB = 50;
  final List<String> _tempFilesToCleanup = [];

  final TextEditingController _targetInputController =
      TextEditingController(text: '50');

  final List<Map<String, dynamic>> _examPresets = [
    {'label': 'BPSC / BSSC Sign', 'kb': 20, 'icon': Icons.draw_rounded},
    {'label': 'Bihar Govt Photo', 'kb': 50, 'icon': Icons.badge_rounded},
    {'label': 'Standard Admit/Doc', 'kb': 100, 'icon': Icons.description_rounded},
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
          final sizeMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          _showOverSizeDialog(sizeMB);
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
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safePath = '${tempDir.path}/safe_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final safeFile = File(safePath);
      await safeFile.writeAsBytes(safeBytes, flush: true);
      _tempFilesToCleanup.add(safePath);

      if (mounted) {
        setState(() {
          _imageBytes = safeBytes;
          _cachedFilePath = safeFile.path;
          _originalSizeKB = (safeBytes.lengthInBytes / 1024).round();
          _isProcessing = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showToast('Processing error: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
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

  void _showOverSizeDialog(String currentSizeMB) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Text('File Size Too Large', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Selected image is $currentSizeMB MB.\nPlease select an image smaller than 8 MB.',
          style: TextStyle(
            fontSize: 13,
            color: widget.isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<File?> _compressToTargetFile(int targetKB) async {
    if (_cachedFilePath == null) return null;

    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/exam_resize_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int minQ = 10;
    int maxQ = 90;
    int currentDim = 900;
    Uint8List? bestBytes;

    for (int i = 0; i < 4; i++) {
      final midQ = ((minQ + maxQ) ~/ 2);

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

  Future<void> _handleDownload() async {
    if (_cachedFilePath == null || _isProcessing) return;

    final targetKB = int.tryParse(_targetInputController.text.trim()) ?? _selectedTargetKB;
    if (targetKB < 10) {
      _showToast('Target size kam se kam 10 KB honi chahiye');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final compressed = await _compressToTargetFile(targetKB);
      if (compressed == null) {
        _showToast('Target size is too small for this image.');
        return;
      }

      final compressedKB = (compressed.lengthSync() / 1024).round();
      final Uint8List bytes = await compressed.readAsBytes();
      final defaultFileName = 'Exam_Photo_${compressedKB}KB_${DateTime.now().millisecondsSinceEpoch}';

      final String? savedPath = await FileSaver.instance.saveAs(
        name: defaultFileName,
        bytes: bytes,
        ext: 'jpg',
        mimeType: MimeType.jpeg,
      );

      if (savedPath != null && savedPath.isNotEmpty) {
        if (mounted) {
          _showToast('✅ Download / Folder me successfully save ho gaya!');
        }
      }
    } catch (e) {
      debugPrint("Download error: $e");
      if (mounted) _showToast('Save cancel ya error: $e');
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Photo & Sign Resizer',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUploadCard(isDark),
                const SizedBox(height: 18),
                Text(
                  'Select Target Exam Standard',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _examPresets.map((preset) {
                      final isSelected = _selectedTargetKB == preset['kb'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTargetKB = preset['kb'];
                              _targetInputController.text = preset['kb'].toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFB45309)
                                  : (isDark ? const Color(0xFF1E1B18) : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFB45309)
                                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  preset['icon'],
                                  size: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.amber.shade300 : const Color(0xFFB45309)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${preset['label']} (<${preset['kb']}KB)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 10),
                      Text(
                        'Target Size:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _targetInputController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'e.g. 50',
                            suffixText: 'KB',
                            suffixStyle: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_imageBytes != null) _buildDownloadActionCard(isDark),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF16A34A)),
                      SizedBox(height: 16),
                      Text(
                        'Optimizing & Saving...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFB45309).withOpacity(0.25),
          width: 1.4,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickImageFromGallery,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _imageBytes != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          width: double.infinity,
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          child: Image.memory(
                            _imageBytes!,
                            cacheWidth: 500,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original: $_originalSizeKB KB',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const Text(
                            'Choose Another Photo ↺',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      )
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB45309).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library_rounded,
                          size: 34,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select Photo from Gallery',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap here to choose passport photo or signature',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadActionCard(bool isDark) {
    final targetKB = _targetInputController.text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text(
                'Target Limit: Under $targetKB KB',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Image optimize hokar seedhe aapke chune huye folder ya Downloads me save hogi.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open_rounded, size: 20),
              label: Text(
                _isProcessing ? 'Downloading...' : 'Save to File Manager / Downloads',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

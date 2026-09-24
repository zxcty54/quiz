import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  File? _originalFile;
  int _originalSizeKB = 0;
  bool _isProcessing = false;
  int _selectedTargetKB = 50;

  final TextEditingController _targetInputController =
      TextEditingController(text: '50');

  final List<Map<String, dynamic>> _examPresets = [
    {'label': 'BPSC / BSSC Sign', 'kb': 20, 'icon': Icons.draw_rounded},
    {'label': 'Bihar Govt Photo', 'kb': 50, 'icon': Icons.badge_rounded},
    {'label': 'Standard Admit/Doc', 'kb': 100, 'icon': Icons.description_rounded},
    {'label': 'Identity Proof', 'kb': 200, 'icon': Icons.fingerprint_rounded},
  ];

  static const int _maxAllowedBytes = 5 * 1024 * 1024; // 5 MB

  @override
  void initState() {
    super.initState();
    // Check if the Android Activity was previously killed while taking a photo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retrieveLostData();
    });
  }

  @override
  void dispose() {
    _targetInputController.dispose();
    super.dispose();
  }

  /// Crash recovery: Restores the file if Android killed the activity during camera capture
  Future<void> _retrieveLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;

      final file = File(response.file!.path);
      if (!await file.exists()) return;

      final bytes = await file.length();
      if (bytes <= _maxAllowedBytes && mounted) {
        setState(() {
          _originalFile = file;
          _originalSizeKB = (bytes / 1024).round();
        });
      }
    } catch (e) {
      debugPrint('Error retrieving lost camera data: $e');
    }
  }

  /// Crash-proof Pick Image: Uses native downsampling to eliminate high-megapixel OOM crashes
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        // Native constraints: resizes bitmap in native code before Dart receives it
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      final file = File(picked.path);
      final bytes = await file.length();

      // Validate 5MB limit
      if (bytes > _maxAllowedBytes) {
        final sizeMB = (bytes / (1024 * 1024)).toStringAsFixed(1);
        _showOverSizeDialog(sizeMB);
        return;
      }

      setState(() {
        _originalFile = file;
        _originalSizeKB = (bytes / 1024).round();
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) _showToast('Error selecting image: $e');
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
          'Selected image is $currentSizeMB MB.\nPlease select an image smaller than 5 MB.',
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

  /// Compression engine using binary search over JPEG quality and iterative dimension reduction
  Future<File?> _compressToTargetFile() async {
    if (_originalFile == null) return null;

    final targetKB = int.tryParse(_targetInputController.text) ?? _selectedTargetKB;
    if (targetKB < 10) {
      _showToast('Target size must be at least 10 KB');
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/exam_resize_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int minQ = 15;
    int maxQ = 95;
    int currentDim = 1200;
    Uint8List? bestBytes;

    for (int i = 0; i < 5; i++) {
      final midQ = ((minQ + maxQ) ~/ 2);

      final result = await FlutterImageCompress.compressWithFile(
        _originalFile!.path,
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
        minQ = midQ + 1; // Try pushing quality higher while staying under limit
      } else {
        maxQ = midQ - 1; // Exceeded limit; decrease quality
      }

      if (minQ > maxQ) break;
    }

    // Fallback: If quality reduction alone wasn't enough, scale down resolution dimensions
    if (bestBytes == null || (bestBytes.lengthInBytes / 1024) > targetKB) {
      while (currentDim > 300) {
        currentDim = (currentDim * 0.8).round();

        final result = await FlutterImageCompress.compressWithFile(
          _originalFile!.path,
          minWidth: currentDim,
          minHeight: currentDim,
          quality: 70,
          format: CompressFormat.jpeg,
          keepExif: false,
        );

        if (result != null && (result.lengthInBytes / 1024) <= targetKB) {
          bestBytes = result;
          break;
        }
      }
    }

    if (bestBytes != null) {
      final finalFile = File(targetPath);
      await finalFile.writeAsBytes(bestBytes, flush: true);
      return finalFile;
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (_originalFile == null || _isProcessing) return;

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final compressed = await _compressToTargetFile();
      if (compressed == null) {
        _showToast('Target size is too small for this image.');
        return;
      }

      final compressedKB = (compressed.lengthSync() / 1024).round();
      final bytes = await compressed.readAsBytes();
      final defaultName = 'Exam_Photo_${compressedKB}KB_${DateTime.now().millisecondsSinceEpoch}.jpg';

      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select destination folder:',
        fileName: defaultName,
        bytes: bytes,
        type: FileType.image,
        allowedExtensions: ['jpg', 'jpeg'],
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final savedFile = File(selectedPath);
        if (!await savedFile.exists() || await savedFile.length() == 0) {
          await savedFile.writeAsBytes(bytes, flush: true);
        }
        HapticFeedback.mediumImpact();
        _showToast('Saved successfully (${compressedKB} KB)!');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final savedFile = File('${dir.path}/$defaultName');
        await savedFile.writeAsBytes(bytes, flush: true);
        _showToast('Saved to app storage (${compressedKB} KB).');
      }
    } catch (e) {
      _showToast('Failed to save file: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleShare() async {
    if (_originalFile == null || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final compressed = await _compressToTargetFile();
      if (compressed == null) {
        _showToast('Could not reach target size.');
        return;
      }

      final compressedKB = (compressed.lengthSync() / 1024).round();
      HapticFeedback.selectionClick();
      await Share.shareXFiles(
        [XFile(compressed.path)],
        text: 'Resized via Exam Photo Tool ($compressedKB KB)',
      );
    } catch (e) {
      _showToast('Share error: $e');
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

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFB45309)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB45309)),
                title: const Text('Take Photo / Scan Sign', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
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
                if (_originalFile != null) _buildActionCard(isDark),
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
                        'Optimizing & Compressing...',
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
          onTap: _showImageSourceSheet,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _originalFile != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          width: double.infinity,
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          child: Image.file(
                            _originalFile!,
                            cacheWidth: 800, // Caps memory allocation in Flutter image cache
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Unable to preview image'),
                                ),
                              );
                            },
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
                            'Change Photo ↺',
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
                          Icons.add_photo_alternate_rounded,
                          size: 34,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload Passport Photo or Signature',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Max file size: 5 MB',
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

  Widget _buildActionCard(bool isDark) {
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
            'The image will be automatically compressed to match this target during save or share.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Save to File Manager', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _handleShare,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    foregroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
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

  // In-memory compressed bytes prevent Android memory overflow (OOM crashes)
  Uint8List? _imageBytes;
  String? _cachedFilePath;
  int _originalSizeKB = 0;
  bool _isProcessing = false;
  int _selectedTargetKB = 50;

  final TextEditingController _targetInputController =
      TextEditingController(text: '50');

  // Standard exam presets
  final List<Map<String, dynamic>> _examPresets = [
    {'label': 'BPSC / BSSC Sign', 'kb': 20, 'icon': Icons.draw_rounded},
    {'label': 'Bihar Govt Photo', 'kb': 50, 'icon': Icons.badge_rounded},
    {'label': 'Standard Admit/Doc', 'kb': 100, 'icon': Icons.description_rounded},
    {'label': 'Identity Proof', 'kb': 200, 'icon': Icons.fingerprint_rounded},
  ];

  static const int _maxAllowedBytes = 5 * 1024 * 1024; // 5 MB maximum threshold

  @override
  void initState() {
    super.initState();
    // Safely check for lost image data after the widget is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retrieveLostData();
    });
  }

  @override
  void dispose() {
    _targetInputController.dispose();
    super.dispose();
  }

  /// Crash recovery: Invoked if Android OS destroyed the Activity while camera was open
  Future<void> _retrieveLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      await _processImageSafe(response.file!.path);
    } catch (e) {
      debugPrint('Lost data recovery error: $e');
    }
  }

  /// Safely handles the raw camera/gallery path and prepares lightweight bytes
  Future<void> _processImageSafe(String rawPath) async {
    setState(() => _isProcessing = true);

    try {
      // Small pause to allow camera hardware buffer release
      await Future.delayed(const Duration(milliseconds: 300));

      final File initialFile = File(rawPath);
      if (!await initialFile.exists()) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      // Convert image directly to lightweight compressed bytes via native C++
      final Uint8List? safeBytes = await FlutterImageCompress.compressWithFile(
        rawPath,
        minWidth: 900,
        minHeight: 900,
        quality: 80,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (safeBytes == null || !mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      // Save a clean temporary working file for future compression cycles
      final tempDir = await getTemporaryDirectory();
      final safeFile = File(
          '${tempDir.path}/safe_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await safeFile.writeAsBytes(safeBytes, flush: true);

      final totalBytes = safeBytes.lengthInBytes;
      if (totalBytes > _maxAllowedBytes) {
        setState(() => _isProcessing = false);
        final sizeMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        _showOverSizeDialog(sizeMB);
        return;
      }

      setState(() {
        _imageBytes = safeBytes;
        _cachedFilePath = safeFile.path;
        _originalSizeKB = (totalBytes / 1024).round();
        _isProcessing = false;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showToast('Image processing error: $e');
      }
    }
  }

  /// Triggers Image Picker with native downsampling constraints
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (picked == null || !mounted) return;
      await _processImageSafe(picked.path);
    } catch (e) {
      if (mounted) _showToast('Camera error: $e');
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
            Text('File Size Too Large',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  /// Compresses the active file down to the target size using binary search
  Future<File?> _compressToTargetFile() async {
    if (_cachedFilePath == null) return null;

    final targetKB =
        int.tryParse(_targetInputController.text) ?? _selectedTargetKB;
    if (targetKB < 10) {
      _showToast('Target size must be at least 10 KB');
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/exam_resize_${DateTime.now().millisecondsSinceEpoch}.jpg';

    int minQ = 15;
    int maxQ = 95;
    int currentDim = 1000;
    Uint8List? bestBytes;

    for (int i = 0; i < 5; i++) {
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
      while (currentDim > 250) {
        currentDim = (currentDim * 0.8).round();

        final result = await FlutterImageCompress.compressWithFile(
          _cachedFilePath!,
          minWidth: currentDim,
          minHeight: currentDim,
          quality: 65,
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

  /// Opens dialog to customize file name before saving
  Future<String?> _showFileNameDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.drive_file_rename_outline_rounded,
                color: Color(0xFF16A34A), size: 24),
            const SizedBox(width: 8),
            Text(
              'Save As',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a file name:',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                suffixText: '.jpg',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF16A34A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF16A34A), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                final cleanName =
                    text.endsWith('.jpg') || text.endsWith('.jpeg')
                        ? text
                        : '$text.jpg';
                Navigator.pop(ctx, cleanName);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Executes target compression, prompts file name, and lets user select folder location
  Future<void> _handleSave() async {
    if (_cachedFilePath == null || _isProcessing) return;

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

      // Suggested default name
      final suggestedName =
          'Exam_${compressedKB}KB_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Prompt custom file name
      final String? finalFileName = await _showFileNameDialog(suggestedName);
      if (finalFileName == null) return; // User cancelled

      setState(() => _isProcessing = true);

      // Invoke system file picker for destination directory
      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select download folder:',
        fileName: finalFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg'],
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final savedFile = File(selectedPath);
        await savedFile.writeAsBytes(bytes, flush: true);

        HapticFeedback.mediumImpact();
        _showToast('✅ Saved to chosen folder (${compressedKB} KB)!');
      } else {
        // Direct fallback to standard device Downloads folder
        Directory? downloadDir;
        if (Platform.isAndroid) {
          downloadDir = Directory('/storage/emulated/0/Download');
        }
        downloadDir ??= await getDownloadsDirectory();

        if (downloadDir != null && await downloadDir.exists()) {
          final fallbackFile = File('${downloadDir.path}/$finalFileName');
          await fallbackFile.writeAsBytes(bytes, flush: true);

          HapticFeedback.mediumImpact();
          _showToast('✅ Saved to Downloads folder (${compressedKB} KB)!');
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final fallbackFile = File('${dir.path}/$finalFileName');
          await fallbackFile.writeAsBytes(bytes, flush: true);
          _showToast('Saved to App folder: $finalFileName');
        }
      }
    } catch (e) {
      _showToast('Failed to save file: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleShare() async {
    if (_cachedFilePath == null || _isProcessing) return;

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
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                leading: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFFB45309)),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFFB45309)),
                title: const Text('Take Photo / Scan Sign',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                              _targetInputController.text =
                                  preset['kb'].toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFB45309)
                                  : (isDark
                                      ? const Color(0xFF1E1B18)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFB45309)
                                    : (isDark
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  preset['icon'],
                                  size: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.amber.shade300
                                          : const Color(0xFFB45309)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${preset['label']} (<${preset['kb']}KB)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF1E293B)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded,
                          size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 10),
                      Text(
                        'Target Size:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF475569),
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
                            color: isDark
                                ? Colors.amber.shade300
                                : const Color(0xFFB45309),
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
                if (_imageBytes != null) _buildActionCard(isDark),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          strokeWidth: 3, color: Color(0xFF16A34A)),
                      SizedBox(height: 16),
                      Text(
                        'Optimizing & Processing...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
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
            child: _imageBytes != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          width: double.infinity,
                          color:
                              isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          // Decodes bytes safely within capped texture boundaries
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
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
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
              const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text(
                'Target Limit: Under $targetKB KB',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Compresses automatically to match target on save/share.',
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Save to File Manager',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

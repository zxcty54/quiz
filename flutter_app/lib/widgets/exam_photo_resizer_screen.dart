import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

// ============================================================================
// TOOL 1: EXAM PHOTO & SIGNATURE RESIZER (<20KB / <50KB)
// ============================================================================
class ExamPhotoResizerScreen extends StatefulWidget {
  final bool isDark;

  const ExamPhotoResizerScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<ExamPhotoResizerScreen> createState() => _ExamPhotoResizerScreenState();
}

class _ExamPhotoResizerScreenState extends State<ExamPhotoResizerScreen>
    with SingleTickerProviderStateMixin {
  File? _originalFile;
  File? _compressedFile;
  int _originalSizeKB = 0;
  int _compressedSizeKB = 0;
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

  @override
  void dispose() {
    _targetInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 92,
      );

      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.length();
      final sizeKB = (bytes / 1024).round();

      setState(() {
        _originalFile = file;
        _originalSizeKB = sizeKB;
        _compressedFile = null;
        _compressedSizeKB = 0;
      });

      _compressImage();
    } catch (e) {
      _showToast('Image pick nahi ho payi. Dobara koshish karein.');
    }
  }

  Future<void> _compressImage() async {
    if (_originalFile == null) return;

    final targetKB = int.tryParse(_targetInputController.text) ?? _selectedTargetKB;
    if (targetKB <= 5) {
      _showToast('Target size kam se kam 10 KB hona chahiye');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/resizer_${DateTime.now().millisecondsSinceEpoch}.jpg';

      int minQ = 10;
      int maxQ = 98;
      int scaleDim = 1800;
      Uint8List? bestBytes;

      for (int i = 0; i < 6; i++) {
        final midQ = ((minQ + maxQ) / 2).round();

        final result = await FlutterImageCompress.compressWithFile(
          _originalFile!.absolute.path,
          minWidth: scaleDim,
          minHeight: scaleDim,
          quality: midQ,
          format: CompressFormat.jpeg,
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
        while (scaleDim > 350) {
          scaleDim = (scaleDim * 0.85).round();

          final result = await FlutterImageCompress.compressWithFile(
            _originalFile!.absolute.path,
            minWidth: scaleDim,
            minHeight: scaleDim,
            quality: 70,
            format: CompressFormat.jpeg,
          );

          if (result != null && (result.lengthInBytes / 1024) <= targetKB) {
            bestBytes = result;
            break;
          }
        }
      }

      if (bestBytes != null) {
        final finalFile = File(targetPath);
        await finalFile.writeAsBytes(bestBytes);
        final finalKB = (finalFile.lengthSync() / 1024).round();

        if (mounted) {
          setState(() {
            _compressedFile = finalFile;
            _compressedSizeKB = finalKB;
          });
          HapticFeedback.mediumImpact();
        }
      } else {
        _showToast('Target size bohot chhota hai. Limit badhayein.');
      }
    } catch (e) {
      debugPrint("Compression Error: $e");
      _showToast('Compression me samasya aayi.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToFileManager() async {
    if (_compressedFile == null) return;
    HapticFeedback.mediumImpact();

    try {
      final bytes = await _compressedFile!.readAsBytes();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final defaultName = 'Resized_Photo_${_compressedSizeKB}KB_$stamp.jpg';

      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download folder chunein:',
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
        _showToast('✅ File Manager me successfully save ho gayi!');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final savedFile = File(path.join(dir.path, defaultName));
        await savedFile.writeAsBytes(bytes, flush: true);
        _showToast('File app directory me save ho gayi.');
      }
    } catch (e) {
      debugPrint("Save error: $e");
      _showToast('File save karne me samasya: $e');
    }
  }

  void _shareCompressedImage() {
    if (_compressedFile == null) return;
    HapticFeedback.selectionClick();
    Share.shareXFiles(
      [XFile(_compressedFile!.path)],
      text: 'Resized via Exam Photo Tool (Size: $_compressedSizeKB KB)',
    );
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
                  color: Colors.grey.withValues(alpha: 0.3),
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
      body: SingleChildScrollView(
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
                        if (_originalFile != null) _compressImage();
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
                    'Exact Limit:',
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
                      onSubmitted: (_) {
                        if (_originalFile != null) _compressImage();
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _originalFile == null || _isProcessing ? null : _compressImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB45309),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Resize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_compressedFile != null) _buildResultCard(isDark),
          ],
        ),
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
          color: const Color(0xFFB45309).withValues(alpha: 0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
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
                          constraints: const BoxConstraints(maxHeight: 180),
                          width: double.infinity,
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          child: Image.file(_originalFile!, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.image_outlined, size: 16, color: Color(0xFFB45309)),
                              const SizedBox(width: 5),
                              Text(
                                'Original: $_originalSizeKB KB',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Tap to Change ↺',
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
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB45309).withValues(alpha: 0.12),
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
                        'Auto-resizes strictly under exam portal limits',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Ready for Exam Portal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Output: $_compressedSizeKB KB',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF292524) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Original', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('$_originalSizeKB KB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                Column(
                  children: [
                    const Text('Saved Size', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      '-${(((_originalSizeKB - _compressedSizeKB) / _originalSizeKB) * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 13),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                Column(
                  children: [
                    const Text('Portal Status', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    const Text('ACCEPTED', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _saveToFileManager,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Save to File Manager',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _shareCompressedImage,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    foregroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 2: EXAM DOC & ID MERGER (INSTANT CANVAS PREVIEW + FULL-SCREEN LOADER)
// ============================================================================
class ExamDocMergerScreen extends StatefulWidget {
  final bool isDark;
  const ExamDocMergerScreen({super.key, required this.isDark});

  @override
  State<ExamDocMergerScreen> createState() => _ExamDocMergerScreenState();
}

class _DocItem {
  final String id;
  final Uint8List rawBytes;
  final img.Image original;
  Rect cropRect;
  Uint8List? croppedPreviewBytes;

  _DocItem({
    required this.id,
    required this.rawBytes,
    required this.original,
  }) : cropRect = const Rect.fromLTWH(0, 0, 1, 1);
}

enum _PageOrientation { topBottom, sideBySide }

class _ExamDocMergerScreenState extends State<ExamDocMergerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<_DocItem> _docs = [];
  bool _isProcessing = false;
  bool _enableSharpenClean = true;
  String _targetPreset = '100KB';
  String _exportFormat = 'PDF';
  _PageOrientation _orientation = _PageOrientation.topBottom;

  bool _isLoadingImages = false;
  String _loadingStatusText = 'Images load ho rahi hain...';

  Uint8List? _cachedLivePreviewBytes;
  bool _isGeneratingPreview = false;

  static const int _maxByteLimit = 5 * 1024 * 1024;
  static const int _maxImages = 4;

  static img.Image? _decodeImageIsolate(Uint8List bytes) {
    return img.decodeImage(bytes);
  }

  Future<void> _pickDocuments() async {
    final remaining = _maxImages - _docs.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aap maximum 4 images hi jod sakte hain.')),
      );
      return;
    }

    try {
      final pickedList = await _picker.pickMultiImage(
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );

      if (pickedList.isEmpty) return;

      setState(() {
        _isLoadingImages = true;
        _loadingStatusText = 'Images process ho rahi hain (0/${pickedList.length})...';
      });

      int addedCount = 0;
      for (int i = 0; i < pickedList.length; i++) {
        if (addedCount >= remaining) break;

        final xfile = pickedList[i];
        final length = await xfile.length();
        if (length > _maxByteLimit) continue;

        setState(() {
          _loadingStatusText = 'Image ${i + 1}/${pickedList.length} decode ho rahi hai...';
        });

        final bytes = await xfile.readAsBytes();
        final decoded = await compute(_decodeImageIsolate, bytes);

        if (decoded != null) {
          final item = _DocItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_$addedCount',
            rawBytes: bytes,
            original: decoded,
          );
          item.croppedPreviewBytes = _generateItemPreview(item);
          _docs.add(item);
          addedCount++;
        }
      }

      if (mounted) {
        setState(() => _isLoadingImages = false);
        _refreshFullCanvasPreview();
      }
    } catch (e) {
      debugPrint("Pick error: $e");
      if (mounted) setState(() => _isLoadingImages = false);
    }
  }

  Uint8List _generateItemPreview(_DocItem doc) {
    final cropped = _cropImage(doc, applySharpen: _enableSharpenClean);
    final scaled = img.copyResize(
      cropped,
      width: math.min(400, cropped.width),
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 80));
  }

  Future<void> _refreshFullCanvasPreview() async {
    if (_docs.isEmpty) {
      setState(() => _cachedLivePreviewBytes = null);
      return;
    }
    setState(() => _isGeneratingPreview = true);

    try {
      final composite = await Future<img.Image>(_buildMergedImage);
      final previewScaled = img.copyResize(
        composite,
        width: math.min(650, composite.width),
        interpolation: img.Interpolation.linear,
      );
      final bytes = Uint8List.fromList(img.encodeJpg(previewScaled, quality: 85));
      if (mounted) {
        setState(() {
          _cachedLivePreviewBytes = bytes;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isGeneratingPreview = false);
    }
  }

  img.Image _enhanceDocumentText(img.Image src) {
    final blurred = img.gaussianBlur(img.Image.from(src), radius: 1);
    final sharpened = img.Image.from(src);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final origPixel = src.getPixel(x, y);
        final blurPixel = blurred.getPixel(x, y);

        final r = (origPixel.r + (origPixel.r - blurPixel.r) * 1.5).clamp(0, 255);
        final g = (origPixel.g + (origPixel.g - blurPixel.g) * 1.5).clamp(0, 255);
        final b = (origPixel.b + (origPixel.b - blurPixel.b) * 1.5).clamp(0, 255);

        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        final contrastVal = lum < 145 ? (lum * 0.75).clamp(0, 255) : math.min(255, lum * 1.12);

        sharpened.setPixelRgb(x, y, contrastVal, contrastVal, contrastVal);
      }
    }
    return sharpened;
  }

  img.Image _cropImage(_DocItem doc, {bool applySharpen = true}) {
    final orig = doc.original;
    final r = doc.cropRect;

    final x = (orig.width * r.left).round().clamp(0, orig.width - 1);
    final y = (orig.height * r.top).round().clamp(0, orig.height - 1);
    final w = (orig.width * r.width).round().clamp(1, orig.width - x);
    final h = (orig.height * r.height).round().clamp(1, orig.height - y);

    var cropped = img.copyCrop(orig, x: x, y: y, width: w, height: h);

    if (applySharpen && _enableSharpenClean) {
      cropped = _enhanceDocumentText(cropped);
    }
    return cropped;
  }

  img.Image _buildMergedImage() {
    if (_docs.isEmpty) return img.Image(width: 1, height: 1);

    final croppedImages = _docs.map((d) => _cropImage(d, applySharpen: _enableSharpenClean)).toList();
    if (croppedImages.length == 1) return croppedImages.first;

    const gap = 20;
    const padding = 16;

    if (_orientation == _PageOrientation.topBottom) {
      final maxWidth = croppedImages.fold<int>(0, (prev, el) => math.max(prev, el.width));
      int totalHeight = padding * 2 + (croppedImages.length - 1) * gap;
      List<img.Image> resized = [];

      for (final imgItem in croppedImages) {
        img.Image current = imgItem;
        if (current.width != maxWidth) {
          final targetH = (current.height * (maxWidth / current.width)).round();
          current = img.copyResize(current, width: maxWidth, height: targetH, interpolation: img.Interpolation.cubic);
        }
        resized.add(current);
        totalHeight += current.height;
      }

      final canvas = img.Image(width: maxWidth + padding * 2, height: totalHeight);
      _fillWhite(canvas);

      int currentY = padding;
      for (final item in resized) {
        img.compositeImage(canvas, item, dstX: padding, dstY: currentY);
        currentY += item.height + gap;
      }
      return canvas;
    } else {
      final maxHeight = croppedImages.fold<int>(0, (prev, el) => math.max(prev, el.height));
      int totalWidth = padding * 2 + (croppedImages.length - 1) * gap;
      List<img.Image> resized = [];

      for (final imgItem in croppedImages) {
        img.Image current = imgItem;
        if (current.height != maxHeight) {
          final targetW = (current.width * (maxHeight / current.height)).round();
          current = img.copyResize(current, width: targetW, height: maxHeight, interpolation: img.Interpolation.cubic);
        }
        resized.add(current);
        totalWidth += current.width;
      }

      final canvas = img.Image(width: totalWidth, height: maxHeight + padding * 2);
      _fillWhite(canvas);

      int currentX = padding;
      for (final item in resized) {
        img.compositeImage(canvas, item, dstX: currentX, dstY: padding);
        currentX += item.width + gap;
      }
      return canvas;
    }
  }

  void _fillWhite(img.Image canvas) {
    for (final p in canvas) {
      p.r = 255;
      p.g = 255;
      p.b = 255;
      p.a = 255;
    }
  }

  void _swapDocs(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _docs.length) return;
    setState(() {
      final temp = _docs.removeAt(fromIndex);
      _docs.insert(toIndex, temp);
    });
    HapticFeedback.lightImpact();
    _refreshFullCanvasPreview();
  }

  Future<void> _openCropDialog(int index) async {
    final doc = _docs[index];
    Rect tempRect = doc.cropRect;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Row(
          children: [
            const Icon(Icons.crop_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 8),
            Text('Crop Image ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: _InteractiveCornerCropper(
            imageBytes: doc.rawBytes,
            initialCrop: doc.cropRect,
            onCropChanged: (newRect) => tempRect = newRect,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Apply Crop', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        doc.cropRect = tempRect;
        doc.croppedPreviewBytes = _generateItemPreview(doc);
      });
      _refreshFullCanvasPreview();
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _exportDocument() async {
    if (_docs.isEmpty) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final mergedImg = await Future<img.Image>(_buildMergedImage);
      final stamp = DateTime.now().millisecondsSinceEpoch;

      int targetMaxBytes = 100 * 1024;
      if (_targetPreset == '200KB') targetMaxBytes = 200 * 1024;
      if (_targetPreset == 'Original') targetMaxBytes = 10 * 1024 * 1024;

      int quality = 95;
      Uint8List compressedJpg = Uint8List.fromList(img.encodeJpg(mergedImg, quality: quality));
      img.Image workingImg = mergedImg;

      while (compressedJpg.lengthInBytes > targetMaxBytes && quality > 20) {
        quality -= 10;
        compressedJpg = Uint8List.fromList(img.encodeJpg(workingImg, quality: quality));
      }

      if (compressedJpg.lengthInBytes > targetMaxBytes && _targetPreset != 'Original') {
        final scaleDown = img.copyResize(workingImg, width: (workingImg.width * 0.75).round());
        compressedJpg = Uint8List.fromList(img.encodeJpg(scaleDown, quality: 75));
      }

      Uint8List exportBytes;
      String defaultFileName;

      if (_exportFormat == 'JPG') {
        exportBytes = compressedJpg;
        defaultFileName = 'MockTester_Doc_$stamp.jpg';
      } else {
        final pdf = pw.Document();
        final imgProvider = pw.MemoryImage(compressedJpg);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) => pw.Center(child: pw.Image(imgProvider, fit: pw.BoxFit.contain)),
          ),
        );
        exportBytes = await pdf.save();
        defaultFileName = 'MockTester_Doc_$stamp.pdf';
      }

      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download folder chunein:',
        fileName: defaultFileName,
        bytes: exportBytes,
        type: _exportFormat == 'JPG' ? FileType.image : FileType.custom,
        allowedExtensions: _exportFormat == 'JPG' ? ['jpg', 'jpeg'] : ['pdf'],
      );

      File finalFile;
      if (selectedPath != null && selectedPath.isNotEmpty) {
        finalFile = File(selectedPath);
        if (!await finalFile.exists() || await finalFile.length() == 0) {
          await finalFile.writeAsBytes(exportBytes, flush: true);
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        finalFile = File(path.join(dir.path, defaultFileName));
        await finalFile.writeAsBytes(exportBytes, flush: true);
      }

      if (!mounted) return;
      _showSuccessSheet(finalFile, exportBytes.lengthInBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessSheet(File file, int byteSize) {
    final sizeKb = (byteSize / 1024).toStringAsFixed(1);
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 12),
              const Text('Saved Successfully! 📁', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                path.basename(file.path),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Size: $sizeKb KB • File Manager me save ho gaya hai.', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Share.shareXFiles([XFile(file.path)], text: 'MockTester Saved Document');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF2563EB)),
                      label: const Text('Share File', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Done 👍', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doc & ID Merger (1-4 Images)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
            Text('Real-time Canvas Preview • Direct Downloads Save', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_docs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: 'Clear All',
              onPressed: () {
                setState(() {
                  _docs.clear();
                  _cachedLivePreviewBytes = null;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          _docs.isEmpty ? _buildEmptySelector() : _buildWorkspace(cardBg),
          if (_isLoadingImages)
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
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loadingStatusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kripya thoda intezar karein...',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _docs.isEmpty ? null : _buildExportBottomBar(),
    );
  }

  Widget _buildEmptySelector() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, size: 54, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 18),
            const Text('Documents / ID Cards Chunein', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              '1 se 4 images select karein. Live Canvas Preview ke sath direct Downloads folder me save karein.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
              label: const Text('Images Chunein (Max 4)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(Color cardBg) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: cardBg,
          child: Row(
            children: [
              Text('${_docs.length}/4 Images', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              if (_docs.length > 1) ...[
                const Text('Layout: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                SegmentedButton<_PageOrientation>(
                  segments: const [
                    ButtonSegment(
                      value: _PageOrientation.topBottom,
                      icon: Icon(Icons.view_agenda_outlined, size: 15),
                      label: Text('Top-Down', style: TextStyle(fontSize: 10)),
                    ),
                    ButtonSegment(
                      value: _PageOrientation.sideBySide,
                      icon: Icon(Icons.view_column_outlined, size: 15),
                      label: Text('Side-Side', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                  selected: {_orientation},
                  onSelectionChanged: (val) {
                    setState(() => _orientation = val.first);
                    _refreshFullCanvasPreview();
                  },
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 8),
              ],
              if (_docs.length < 4)
                IconButton(
                  onPressed: _pickDocuments,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB)),
                  tooltip: 'Add Image',
                ),
            ],
          ),
        ),

        // 👁️ LIVE COMBINED CANVAS PREVIEW
        Container(
          height: 185,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isGeneratingPreview)
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                )
              else if (_cachedLivePreviewBytes != null)
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.5,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(4),
                      color: Colors.white,
                      child: Image.memory(_cachedLivePreviewBytes!, fit: BoxFit.contain),
                    ),
                  ),
                )
              else
                const Center(child: Text('Preview taiyar ho raha hai...', style: TextStyle(color: Colors.white54, fontSize: 12))),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Live Document Preview (Zoomable)', style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _docs.length,
            itemBuilder: (ctx, idx) => _buildImageItemCard(idx, cardBg),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: cardBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Magic Clean (Text Unblur & Pure White Paper)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Switch(
                    value: _enableSharpenClean,
                    activeThumbColor: const Color(0xFF16A34A),
                    onChanged: (v) {
                      setState(() {
                        _enableSharpenClean = v;
                        for (var d in _docs) {
                          d.croppedPreviewBytes = _generateItemPreview(d);
                        }
                      });
                      _refreshFullCanvasPreview();
                    },
                  ),
                ],
              ),
              const Divider(height: 8),
              Row(
                children: [
                  const Text('Format:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'PDF', label: Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ButtonSegment(value: 'JPG', label: Text('JPG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                    selected: {_exportFormat},
                    onSelectionChanged: (val) => setState(() => _exportFormat = val.first),
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                  const Spacer(),
                  const Text('Target:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _targetPreset,
                    underline: const SizedBox(),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      DropdownMenuItem(value: '100KB', child: Text('< 100 KB')),
                      DropdownMenuItem(value: '200KB', child: Text('< 200 KB')),
                      DropdownMenuItem(value: 'Original', child: Text('Original Max')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _targetPreset = v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageItemCard(int index, Color cardBg) {
    final doc = _docs[index];
    final previewBytes = doc.croppedPreviewBytes ?? doc.rawBytes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 58,
              height: 58,
              color: Colors.black12,
              child: Image.memory(previewBytes, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      index == 0 ? 'Front Side / Page 1' : (index == 1 ? 'Back Side / Page 2' : 'Page ${index + 1}'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openCropDialog(index),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.crop_rounded, size: 13),
                      label: const Text('Crop', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => _docs.removeAt(index));
                        _refreshFullCanvasPreview();
                      },
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_docs.length > 1)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  onPressed: index > 0 ? () => _swapDocs(index, index - 1) : null,
                  tooltip: 'Move Up',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  onPressed: index < _docs.length - 1 ? () => _swapDocs(index, index + 1) : null,
                  tooltip: 'Move Down',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExportBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        color: widget.isDark ? const Color(0xFF1E1B18) : Colors.white,
        child: ElevatedButton.icon(
          onPressed: _isProcessing ? null : _exportDocument,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_for_offline_rounded, size: 20),
          label: Text(
            _isProcessing ? 'Saving to Device...' : 'Download $_exportFormat to File Manager (${_docs.length} Image${_docs.length > 1 ? "s" : ""})',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
          ),
        ),
      ),
    );
  }
}

class _InteractiveCornerCropper extends StatefulWidget {
  final Uint8List imageBytes;
  final Rect initialCrop;
  final ValueChanged<Rect> onCropChanged;

  const _InteractiveCornerCropper({
    required this.imageBytes,
    required this.initialCrop,
    required this.onCropChanged,
  });

  @override
  State<_InteractiveCornerCropper> createState() => _InteractiveCornerCropperState();
}

class _InteractiveCornerCropperState extends State<_InteractiveCornerCropper> {
  late Rect _crop;

  @override
  void initState() {
    super.initState();
    _crop = widget.initialCrop;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final pixelRect = Rect.fromLTWH(
          _crop.left * w,
          _crop.top * h,
          _crop.width * w,
          _crop.height * h,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
            ),
            CustomPaint(painter: _HoleOverlayPainter(pixelRect)),
            Positioned(
              left: pixelRect.left,
              top: pixelRect.top,
              width: pixelRect.width,
              height: pixelRect.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2563EB), width: 2),
                ),
              ),
            ),
            _buildHandle(pixelRect.left, pixelRect.top, (dx, dy) {
              setState(() {
                final newL = ((pixelRect.left + dx) / w).clamp(0.0, _crop.right - 0.1);
                final newT = ((pixelRect.top + dy) / h).clamp(0.0, _crop.bottom - 0.1);
                _crop = Rect.fromLTRB(newL, newT, _crop.right, _crop.bottom);
                widget.onCropChanged(_crop);
              });
            }),
            _buildHandle(pixelRect.right, pixelRect.top, (dx, dy) {
              setState(() {
                final newR = ((pixelRect.right + dx) / w).clamp(_crop.left + 0.1, 1.0);
                final newT = ((pixelRect.top + dy) / h).clamp(0.0, _crop.bottom - 0.1);
                _crop = Rect.fromLTRB(_crop.left, newT, newR, _crop.bottom);
                widget.onCropChanged(_crop);
              });
            }),
            _buildHandle(pixelRect.left, pixelRect.bottom, (dx, dy) {
              setState(() {
                final newL = ((pixelRect.left + dx) / w).clamp(0.0, _crop.right - 0.1);
                final newB = ((pixelRect.bottom + dy) / h).clamp(_crop.top + 0.1, 1.0);
                _crop = Rect.fromLTRB(newL, _crop.top, _crop.right, newB);
                widget.onCropChanged(_crop);
              });
            }),
            _buildHandle(pixelRect.right, pixelRect.bottom, (dx, dy) {
              setState(() {
                final newR = ((pixelRect.right + dx) / w).clamp(_crop.left + 0.1, 1.0);
                final newB = ((pixelRect.bottom + dy) / h).clamp(_crop.top + 0.1, 1.0);
                _crop = Rect.fromLTRB(_crop.left, _crop.top, newR, newB);
                widget.onCropChanged(_crop);
              });
            }),
          ],
        );
      },
    );
  }

  Widget _buildHandle(double x, double y, void Function(double dx, double dy) onDrag) {
    const size = 30.0;
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class _HoleOverlayPainter extends CustomPainter {
  final Rect hole;
  _HoleOverlayPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HoleOverlayPainter oldDelegate) => oldDelegate.hole != hole;
}

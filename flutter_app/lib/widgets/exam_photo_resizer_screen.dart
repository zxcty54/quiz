import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
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
  const ExamPhotoResizerScreen({super.key, required this.isDark});

  @override
  State<ExamPhotoResizerScreen> createState() => _ExamPhotoResizerScreenState();
}

class _ExamPhotoResizerScreenState extends State<ExamPhotoResizerScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _pickedFile;
  Uint8List? _processedBytes;
  bool _isProcessing = false;
  int _targetMaxKb = 50;
  String _selectedPreset = 'Photo (< 50 KB)';

  final Map<String, int> _presets = {
    'Signature (< 20 KB)': 20,
    'Photo (< 50 KB)': 50,
    'Document (< 100 KB)': 100,
    'High Res (< 200 KB)': 200,
  };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source);
      if (xfile == null) return;

      setState(() {
        _pickedFile = File(xfile.path);
        _processedBytes = null;
      });

      _processImage();
    } catch (e) {
      debugPrint("Picker Error: $e");
    }
  }

  Future<void> _processImage() async {
    if (_pickedFile == null) return;
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final rawBytes = await _pickedFile!.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return;

      final targetBytes = _targetMaxKb * 1024;
      int quality = 95;
      img.Image current = decoded;

      if (current.width > 1200 || current.height > 1200) {
        current = img.copyResize(current, width: 1000, interpolation: img.Interpolation.linear);
      }

      Uint8List compressed = Uint8List.fromList(img.encodeJpg(current, quality: quality));

      while (compressed.lengthInBytes > targetBytes && quality > 15) {
        quality -= 8;
        compressed = Uint8List.fromList(img.encodeJpg(current, quality: quality));
      }

      while (compressed.lengthInBytes > targetBytes && current.width > 300) {
        current = img.copyResize(current, width: (current.width * 0.85).round(), interpolation: img.Interpolation.cubic);
        compressed = Uint8List.fromList(img.encodeJpg(current, quality: 75));
      }

      if (mounted) {
        setState(() {
          _processedBytes = compressed;
        });
      }
    } catch (e) {
      debugPrint("Processing error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAndShare() async {
    if (_processedBytes == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = path.join(dir.path, 'resized_$stamp.jpg');
      final outFile = File(outPath);
      await outFile.writeAsBytes(_processedBytes!, flush: true);

      await Share.shareXFiles([XFile(outFile.path)], text: 'MockTester Resized Image');
    } catch (e) {
      debugPrint("Share error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Photo & Sign Resizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFFB45309), size: 20),
                const SizedBox(width: 10),
                const Text('Target Preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedPreset,
                  underline: const SizedBox(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  items: _presets.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedPreset = v;
                        _targetMaxKb = _presets[v]!;
                      });
                      if (_pickedFile != null) _processImage();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: _pickedFile == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text('Gallery ya Camera se Photo select karein', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                : _isProcessing
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFB45309)))
                    : Center(
                        child: Image.memory(
                          _processedBytes ?? _pickedFile!.readAsBytesSync(),
                          fit: BoxFit.contain,
                        ),
                      ),
          ),
          const SizedBox(height: 12),
          if (_processedBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Output Size: ${(_processedBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB (Target: < $_targetMaxKb KB)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_processedBytes != null)
            ElevatedButton.icon(
              onPressed: _saveAndShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Save & Share Resized Image', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 2: EXAM DOC & ID MERGER (LIVE CANVAS & DIRECT DOWNLOAD STORAGE)
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

  Uint8List? _liveMergedCanvasBytes;
  bool _isUpdatingPreview = false;

  static const int _maxByteLimit = 5 * 1024 * 1024;
  static const int _maxImages = 4;

  Future<void> _pickDocuments() async {
    final remaining = _maxImages - _docs.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aap maximum 4 images hi jod sakte hain.')),
      );
      return;
    }

    try {
      final pickedList = await _picker.pickMultiImage();
      if (pickedList.isEmpty) return;

      int addedCount = 0;
      for (final xfile in pickedList) {
        if (addedCount >= remaining) break;

        final length = await xfile.length();
        if (length > _maxByteLimit) continue;

        final bytes = await xfile.readAsBytes();
        final decoded = img.decodeImage(bytes);
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
        setState(() {});
        _rebuildFullLivePreview();
      }
    } catch (e) {
      debugPrint("Pick error: $e");
    }
  }

  Uint8List _generateItemPreview(_DocItem doc) {
    final cropped = _cropImage(doc, applySharpen: _enableSharpenClean);
    final scaled = img.copyResize(
      cropped,
      width: math.min(450, cropped.width),
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 80));
  }

  Future<void> _rebuildFullLivePreview() async {
    if (_docs.isEmpty) {
      setState(() => _liveMergedCanvasBytes = null);
      return;
    }
    setState(() => _isUpdatingPreview = true);

    try {
      final merged = await Future<img.Image>(_buildMergedImage);
      final thumb = img.copyResize(
        merged,
        width: math.min(750, merged.width),
        interpolation: img.Interpolation.linear,
      );
      final bytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 85));
      if (mounted) {
        setState(() {
          _liveMergedCanvasBytes = bytes;
          _isUpdatingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isUpdatingPreview = false);
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
    _rebuildFullLivePreview();
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
            Text(
              'Crop Image ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: _InteractiveCornerCropper(
            imageBytes: doc.rawBytes,
            initialCrop: doc.cropRect,
            onCropChanged: (newRect) {
              tempRect = newRect;
            },
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
      _rebuildFullLivePreview();
      HapticFeedback.mediumImpact();
    }
  }

  // 🚀 Guaranteed File Manager Accessible Path on Android
  Future<File> _saveDirectlyToDownloads(Uint8List bytes, String fileName) async {
    List<Directory> targetDirs = [];

    if (Platform.isAndroid) {
      // 1. Primary Public Download folder
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (publicDownload.existsSync()) targetDirs.add(publicDownload);

      // 2. External Storage Directory (App public root)
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) targetDirs.add(extDir);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    targetDirs.add(docsDir);

    for (final dir in targetDirs) {
      try {
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final f = File(path.join(dir.path, fileName));
        await f.writeAsBytes(bytes, flush: true);
        if (await f.exists() && await f.length() > 0) {
          return f;
        }
      } catch (e) {
        continue;
      }
    }
    final fallback = File(path.join(docsDir.path, fileName));
    await fallback.writeAsBytes(bytes, flush: true);
    return fallback;
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

      File exportedFile;
      if (_exportFormat == 'JPG') {
        exportedFile = await _saveDirectlyToDownloads(compressedJpg, 'MockTester_Doc_$stamp.jpg');
      } else {
        final pdf = pw.Document();
        final imgProvider = pw.MemoryImage(compressedJpg);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Image(imgProvider, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
        final pdfBytes = await pdf.save();
        exportedFile = await _saveDirectlyToDownloads(pdfBytes, 'MockTester_Doc_$stamp.pdf');
      }

      if (!mounted) return;
      _showSuccessSheet(exportedFile, compressedJpg.lengthInBytes);
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
              const Text('Document Ready & Saved! ⚡', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                path.basename(file.path),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Size: $sizeKb KB • File Location:\n${file.path}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
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
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Save copy dialog / open action
                        Share.shareXFiles([XFile(file.path)], subject: 'MockTester Document');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_done_rounded, size: 18),
                      label: const Text('Export/Save Copy', style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text('Live Canvas Preview • Direct Document Export', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                  _liveMergedCanvasBytes = null;
                });
              },
            ),
        ],
      ),
      body: _docs.isEmpty ? _buildEmptySelector() : _buildWorkspace(cardBg),
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
              '1 se 4 images select karein (ID Front/Back, Certificate, Marksheet). Screen par Live preview dekhein aur direct PDF download karein.',
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
        // 🔄 Orientation & Control Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: cardBg,
          child: Row(
            children: [
              Text(
                '${_docs.length}/4 Images',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              if (_docs.length > 1) ...[
                const Text('Orientation: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
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
                    _rebuildFullLivePreview();
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

        // 👁️ LIVE COMBINED CANVAS PREVIEW (Zoomable & Stitched)
        Container(
          height: 190,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isUpdatingPreview)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                      SizedBox(height: 8),
                      Text('Generating Live Preview...', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                )
              else if (_liveMergedCanvasBytes != null)
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.5,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
                        ],
                      ),
                      child: Image.memory(
                        _liveMergedCanvasBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              else
                const Center(
                  child: Text('Live preview ready nahi hai', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Live Output Page Preview (Zoomable)', style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ),
            ],
          ),
        ),

        // 🖼️ Reorder & Individual Crop Deck
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _docs.length,
            itemBuilder: (ctx, idx) => _buildImageItemCard(idx, cardBg),
          ),
        ),

        // ⚙️ Configurations Deck
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
                      _rebuildFullLivePreview();
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
              child: Image.memory(
                previewBytes,
                fit: BoxFit.contain,
              ),
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
                        _rebuildFullLivePreview();
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
            _isProcessing ? 'Saving to Downloads...' : 'Save $_exportFormat (${_docs.length} Image${_docs.length > 1 ? "s" : ""})',
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

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

class ExamDocMergerScreen extends StatefulWidget {
  final bool isDark;
  const ExamDocMergerScreen({super.key, required this.isDark});

  @override
  State<ExamDocMergerScreen> createState() => _ExamDocMergerScreenState();
}

class _DocImage {
  final String id;
  final Uint8List rawBytes;
  img.Image original;
  Rect cropRect;

  _DocImage({
    required this.id,
    required this.rawBytes,
    required this.original,
  }) : cropRect = const Rect.fromLTWH(0, 0, 1, 1);
}

class _ExamDocMergerScreenState extends State<ExamDocMergerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<_DocImage> _docs = [];
  int _activeCropIndex = 0;
  bool _isProcessing = false;
  bool _enableSharpenClean = true; // Magic Clean / Unblur
  String _targetPreset = '100KB'; // 100KB, 200KB, Original
  String _exportFormat = 'PDF'; // PDF, JPG

  static const int _maxByteLimit = 5 * 1024 * 1024; // 5 MB Hard Limit

  Future<void> _pickDocument({bool allowMultiple = true}) async {
    try {
      List<XFile> pickedList = [];
      if (allowMultiple) {
        pickedList = await _picker.pickMultiImage();
      } else {
        final single = await _picker.pickImage(source: ImageSource.gallery);
        if (single != null) pickedList.add(single);
      }

      if (pickedList.isEmpty) return;

      int rejectedCount = 0;
      for (final xfile in pickedList) {
        final length = await xfile.length();
        if (length > _maxByteLimit) {
          rejectedCount++;
          continue;
        }

        final bytes = await xfile.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          _docs.add(_DocImage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            rawBytes: bytes,
            original: decoded,
          ));
        }
      }

      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $rejectedCount image(s) 5MB se badi hone ke kaaran chhod di gayi.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Pick error: $e");
    }
  }

  // ⚡ Unsharp Masking & Document Contrast Filter (Text Unblur)
  img.Image _enhanceDocumentText(img.Image src) {
    final blurred = img.gaussianBlur(img.Image.from(src), radius: 1);
    final sharpened = img.Image.from(src);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final origPixel = src.getPixel(x, y);
        final blurPixel = blurred.getPixel(x, y);

        // High-pass edge sharpening
        final r = (origPixel.r + (origPixel.r - blurPixel.r) * 1.6).clamp(0, 255);
        final g = (origPixel.g + (origPixel.g - blurPixel.g) * 1.6).clamp(0, 255);
        final b = (origPixel.b + (origPixel.b - blurPixel.b) * 1.6).clamp(0, 255);

        // Contrast boost for document readability (Shadows dark, background pure white)
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        final contrastVal = lum < 145 ? (lum * 0.75).clamp(0, 255) : math.min(255, lum * 1.12);

        sharpened.setPixelRgb(x, y, contrastVal, contrastVal, contrastVal);
      }
    }
    return sharpened;
  }

  img.Image _cropImage(_DocImage doc) {
    final orig = doc.original;
    final r = doc.cropRect;

    final x = (orig.width * r.left).round().clamp(0, orig.width - 1);
    final y = (orig.height * r.top).round().clamp(0, orig.height - 1);
    final w = (orig.width * r.width).round().clamp(1, orig.width - x);
    final h = (orig.height * r.height).round().clamp(1, orig.height - y);

    var cropped = img.copyCrop(orig, x: x, y: y, width: w, height: h);

    if (_enableSharpenClean) {
      cropped = _enhanceDocumentText(cropped);
    }
    return cropped;
  }

  img.Image _buildMergedImage() {
    if (_docs.isEmpty) return img.Image(width: 1, height: 1);

    final croppedImages = _docs.map((d) => _cropImage(d)).toList();
    if (croppedImages.length == 1) return croppedImages.first;

    // Top-to-Bottom stacking (ID front & back layout)
    final maxWidth = croppedImages.fold<int>(0, (prev, el) => math.max(prev, el.width));
    const gap = 24;
    const padding = 20;

    int totalHeight = padding * 2 + (croppedImages.length - 1) * gap;
    List<img.Image> resizedImages = [];

    for (final imgItem in croppedImages) {
      img.Image current = imgItem;
      if (current.width != maxWidth) {
        final targetH = (current.height * (maxWidth / current.width)).round();
        current = img.copyResize(current, width: maxWidth, height: targetH, interpolation: img.Interpolation.cubic);
      }
      resizedImages.add(current);
      totalHeight += current.height;
    }

    final canvas = img.Image(width: maxWidth + padding * 2, height: totalHeight);
    for (final p in canvas) {
      p.r = 255;
      p.g = 255;
      p.b = 255;
      p.a = 255;
    }

    int currentY = padding;
    for (final item in resizedImages) {
      img.compositeImage(canvas, item, dstX: padding, dstY: currentY);
      currentY += item.height + gap;
    }

    return canvas;
  }

  Future<void> _exportDocument() async {
    if (_docs.isEmpty) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final mergedImg = await Future<img.Image>(_buildMergedImage);
      final directory = await getApplicationDocumentsDirectory();
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
        exportedFile = File(path.join(directory.path, 'doc_$stamp.jpg'));
        await exportedFile.writeAsBytes(compressedJpg, flush: true);
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
        exportedFile = File(path.join(directory.path, 'doc_$stamp.pdf'));
        await exportedFile.writeAsBytes(await pdf.save(), flush: true);
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
              const Text('Document Ready! ⚡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                'Size: $sizeKb KB • Format: $_exportFormat',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Share.shareXFiles([XFile(file.path)]);
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
                      child: const Text('Ho Gaya (Done)', style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text('Doc & ID Card Merger', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text('1-Doc PDF / Front & Back Merge (<100KB, <200KB)', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
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
              onPressed: () => setState(() => _docs.clear()),
            ),
        ],
      ),
      body: _docs.isEmpty ? _buildEmptySelector() : _buildEditorUI(cardBg),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, size: 54, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 18),
            const Text('Document ya ID Card Chunein', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              'Aadhaar Front+Back merge karein ya 1 photo ko direct exam PDF me badlein (Max 5MB).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(allowMultiple: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.insert_drive_file_outlined),
                    label: const Text('1 Image (Single)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickDocument(allowMultiple: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('2 Images (Merge)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorUI(Color cardBg) {
    final currentDoc = _docs[_activeCropIndex.clamp(0, _docs.length - 1)];

    return Column(
      children: [
        if (_docs.length > 1)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _docs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final active = idx == _activeCropIndex;
                return ChoiceChip(
                  label: Text(idx == 0 ? 'Front Side' : (idx == 1 ? 'Back Side' : 'Page ${idx + 1}')),
                  selected: active,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: active ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (val) => setState(() => _activeCropIndex = idx),
                );
              },
            ),
          ),

        // Interactive 4-Corner Box Cropper
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _InteractiveCornerCropper(
              key: ValueKey(currentDoc.id),
              imageBytes: currentDoc.rawBytes,
              initialCrop: currentDoc.cropRect,
              onCropChanged: (newRect) {
                currentDoc.cropRect = newRect;
              },
            ),
          ),
        ),

        // Filters & Preset Configuration Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: cardBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Magic Clean & Unblur Switch
              Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Magic Clean (Text Unblur & White Paper)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Switch(
                    value: _enableSharpenClean,
                    activeThumbColor: const Color(0xFF16A34A),
                    onChanged: (v) => setState(() => _enableSharpenClean = v),
                  ),
                ],
              ),
              const Divider(height: 10),
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
                  const Text('Size:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                      DropdownMenuItem(value: 'Original', child: Text('Max Quality')),
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
              : const Icon(Icons.download_done_rounded, size: 20),
          label: Text(
            _isProcessing ? 'Processing...' : 'Download $_exportFormat (${_docs.length > 1 ? "Merged" : "Single"})',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

/// 🎯 Advanced Touch Corner & Edge Drag Cropper
class _InteractiveCornerCropper extends StatefulWidget {
  final Uint8List imageBytes;
  final Rect initialCrop;
  final ValueChanged<Rect> onCropChanged;

  const _InteractiveCornerCropper({
    super.key,
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
            // Top-Left
            _buildHandle(pixelRect.left, pixelRect.top, (dx, dy) {
              setState(() {
                final newL = ((pixelRect.left + dx) / w).clamp(0.0, _crop.right - 0.1);
                final newT = ((pixelRect.top + dy) / h).clamp(0.0, _crop.bottom - 0.1);
                _crop = Rect.fromLTRB(newL, newT, _crop.right, _crop.bottom);
                widget.onCropChanged(_crop);
              });
            }),
            // Top-Right
            _buildHandle(pixelRect.right, pixelRect.top, (dx, dy) {
              setState(() {
                final newR = ((pixelRect.right + dx) / w).clamp(_crop.left + 0.1, 1.0);
                final newT = ((pixelRect.top + dy) / h).clamp(0.0, _crop.bottom - 0.1);
                _crop = Rect.fromLTRB(_crop.left, newT, newR, _crop.bottom);
                widget.onCropChanged(_crop);
              });
            }),
            // Bottom-Left
            _buildHandle(pixelRect.left, pixelRect.bottom, (dx, dy) {
              setState(() {
                final newL = ((pixelRect.left + dx) / w).clamp(0.0, _crop.right - 0.1);
                final newB = ((pixelRect.bottom + dy) / h).clamp(_crop.top + 0.1, 1.0);
                _crop = Rect.fromLTRB(newL, _crop.top, _crop.right, newB);
                widget.onCropChanged(_crop);
              });
            }),
            // Bottom-Right
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
    const size = 32.0;
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
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

class _ExamPhotoResizerScreenState extends State<ExamPhotoResizerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _originalFile;
  File? _compressedFile;
  int _originalSizeKB = 0;
  int _compressedSizeKB = 0;
  bool _isProcessing = false;
  bool _isLoadingFromPicker = false;
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
  void initState() {
    super.initState();
    _recoverLostCameraData();
  }

  @override
  void dispose() {
    _targetInputController.dispose();
    super.dispose();
  }

  Future<void> _recoverLostCameraData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;

      final file = File(response.file!.path);
      final bytes = await file.length();
      if (mounted) {
        setState(() {
          _originalFile = file;
          _originalSizeKB = (bytes / 1024).round();
          _compressedFile = null;
          _compressedSizeKB = 0;
        });
        _compressImage();
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isLoadingFromPicker = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (picked == null) {
        if (mounted) setState(() => _isLoadingFromPicker = false);
        return;
      }

      final file = File(picked.path);
      final bytes = await file.length();
      final sizeKB = (bytes / 1024).round();

      if (mounted) {
        setState(() {
          _originalFile = file;
          _originalSizeKB = sizeKB;
          _compressedFile = null;
          _compressedSizeKB = 0;
          _isLoadingFromPicker = false;
        });
        _compressImage();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFromPicker = false);
      _showToast('Image select nahi ho saki. Dobara try karein.');
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
      int scaleDim = 1600;
      Uint8List? bestBytes;

      // Phase 1: Binary Search on Quality (5 iterations)
      for (int i = 0; i < 6; i++) {
        final midQ = ((minQ + maxQ) / 2).round();

        final result = await FlutterImageCompress.compressWithFile(
          _originalFile!.absolute.path,
          minWidth: scaleDim,
          minHeight: scaleDim,
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

      // Phase 2: Dimensions Step-down (if file is unusually dense)
      if (bestBytes == null || (bestBytes.lengthInBytes / 1024) > targetKB) {
        while (scaleDim > 320) {
          scaleDim = (scaleDim * 0.85).round();

          final result = await FlutterImageCompress.compressWithFile(
            _originalFile!.absolute.path,
            minWidth: scaleDim,
            minHeight: scaleDim,
            quality: 75,
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
        final finalKB = (finalFile.lengthSync() / 1024).round();

        if (mounted) {
          setState(() {
            _compressedFile = finalFile;
            _compressedSizeKB = finalKB;
          });
          HapticFeedback.mediumImpact();
        }
      } else {
        _showToast('Target size bohot kam hai. Thoda badhayein.');
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
        _showToast('File app folder me save ho gayi.');
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
          if (_isLoadingFromPicker)
            Container(
              color: Colors.black45,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFB45309)),
                      SizedBox(height: 14),
                      Text('Image load ho rahi hai...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

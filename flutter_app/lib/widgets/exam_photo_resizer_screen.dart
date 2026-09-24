import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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
  State<ExamPhotoResizerScreen> createState() =>
      _ExamPhotoResizerScreenState();
}

class _ExamPhotoResizerScreenState extends State<ExamPhotoResizerScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _originalFile;
  File? _compressedFile;

  int _originalSizeKB = 0;
  int _compressedSizeKB = 0;

  bool _isProcessing = false;
  bool _isLoadingFromPicker = false;

  int _selectedTargetKB = 50;

  int _compressionRequestId = 0;

  final TextEditingController _targetInputController =
      TextEditingController(text: '50');

  final List<Map<String, dynamic>> _examPresets = [
    {
      'label': 'BPSC / BSSC Sign',
      'kb': 20,
      'icon': Icons.draw_rounded,
    },
    {
      'label': 'Bihar Govt Photo',
      'kb': 50,
      'icon': Icons.badge_rounded,
    },
    {
      'label': 'Standard Admit/Doc',
      'kb': 100,
      'icon': Icons.description_rounded,
    },
    {
      'label': 'Identity Proof',
      'kb': 200,
      'icon': Icons.fingerprint_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _recoverLostCameraData();
  }

  @override
  void dispose() {
    _compressionRequestId++;
    _targetInputController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOST CAMERA DATA
  // ------------------------------------------------------------

  Future<void> _recoverLostCameraData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();

      if (response.isEmpty || response.file == null) {
        return;
      }

      final recoveredFile = File(response.file!.path);

      if (!await recoveredFile.exists()) {
        return;
      }

      final bytes = await recoveredFile.length();

      if (bytes <= 0) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _originalFile = recoveredFile;
        _originalSizeKB = _bytesToKB(bytes);
        _compressedFile = null;
        _compressedSizeKB = 0;
      });

      // Delay by one frame so UI can render first.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        _compressImage();
      }
    } catch (e) {
      debugPrint('Lost camera data error: $e');
    }
  }

  // ------------------------------------------------------------
  // PICK IMAGE
  // ------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoadingFromPicker) return;

    setState(() {
      _isLoadingFromPicker = true;
    });

    try {
      /*
       * IMPORTANT:
       *
       * Camera:
       * Don't force very large dimensions here.
       * The camera plugin/device will provide the image,
       * and our own compression pipeline handles resizing.
       *
       * Gallery:
       * Use a reasonable max size so a 6000x4000 image doesn't
       * get unnecessarily loaded into memory at full resolution.
       */

      final XFile? picked = await _picker.pickImage(
        source: source,

        // Much safer for memory than 1600/1600 + quality 90.
        maxWidth: 2048,
        maxHeight: 2048,

        // Keep enough quality for the later compression stage.
        imageQuality: 85,
      );

      if (picked == null) {
        if (mounted) {
          setState(() {
            _isLoadingFromPicker = false;
          });
        }
        return;
      }

      final file = File(picked.path);

      if (!await file.exists()) {
        throw Exception('Selected image does not exist');
      }

      final bytes = await file.length();

      if (bytes <= 0) {
        throw Exception('Selected image is empty');
      }

      if (!mounted) return;

      setState(() {
        _originalFile = file;
        _originalSizeKB = _bytesToKB(bytes);
        _compressedFile = null;
        _compressedSizeKB = 0;
        _isLoadingFromPicker = false;
      });

      /*
       * Let Flutter render the selected image first.
       * This makes the UI feel much faster.
       */
      await Future<void>.delayed(const Duration(milliseconds: 80));

      if (mounted) {
        _compressImage();
      }
    } catch (e) {
      debugPrint('Image picker error: $e');

      if (mounted) {
        setState(() {
          _isLoadingFromPicker = false;
        });

        _showToast(
          source == ImageSource.camera
              ? 'Camera se photo nahi mil saki. Dobara try karein.'
              : 'Image select nahi ho saki. Dobara try karein.',
        );
      }
    }
  }

  // ------------------------------------------------------------
  // COMPRESSION
  // ------------------------------------------------------------

  Future<void> _compressImage() async {
    final original = _originalFile;

    if (original == null) return;

    if (!await original.exists()) {
      _showToast('Original image available nahi hai.');
      return;
    }

    int targetKB =
        int.tryParse(_targetInputController.text.trim()) ??
        _selectedTargetKB;

    if (targetKB < 10) {
      targetKB = 10;
      _targetInputController.text = '10';
    }

    final int requestId = ++_compressionRequestId;

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    HapticFeedback.lightImpact();

    try {
      final Uint8List originalBytes = await original.readAsBytes();

      if (originalBytes.isEmpty) {
        throw Exception('Image bytes empty');
      }

      /*
       * First determine a reasonable starting dimension.
       *
       * We don't need 1600px for a 20KB / 50KB exam image.
       */
      int dimension = 1600;

      if (originalBytes.lengthInBytes > 5 * 1024 * 1024) {
        dimension = 1400;
      } else if (originalBytes.lengthInBytes > 2 * 1024 * 1024) {
        dimension = 1500;
      }

      Uint8List? bestBytes;

      /*
       * --------------------------------------------------------
       * FAST PATH
       * --------------------------------------------------------
       *
       * Start with quality 75.
       * In many normal exam-photo cases this already produces
       * a usable result.
       */
      Uint8List? result = await _compress(
        original.path,
        dimension: dimension,
        quality: 75,
      );

      if (!_isCurrentRequest(requestId)) return;

      if (result != null &&
          _bytesToKB(result.lengthInBytes) <= targetKB) {
        bestBytes = result;
      }

      /*
       * --------------------------------------------------------
       * QUALITY SEARCH
       * --------------------------------------------------------
       *
       * Only run if necessary.
       * Maximum ~4 additional compressions.
       */
      if (bestBytes == null) {
        int low = 25;
        int high = 75;

        for (int i = 0; i < 4 && low <= high; i++) {
          final int quality = ((low + high) / 2).round();

          result = await _compress(
            original.path,
            dimension: dimension,
            quality: quality,
          );

          if (!_isCurrentRequest(requestId)) return;

          if (result == null) continue;

          final int currentKB = _bytesToKB(result.lengthInBytes);

          if (currentKB <= targetKB) {
            bestBytes = result;
            low = quality + 1;
          } else {
            high = quality - 1;
          }
        }
      }

      /*
       * --------------------------------------------------------
       * DIMENSION FALLBACK
       * --------------------------------------------------------
       *
       * If quality alone isn't enough, reduce dimensions.
       *
       * 1600 -> 1360 -> 1155 -> 980 -> 830 -> 700...
       *
       * This is much cheaper than blindly running many
       * compression operations.
       */
      if (bestBytes == null) {
        int currentDimension = dimension;

        for (int i = 0; i < 6; i++) {
          currentDimension = (currentDimension * 0.82).round();

          if (currentDimension < 500) {
            currentDimension = 500;
          }

          result = await _compress(
            original.path,
            dimension: currentDimension,
            quality: 70,
          );

          if (!_isCurrentRequest(requestId)) return;

          if (result == null) continue;

          final int currentKB = _bytesToKB(result.lengthInBytes);

          if (currentKB <= targetKB) {
            bestBytes = result;
            break;
          }

          if (currentDimension <= 500) {
            break;
          }
        }
      }

      if (!_isCurrentRequest(requestId)) return;

      /*
       * No result under target.
       */
      if (bestBytes == null) {
        if (mounted) {
          _showToast(
            'Target size bohot kam hai. Target size thoda badhayein.',
          );
        }
        return;
      }

      /*
       * Safety:
       * If the result is still larger than target, don't show
       * "ACCEPTED".
       */
      final int finalKB = _bytesToKB(bestBytes.lengthInBytes);

      if (finalKB > targetKB) {
        if (mounted) {
          _showToast(
            'Exact target size achieve nahi ho saka. Target thoda badhayein.',
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();

      final fileName =
          'exam_resized_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final targetPath = path.join(tempDir.path, fileName);

      final finalFile = File(targetPath);

      await finalFile.writeAsBytes(
        bestBytes,
        flush: true,
      );

      if (!_isCurrentRequest(requestId)) {
        try {
          await finalFile.delete();
        } catch (_) {}
        return;
      }

      if (mounted) {
        setState(() {
          _compressedFile = finalFile;
          _compressedSizeKB = finalKB;
        });

        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Compression Error: $e');

      if (mounted && _isCurrentRequest(requestId)) {
        _showToast('Compression me samasya aayi.');
      }
    } finally {
      if (mounted && _isCurrentRequest(requestId)) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<Uint8List?> _compress(
    String inputPath, {
    required int dimension,
    required int quality,
  }) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        inputPath,
        minWidth: dimension,
        minHeight: dimension,
        quality: quality.clamp(10, 95),
        format: CompressFormat.jpeg,
        keepExif: false,
      );
    } catch (e) {
      debugPrint(
        'Compression attempt failed '
        '(dimension=$dimension, quality=$quality): $e',
      );
      return null;
    }
  }

  bool _isCurrentRequest(int requestId) {
    return mounted && requestId == _compressionRequestId;
  }

  int _bytesToKB(int bytes) {
    if (bytes <= 0) return 0;
    return (bytes / 1024).ceil();
  }

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------

  Future<void> _saveToFileManager() async {
    final compressed = _compressedFile;

    if (compressed == null) return;

    HapticFeedback.mediumImpact();

    try {
      final bytes = await compressed.readAsBytes();

      if (bytes.isEmpty) {
        _showToast('File empty hai.');
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;

      final defaultName =
          'Resized_Photo_${_compressedSizeKB}KB_$stamp.jpg';

      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download folder chunein:',
        fileName: defaultName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg'],
      );

      if (!mounted) return;

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final savedFile = File(selectedPath);

        if (!await savedFile.exists() ||
            await savedFile.length() == 0) {
          await savedFile.writeAsBytes(
            bytes,
            flush: true,
          );
        }

        if (mounted) {
          _showToast(
            '✅ File Manager me successfully save ho gayi!',
          );
        }
      } else {
        /*
         * User cancelled the file picker.
         * Don't silently save somewhere else.
         */
        _showToast('Save cancel kar diya gaya.');
      }
    } catch (e) {
      debugPrint('Save error: $e');

      if (mounted) {
        _showToast('File save karne me samasya aayi.');
      }
    }
  }

  // ------------------------------------------------------------
  // SHARE
  // ------------------------------------------------------------

  Future<void> _shareCompressedImage() async {
    final compressed = _compressedFile;

    if (compressed == null) return;

    HapticFeedback.selectionClick();

    try {
      await Share.shareXFiles(
        [XFile(compressed.path)],
        text:
            'Resized via Exam Photo Tool '
            '(Size: $_compressedSizeKB KB)',
      );
    } catch (e) {
      debugPrint('Share error: $e');

      if (mounted) {
        _showToast('Share karne me problem aayi.');
      }
    }
  }

  // ------------------------------------------------------------
  // TOAST
  // ------------------------------------------------------------

  void _showToast(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ------------------------------------------------------------
  // SOURCE SHEET
  // ------------------------------------------------------------

  void _showImageSourceSheet() {
    if (_isLoadingFromPicker || _isProcessing) return;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          widget.isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
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
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFFB45309),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFFB45309),
                  ),
                  title: const Text(
                    'Take Photo / Scan Sign',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text(
          'Photo & Sign Resizer',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        backgroundColor:
            isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor:
            isDark ? Colors.white : const Color(0xFF0F172A),
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
                    color: isDark
                        ? Colors.white70
                        : const Color(0xFF475569),
                  ),
                ),

                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _examPresets.map((preset) {
                      final isSelected =
                          _selectedTargetKB == preset['kb'];

                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTargetKB = preset['kb'];
                              _targetInputController.text =
                                  preset['kb'].toString();
                            });

                            if (_originalFile != null) {
                              _compressImage();
                            }
                          },
                          borderRadius:
                              BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFB45309)
                                  : (isDark
                                      ? const Color(0xFF1E1B18)
                                      : Colors.white),
                              borderRadius:
                                  BorderRadius.circular(10),
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
                                    fontWeight:
                                        FontWeight.w700,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1B18)
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 10),

                      Text(
                        'Exact Limit:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: TextField(
                          controller:
                              _targetInputController,
                          keyboardType:
                              TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly,
                          ],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.amber.shade300
                                : const Color(0xFFB45309),
                          ),
                          decoration:
                              const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'e.g. 50',
                            suffixText: 'KB',
                            suffixStyle: TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          onSubmitted: (_) {
                            if (_originalFile != null &&
                                !_isProcessing) {
                              _compressImage();
                            }
                          },
                        ),
                      ),

                      ElevatedButton(
                        onPressed:
                            _originalFile == null ||
                                    _isProcessing
                                ? null
                                : _compressImage,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFB45309),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Resize',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (_compressedFile != null)
                  _buildResultCard(isDark),
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
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFFB45309),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Image load ho rahi hai...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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

  // ------------------------------------------------------------
  // UPLOAD CARD
  // ------------------------------------------------------------

  Widget _buildUploadCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1B18)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFB45309)
              .withValues(alpha: 0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.25 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ||
                  _isLoadingFromPicker
              ? null
              : _showImageSourceSheet,
          borderRadius:
              BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _originalFile != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12),
                        child: Container(
                          constraints:
                              const BoxConstraints(
                            maxHeight: 180,
                          ),
                          width: double.infinity,
                          color: isDark
                              ? Colors.black26
                              : const Color(0xFFF1F5F9),
                          child: Image.file(
                            _originalFile!,
                            fit: BoxFit.contain,
                            cacheWidth: 1000,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                size: 16,
                                color:
                                    Color(0xFFB45309),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Original: $_originalSizeKB KB',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w800,
                                  fontSize: 12,
                                  color:
                                      Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),

                          const Text(
                            'Tap to Change ↺',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      Container(
                        padding:
                            const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFB45309,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons
                              .add_photo_alternate_rounded,
                          size: 34,
                          color:
                              Color(0xFFB45309),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Upload Passport Photo or Signature',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(
                                  0xFF0F172A,
                                ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Auto-resizes strictly under exam portal limits',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white54
                              : const Color(
                                  0xFF64748B,
                                ),
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

  // ------------------------------------------------------------
  // RESULT CARD
  // ------------------------------------------------------------

  Widget _buildResultCard(bool isDark) {
    final int savedPercent =
        _originalSizeKB > 0
            ? math.max(
                0,
                (((_originalSizeKB -
                            _compressedSizeKB) /
                        _originalSizeKB) *
                    100)
                    .round(),
              )
            : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1B18)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF16A34A)
              .withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ready for Exam Portal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF16A34A,
                  ).withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(6),
                ),
                child: Text(
                  'Output: $_compressedSizeKB KB',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF292524)
                  : const Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Original',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_originalSizeKB KB',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.grey,
                ),

                Column(
                  children: [
                    const Text(
                      'Saved Size',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-$savedPercent%',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w900,
                        color:
                            Color(0xFF16A34A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.grey,
                ),

                Column(
                  children: [
                    const Text(
                      'Portal Status',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'ACCEPTED',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w900,
                        color:
                            Color(0xFF16A34A),
                        fontSize: 12,
                      ),
                    ),
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
                  onPressed:
                      _saveToFileManager,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF16A34A),
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Save to File Manager',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                flex: 2,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _shareCompressedImage,
                  style:
                      OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color:
                          Color(0xFF16A34A),
                    ),
                    foregroundColor:
                        const Color(
                      0xFF16A34A,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Share',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 12.5,
                    ),
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
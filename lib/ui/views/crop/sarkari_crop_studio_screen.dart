// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Fluid Image Pan & Zoom Viewfinder Crop Studio

import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../../../models/exam_preset_model.dart';
import '../../../services/image_resizer_engine.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';
import '../background/background_studio_screen.dart';
import '../result/sarkari_result_screen.dart';

class SarkariCropStudioScreen extends StatefulWidget {
  final File file;
  final ExamPresetModel preset;

  const SarkariCropStudioScreen({
    super.key,
    required this.file,
    required this.preset,
  });

  static Future<void> open(BuildContext context, {required File file, required ExamPresetModel preset}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SarkariCropStudioScreen(file: file, preset: preset),
      ),
    );
  }

  @override
  State<SarkariCropStudioScreen> createState() => _SarkariCropStudioScreenState();
}

class _SarkariCropStudioScreenState extends State<SarkariCropStudioScreen> {
  ui.Image? _uiImage;
  Uint8List? _rawBytes;
  bool _isLoading = true;
  bool _isProcessing = false;

  // Mode: Fixed Ratio Viewfinder vs Free Size
  bool _isFixedRatio = true;

  // Pan & Zoom values for Fixed Ratio Viewfinder
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _startPan = Offset.zero;

  // Viewport cached rects
  Rect _cachedCropBox = Rect.zero;
  Rect _cachedImageRect = Rect.zero;

  // Freeform Crop Box (Used only when _isFixedRatio == false)
  Rect _freeformRect = Rect.zero;
  int? _activeFreeformHandle;

  // DOP & Name Stamp Settings
  late bool _addNameDate;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();

  // Signature Whitening
  late bool _cleanSignature;

  // Target KB & Format
  late int _targetMinKb;
  late int _targetMaxKb;
  String _selectedFormat = 'JPG';

  @override
  void initState() {
    super.initState();
    _addNameDate = widget.preset.requiresNameDate;
    _cleanSignature = widget.preset.itemType.toLowerCase().contains('signature') ||
        widget.preset.itemType.toLowerCase().contains('thumb');
    _targetMinKb = widget.preset.minKb;
    _targetMaxKb = widget.preset.maxKb;

    _nameCtrl.text = 'NAME';
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());

    _loadImage();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _rawBytes = bytes;
          _uiImage = frame.image;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetTransform() {
    HapticFeedback.selectionClick();
    setState(() {
      _scale = 1.0;
      _panOffset = Offset.zero;
    });
  }

  void _adjustZoom(double factor) {
    HapticFeedback.selectionClick();
    setState(() {
      _scale = (_scale * factor).clamp(0.5, 5.0);
    });
  }

  /// Calculates the normalized [0.0, 1.0] crop rect of the original source image
  Rect _calculateNormalizedCrop() {
    if (_uiImage == null || _cachedCropBox == Rect.zero || _cachedImageRect == Rect.zero) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }

    final targetBox = _isFixedRatio ? _cachedCropBox : _freeformRect;

    final double normLeft = ((targetBox.left - _cachedImageRect.left) / _cachedImageRect.width).clamp(0.0, 1.0);
    final double normTop = ((targetBox.top - _cachedImageRect.top) / _cachedImageRect.height).clamp(0.0, 1.0);
    final double normW = (targetBox.width / _cachedImageRect.width).clamp(0.01, 1.0 - normLeft);
    final double normH = (targetBox.height / _cachedImageRect.height).clamp(0.01, 1.0 - normTop);

    return Rect.fromLTWH(normLeft, normTop, normW, normH);
  }

  static Uint8List _cropHighResWorker(List<dynamic> args) {
    final Uint8List rawBytes = args[0] as Uint8List;
    final Rect normCrop = args[1] as Rect;
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    final int cropX = (normCrop.left * decoded.width).round().clamp(0, decoded.width - 1);
    final int cropY = (normCrop.top * decoded.height).round().clamp(0, decoded.height - 1);
    final int cropW = (normCrop.width * decoded.width).round().clamp(10, decoded.width - cropX);
    final int cropH = (normCrop.height * decoded.height).round().clamp(10, decoded.height - cropY);
    final cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);
    return Uint8List.fromList(img.encodePng(cropped));
  }

  Future<void> _executeCrop() async {
    if (_rawBytes == null) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final normalizedCrop = _calculateNormalizedCrop();

      int targetW = widget.preset.pixelWidth;
      int targetH = widget.preset.pixelHeight;
      if (!_isFixedRatio && _uiImage != null) {
        final double cropAspect = (normalizedCrop.width * _uiImage!.width) /
            (normalizedCrop.height * _uiImage!.height);
        if (cropAspect > 0) {
          targetH = (targetW / cropAspect).round().clamp(10, 4096);
        }
      }

      final params = ResizeTaskParams(
        imageBytes: _rawBytes!,
        normalizedCropRect: normalizedCrop,
        targetWidthPx: targetW,
        targetHeightPx: targetH,
        minKb: _targetMinKb,
        maxKb: _targetMaxKb,
        addNameDate: _addNameDate,
        candidateName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        photoDate: _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
        cleanSignature: _cleanSignature,
        format: _selectedFormat,
      );

      final processedBytes = await ImageResizerEngine.instance.processExamImage(params);

      final ext = _selectedFormat.toLowerCase();
      final baseName = '${widget.preset.category}_${widget.preset.itemType}'.replaceAll(' ', '_');
      final savedFile = await SarkariStorageService.instance.saveResizedFile(
        bytes: processedBytes,
        baseName: baseName,
        extension: ext,
        examCategory: widget.preset.category,
        itemType: widget.preset.itemType,
        widthPx: widget.preset.pixelWidth,
        heightPx: widget.preset.pixelHeight,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SarkariResultScreen(
              file: savedFile,
              title: widget.preset.examName,
              examCategory: widget.preset.category,
              itemType: widget.preset.itemType,
              widthPx: widget.preset.pixelWidth,
              heightPx: widget.preset.pixelHeight,
              originalSizeBytes: _rawBytes!.length,
              dimensionString: widget.preset.dimensionSummary,
              allowedKbString: widget.preset.kbSummary,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: SarkariTheme.crimsonRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.preset.examName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              '${widget.preset.dimensionSummary} • ${widget.preset.kbSummary}',
              style: const TextStyle(fontSize: 11, color: SarkariTheme.cyanAccent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens_outlined, color: SarkariTheme.cyanAccent, size: 20),
            tooltip: 'Replace Background',
            onPressed: _isProcessing || _isLoading
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    final cropRect = _calculateNormalizedCrop();
                    // Crop at 100% full raw resolution so background removal never pixelates
                    final highResCropBytes = await Isolate.run(
                      () => _cropHighResWorker([_rawBytes!, cropRect]),
                    );
                    if (!context.mounted) return;
                    setState(() => _isProcessing = false);
                    BackgroundStudioScreen.open(context, bytes: highResCropBytes);
                  },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: FilledButton(
              onPressed: _isProcessing || _isLoading ? null : _executeCrop,
              style: FilledButton.styleFrom(
                backgroundColor: SarkariTheme.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Export', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SarkariTheme.cyanAccent))
          : Column(
              children: [
                // Top Control Bar: Mode Toggle & Zoom Controls
                Container(
                  color: SarkariTheme.surfaceCard,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Mode Selector Pill
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: SarkariTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SarkariTheme.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeTab('Fixed Ratio', _isFixedRatio, () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isFixedRatio = true;
                                _resetTransform();
                              });
                            }),
                            _buildModeTab('Free Size', !_isFixedRatio, () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isFixedRatio = false;
                                if (_cachedCropBox != Rect.zero) {
                                  _freeformRect = _cachedCropBox;
                                }
                              });
                            }),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, color: SarkariTheme.textSecondary, size: 20),
                        onPressed: () => _adjustZoom(0.85),
                        tooltip: 'Zoom Out',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: SarkariTheme.textSecondary, size: 20),
                        onPressed: () => _adjustZoom(1.15),
                        tooltip: 'Zoom In',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.center_focus_strong_rounded, color: SarkariTheme.cyanAccent, size: 20),
                        onPressed: _resetTransform,
                        tooltip: 'Center Image',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Fluid Image Pan & Zoom Viewport
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final double screenW = constraints.maxWidth;
                      final double screenH = constraints.maxHeight;

                      // 1. Calculate the Fixed Center Crop Window
                      final double targetAspect = widget.preset.aspectRatio;
                      final double maxBoxW = screenW * 0.82;
                      final double maxBoxH = screenH * 0.82;

                      double boxW, boxH;
                      if (targetAspect > (maxBoxW / maxBoxH)) {
                        boxW = maxBoxW;
                        boxH = boxW / targetAspect;
                      } else {
                        boxH = maxBoxH;
                        boxW = boxH * targetAspect;
                      }

                      final centerCropBox = Rect.fromCenter(
                        center: Offset(screenW / 2, screenH / 2),
                        width: boxW,
                        height: boxH,
                      );
                      _cachedCropBox = centerCropBox;

                      if (_freeformRect == Rect.zero) {
                        _freeformRect = centerCropBox;
                      }

                      // 2. Base Image Dimensions: sized to cover the crop box comfortably
                      final double imgAspect = _uiImage!.width / _uiImage!.height;
                      double baseW, baseH;
                      if (imgAspect > targetAspect) {
                        baseH = centerCropBox.height;
                        baseW = baseH * imgAspect;
                      } else {
                        baseW = centerCropBox.width;
                        baseH = baseW / imgAspect;
                      }

                      // Apply current zoom and pan offset
                      final double currentW = baseW * _scale;
                      final double currentH = baseH * _scale;
                      final Offset currentCenter = centerCropBox.center + _panOffset;
                      final Rect currentImageRect = Rect.fromCenter(
                        center: currentCenter,
                        width: currentW,
                        height: currentH,
                      );
                      _cachedImageRect = currentImageRect;

                      final activeBox = _isFixedRatio ? centerCropBox : _freeformRect;

                      return GestureDetector(
                        onScaleStart: (details) {
                          _baseScale = _scale;
                          _startPan = details.focalPoint - _panOffset;
                          if (!_isFixedRatio) {
                            // Check corner hit for freeform resize
                            const hit = 36.0;
                            final pos = details.localFocalPoint;
                            if ((pos - _freeformRect.topLeft).distance <= hit) {
                              _activeFreeformHandle = 0;
                            } else if ((pos - _freeformRect.topRight).distance <= hit) {
                              _activeFreeformHandle = 1;
                            } else if ((pos - _freeformRect.bottomRight).distance <= hit) {
                              _activeFreeformHandle = 2;
                            } else if ((pos - _freeformRect.bottomLeft).distance <= hit) {
                              _activeFreeformHandle = 3;
                            } else {
                              _activeFreeformHandle = null;
                            }
                          }
                        },
                        onScaleUpdate: (details) {
                          if (!_isFixedRatio && _activeFreeformHandle != null) {
                            // Freeform handle resize
                            final pos = details.localFocalPoint;
                            setState(() {
                              double l = _freeformRect.left;
                              double t = _freeformRect.top;
                              double r = _freeformRect.right;
                              double b = _freeformRect.bottom;

                              if (_activeFreeformHandle == 0) {
                                l = pos.dx.clamp(0.0, r - 40);
                                t = pos.dy.clamp(0.0, b - 40);
                              } else if (_activeFreeformHandle == 1) {
                                r = pos.dx.clamp(l + 40, screenW);
                                t = pos.dy.clamp(0.0, b - 40);
                              } else if (_activeFreeformHandle == 2) {
                                r = pos.dx.clamp(l + 40, screenW);
                                b = pos.dy.clamp(t + 40, screenH);
                              } else if (_activeFreeformHandle == 3) {
                                l = pos.dx.clamp(0.0, r - 40);
                                b = pos.dy.clamp(t + 40, screenH);
                              }
                              _freeformRect = Rect.fromLTRB(l, t, r, b);
                            });
                          } else {
                            // Fluid Image Pan & Pinch-Zoom
                            setState(() {
                              _scale = (_baseScale * details.scale).clamp(0.5, 6.0);
                              _panOffset = details.focalPoint - _startPan;
                            });
                          }
                        },
                        onScaleEnd: (_) {
                          _activeFreeformHandle = null;
                        },
                        child: CustomPaint(
                          size: Size(screenW, screenH),
                          painter: _FluidCropPainter(
                            image: _uiImage!,
                            imageRect: currentImageRect,
                            cropBox: activeBox,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Configuration Dock
                Container(
                  color: SarkariTheme.surfaceCard,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date & Name Banner (DOP) Strip
                      if (widget.preset.requiresNameDate || !widget.preset.itemType.toLowerCase().contains('signature')) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: _addNameDate,
                              activeColor: SarkariTheme.cyanAccent,
                              checkColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) => setState(() => _addNameDate = v ?? false),
                            ),
                            const Text(
                              'Date & Name Banner',
                              style: TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        if (_addNameDate) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  style: const TextStyle(color: SarkariTheme.textPrimary, fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Candidate Name',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _dateCtrl,
                                  style: const TextStyle(color: SarkariTheme.textPrimary, fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Date (DD/MM/YYYY)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],

                      // Signature Paper Whitener
                      if (widget.preset.itemType.toLowerCase().contains('signature') ||
                          widget.preset.itemType.toLowerCase().contains('thumb')) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: _cleanSignature,
                              activeColor: SarkariTheme.cyanAccent,
                              checkColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) => setState(() => _cleanSignature = v ?? false),
                            ),
                            const Text(
                              'Clean Paper Background to White',
                              style: TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Format & Limit
                      Row(
                        children: [
                          const Text('Format', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 12)),
                          const SizedBox(width: 8),
                          Row(
                            children: ['JPG', 'PNG', 'PDF'].map((fmt) {
                              final isSel = _selectedFormat == fmt;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => setState(() => _selectedFormat = fmt),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceElevated,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceBorder,
                                      ),
                                    ),
                                    child: Text(
                                      fmt,
                                      style: TextStyle(
                                        color: isSel ? Colors.black : SarkariTheme.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const Spacer(),
                          Text(
                            'Limit: $_targetMinKb - $_targetMaxKb KB',
                            style: const TextStyle(color: SarkariTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModeTab(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? SarkariTheme.surfaceBorder : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? SarkariTheme.cyanAccent : SarkariTheme.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FluidCropPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final Rect cropBox;

  _FluidCropPainter({
    required this.image,
    required this.imageRect,
    required this.cropBox,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Panned & Zoomed Image
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, srcRect, imageRect, Paint()..filterQuality = FilterQuality.high);

    // 2. Dim Outside Mask
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final maskPath = Path.combine(PathOperation.difference, Path()..addRect(fullRect), Path()..addRect(cropBox));
    canvas.drawPath(maskPath, Paint()..color = Colors.black.withAlpha(190));

    // 3. Grid Lines (Rule of Thirds inside Crop Box)
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final stepX = cropBox.width / 3;
    final stepY = cropBox.height / 3;
    canvas.drawLine(Offset(cropBox.left + stepX, cropBox.top), Offset(cropBox.left + stepX, cropBox.bottom), gridPaint);
    canvas.drawLine(Offset(cropBox.left + stepX * 2, cropBox.top), Offset(cropBox.left + stepX * 2, cropBox.bottom), gridPaint);
    canvas.drawLine(Offset(cropBox.left, cropBox.top + stepY), Offset(cropBox.right, cropBox.top + stepY), gridPaint);
    canvas.drawLine(Offset(cropBox.left, cropBox.top + stepY * 2), Offset(cropBox.right, cropBox.top + stepY * 2), gridPaint);

    // 4. Crop Box Border (Hairline Cyan)
    final borderPaint = Paint()
      ..color = SarkariTheme.cyanAccent.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropBox, borderPaint);

    // 5. Four Precision Corner Brackets (Matching App Icon Design)
    final cornerPaint = Paint()
      ..color = SarkariTheme.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const len = 22.0;
    // TL
    canvas.drawLine(cropBox.topLeft, cropBox.topLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(cropBox.topLeft, cropBox.topLeft + const Offset(0, len), cornerPaint);
    // TR
    canvas.drawLine(cropBox.topRight, cropBox.topRight - const Offset(len, 0), cornerPaint);
    canvas.drawLine(cropBox.topRight, cropBox.topRight + const Offset(0, len), cornerPaint);
    // BR
    canvas.drawLine(cropBox.bottomRight, cropBox.bottomRight - const Offset(len, 0), cornerPaint);
    canvas.drawLine(cropBox.bottomRight, cropBox.bottomRight - const Offset(0, len), cornerPaint);
    // BL
    canvas.drawLine(cropBox.bottomLeft, cropBox.bottomLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(cropBox.bottomLeft, cropBox.bottomLeft - const Offset(0, len), cornerPaint);

    // Anchor Dots
    final dotPaint = Paint()..color = SarkariTheme.cyanAccent;
    const dotR = 3.5;
    canvas.drawCircle(cropBox.topLeft, dotR, dotPaint);
    canvas.drawCircle(cropBox.topRight, dotR, dotPaint);
    canvas.drawCircle(cropBox.bottomRight, dotR, dotPaint);
    canvas.drawCircle(cropBox.bottomLeft, dotR, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _FluidCropPainter oldDelegate) => true;
}

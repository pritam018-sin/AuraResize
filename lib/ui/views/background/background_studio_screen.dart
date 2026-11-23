// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - AI Portrait Background Removal & Color Replacement Studio
// Hybrid Engine: Built-in RemBG Cloud HD with Automatic On-Device U-2-Net Fallback

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/rembg_api_service.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../services/u2net_background_remover.dart';
import '../../../theme/sarkari_theme.dart';
import '../../widgets/action_pipeline_ribbon.dart';
import '../result/sarkari_result_screen.dart';

class BackgroundStudioScreen extends StatefulWidget {
  final File? initialFile;
  final Uint8List? initialBytes;

  const BackgroundStudioScreen({
    super.key,
    this.initialFile,
    this.initialBytes,
  });

  static Future<void> open(BuildContext context, {File? file, Uint8List? bytes}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackgroundStudioScreen(
          initialFile: file,
          initialBytes: bytes,
        ),
      ),
    );
  }

  @override
  State<BackgroundStudioScreen> createState() => _BackgroundStudioScreenState();
}

class _BackgroundStudioScreenState extends State<BackgroundStudioScreen> {
  Uint8List? _sourceBytes;
  Uint8List? _processedBytes;
  bool _isProcessing = false;
  bool _showOriginal = false;

  // Selected Background Color
  Color _selectedBgColor = Colors.white;
  double _feather = 0.12;
  double _threshold = 0.52;
  bool _refineHair = true;

  // Engine Status
  bool _isCloudResult = false;
  String? _engineStatus;

  final List<_BgSwatch> _swatches = [
    _BgSwatch(label: 'Pure White', color: Colors.white, desc: 'Passport / Official'),
    _BgSwatch(label: 'Light Blue', color: const Color(0xFF93C5FD), desc: 'Passport Seva'),
    _BgSwatch(label: 'Off-White', color: const Color(0xFFF1F5F9), desc: 'Studio Standard'),
    _BgSwatch(label: 'Navy Blue', color: const Color(0xFF1E3A8A), desc: 'Corporate ID'),
    _BgSwatch(label: 'Dark Grey', color: const Color(0xFF334155), desc: 'Neutral Grey'),
    _BgSwatch(label: 'Transparent', color: Colors.transparent, desc: 'PNG Cutout'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null) {
      _sourceBytes = widget.initialBytes;
      _processBackground();
    } else if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  Future<void> _loadFile(File f) async {
    final b = await f.readAsBytes();
    if (mounted) {
      setState(() {
        _sourceBytes = b;
      });
      _processBackground();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null && mounted) {
      _loadFile(File(picked.path));
    }
  }

  Future<void> _processBackground() async {
    if (_sourceBytes == null) return;
    setState(() => _isProcessing = true);

    // 1. Seamless Cloud Attempt (RemBG Cloud API via built-in configuration)
    try {
      final cloudBytes = await RembgApiService.instance.removeBackground(
        bytes: _sourceBytes!,
        targetColor: _selectedBgColor,
      );

      if (cloudBytes != null) {
        if (mounted) {
          setState(() {
            _processedBytes = cloudBytes;
            _isCloudResult = true;
            _engineStatus = 'RemBG HD';
            _isProcessing = false;
          });
        }
        return;
      }
    } catch (_) {
      // Seamlessly fall back
    }

    // 2. On-Device U-2-Net Processing (When offline or quota exhausted)
    try {
      final offlineBytes = await U2NetBackgroundRemover.instance.removeBackground(
        bytes: _sourceBytes!,
        targetColor: _selectedBgColor,
        threshold: _threshold,
        feather: _feather,
        refineHair: _refineHair,
      );

      if (mounted) {
        setState(() {
          _processedBytes = offlineBytes;
          _isCloudResult = false;
          _engineStatus = 'On-Device AI';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing error: $e'),
            backgroundColor: SarkariTheme.crimsonRed,
          ),
        );
      }
    }
  }

  Future<void> _exportResult() async {
    if (_processedBytes == null) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final isTrans = (_selectedBgColor.a * 255.0).round() == 0;
    final ext = isTrans ? 'png' : 'jpg';

    final saved = await SarkariStorageService.instance.saveResizedFile(
      bytes: _processedBytes!,
      baseName: 'BG_Replaced',
      extension: ext,
      examCategory: 'Background',
      itemType: isTrans ? 'Transparent Cutout' : 'Color Background',
      widthPx: 0,
      heightPx: 0,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SarkariResultScreen(
            file: saved,
            title: 'Background Output',
            examCategory: 'Background Studio',
            itemType: isTrans ? 'Transparent PNG' : 'Replaced Color',
            widthPx: 0,
            heightPx: 0,
            originalSizeBytes: _sourceBytes!.length,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTrans = (_selectedBgColor.a * 255.0).round() == 0;

    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Background Studio'),
        actions: [
          if (_processedBytes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: FilledButton(
                onPressed: _isProcessing ? null : _exportResult,
                style: FilledButton.styleFrom(
                  backgroundColor: SarkariTheme.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Export', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Interactive Preview Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                if (_sourceBytes != null) ...[
                  Stack(
                    children: [
                      Container(
                        height: 280,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isTrans ? Colors.transparent : _selectedBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SarkariTheme.surfaceBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (isTrans)
                                CustomPaint(
                                  painter: _CheckerboardPainter(),
                                ),
                              InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Center(
                                  child: Image.memory(
                                    _showOriginal
                                        ? _sourceBytes!
                                        : (_processedBytes ?? _sourceBytes!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Subtle Engine Status Pill (Top-Right)
                      if (_engineStatus != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(200),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isCloudResult ? const Color(0xFF10B981) : SarkariTheme.cyanAccent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isCloudResult ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
                                  size: 12,
                                  color: _isCloudResult ? const Color(0xFF10B981) : SarkariTheme.cyanAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _engineStatus!,
                                  style: TextStyle(
                                    color: _isCloudResult ? const Color(0xFF10B981) : SarkariTheme.cyanAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_isProcessing)
                        Container(
                          height: 280,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(170),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: SarkariTheme.cyanAccent, strokeWidth: 2.5),
                                SizedBox(height: 12),
                                Text(
                                  'Processing Portrait...',
                                  style: TextStyle(color: SarkariTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SarkariTheme.textPrimary,
                          side: const BorderSide(color: SarkariTheme.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 14),
                        label: const Text('Change Photo', style: TextStyle(fontSize: 11)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTapDown: (_) => setState(() => _showOriginal = true),
                        onTapUp: (_) => setState(() => _showOriginal = false),
                        onTapCancel: () => setState(() => _showOriginal = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: SarkariTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: SarkariTheme.surfaceBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.compare_arrows_rounded, color: SarkariTheme.cyanAccent, size: 14),
                              SizedBox(width: 4),
                              Text('Hold for Original', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: SarkariTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SarkariTheme.surfaceBorder),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: SarkariTheme.cyanAccent, size: 36),
                            SizedBox(height: 8),
                            Text(
                              'Select Portrait to Remove Background',
                              style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Background Color Swatches
          const Text(
            'BACKGROUND COLOR',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _swatches.map((swatch) {
                final isSel = _selectedBgColor == swatch.color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBgColor = swatch.color);
                      _processBackground();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: SarkariTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceBorder,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: swatch.color == Colors.transparent ? Colors.grey[800] : swatch.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: swatch.color == Colors.transparent
                                ? const Icon(Icons.block_rounded, size: 10, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            swatch.label,
                            style: TextStyle(
                              color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
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
          const SizedBox(height: 14),

          // 3. Edge Controls: Hair Matting, Smoothing & Cutout Tightness
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hair Refinement Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REFINE HAIR & DECONTAMINATE',
                          style: TextStyle(color: SarkariTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                        ),
                        Text(
                          'Eliminates color halo and preserves fine strands',
                          style: TextStyle(color: SarkariTheme.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                    Switch(
                      value: _refineHair,
                      activeColor: SarkariTheme.cyanAccent,
                      onChanged: (v) {
                        setState(() => _refineHair = v);
                        _processBackground();
                      },
                    ),
                  ],
                ),
                const Divider(color: SarkariTheme.surfaceBorder, height: 20),

                // Edge Smoothing Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('EDGE SMOOTHING', style: TextStyle(color: SarkariTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    Text('${(_feather * 100).toInt()}%', style: const TextStyle(color: SarkariTheme.cyanAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: SarkariTheme.cyanAccent,
                    inactiveTrackColor: SarkariTheme.surfaceElevated,
                    thumbColor: SarkariTheme.cyanAccent,
                    overlayColor: SarkariTheme.cyanAccent.withAlpha(30),
                  ),
                  child: Slider(
                    value: _feather,
                    min: 0.04,
                    max: 0.28,
                    onChanged: (v) {
                      setState(() => _feather = v);
                    },
                    onChangeEnd: (_) => _processBackground(),
                  ),
                ),
                const SizedBox(height: 6),

                // Cutout Tightness Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CUTOUT TIGHTNESS', style: TextStyle(color: SarkariTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    Text('${(_threshold * 100).toInt()}%', style: const TextStyle(color: SarkariTheme.cyanAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: SarkariTheme.cyanAccent,
                    inactiveTrackColor: SarkariTheme.surfaceElevated,
                    thumbColor: SarkariTheme.cyanAccent,
                    overlayColor: SarkariTheme.cyanAccent.withAlpha(30),
                  ),
                  child: Slider(
                    value: _threshold,
                    min: 0.35,
                    max: 0.70,
                    onChanged: (v) {
                      setState(() => _threshold = v);
                    },
                    onChangeEnd: (_) => _processBackground(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Chained Action Pipeline Ribbon
          if (_processedBytes != null) ...[
            ActionPipelineRibbon(
              imageBytes: _processedBytes!,
              activeTool: 'bg',
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _BgSwatch {
  final String label;
  final Color color;
  final String desc;
  const _BgSwatch({required this.label, required this.color, required this.desc});
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double sq = 12.0;
    final paint1 = Paint()..color = const Color(0xFF1E293B);
    final paint2 = Paint()..color = const Color(0xFF0F172A);
    for (double y = 0; y < size.height; y += sq) {
      for (double x = 0; x < size.width; x += sq) {
        final isEven = ((x / sq).floor() + (y / sq).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, sq, sq), isEven ? paint1 : paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

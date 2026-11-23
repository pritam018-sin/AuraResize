// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist Target KB Compressor

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/image_resizer_engine.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';
import '../../widgets/action_pipeline_ribbon.dart';
import '../result/sarkari_result_screen.dart';

class TargetKbCompressorScreen extends StatefulWidget {
  final File? initialFile;

  const TargetKbCompressorScreen({super.key, this.initialFile});

  static Future<void> open(BuildContext context, {File? file}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TargetKbCompressorScreen(initialFile: file),
      ),
    );
  }

  @override
  State<TargetKbCompressorScreen> createState() => _TargetKbCompressorScreenState();
}

class _TargetKbCompressorScreenState extends State<TargetKbCompressorScreen> {
  File? _file;
  Uint8List? _rawBytes;
  int _targetKb = 45;
  bool _isCompressing = false;
  final TextEditingController _targetCtrl = TextEditingController(text: '45');

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFile(File f) async {
    final bytes = await f.readAsBytes();
    if (mounted) {
      setState(() {
        _file = f;
        _rawBytes = bytes;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null && mounted) {
      _loadFile(File(picked.path));
    }
  }

  Future<void> _executeCompression() async {
    if (_rawBytes == null || _file == null) return;
    setState(() => _isCompressing = true);
    HapticFeedback.mediumImpact();

    try {
      final compressedBytes = ImageResizerEngine.instance.compressImageToTargetKb(
        _rawBytes!,
        _targetKb,
      );

      final savedFile = await SarkariStorageService.instance.saveResizedFile(
        bytes: compressedBytes,
        baseName: 'Compressed_${_targetKb}KB',
        extension: 'jpg',
        examCategory: 'Compressor',
        itemType: '${_targetKb}KB Target',
        widthPx: 0,
        heightPx: 0,
      );

      if (mounted) {
        setState(() => _isCompressing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SarkariResultScreen(
              file: savedFile,
              title: 'Target Size Output',
              examCategory: 'Compression',
              itemType: 'Target $_targetKb KB',
              widthPx: 0,
              heightPx: 0,
              originalSizeBytes: _rawBytes!.length,
              allowedKbString: 'Max $_targetKb KB',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompressing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: SarkariTheme.crimsonRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final origKb = _rawBytes != null ? (_rawBytes!.length / 1024).toStringAsFixed(1) : null;

    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Target File Size'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Image Preview & Selector Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                if (_file != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_file!, height: 160, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Original Size: $origKb KB',
                    style: const TextStyle(color: SarkariTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SarkariTheme.textPrimary,
                          side: const BorderSide(color: SarkariTheme.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Change', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: SarkariTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SarkariTheme.surfaceBorder),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: SarkariTheme.cyanAccent, size: 28),
                            SizedBox(height: 6),
                            Text(
                              'Tap to Select Image',
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

          // 2. Preset Limits
          const Text('COMMON LIMITS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKbPill(20),
                _buildKbPill(50),
                _buildKbPill(100),
                _buildKbPill(200),
                _buildKbPill(500),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Target Input & Slider
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TARGET FILE SIZE', style: TextStyle(color: SarkariTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SarkariTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: SarkariTheme.cyanAccent.withAlpha(100)),
                      ),
                      child: Text(
                        '$_targetKb KB',
                        style: const TextStyle(color: SarkariTheme.cyanAccent, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: SarkariTheme.cyanAccent,
                    inactiveTrackColor: SarkariTheme.surfaceElevated,
                    thumbColor: SarkariTheme.cyanAccent,
                    overlayColor: SarkariTheme.cyanAccent.withAlpha(30),
                  ),
                  child: Slider(
                    value: _targetKb.toDouble().clamp(10, 1000),
                    min: 10,
                    max: 1000,
                    divisions: 99,
                    onChanged: (v) {
                      setState(() {
                        _targetKb = v.toInt();
                        _targetCtrl.text = _targetKb.toString();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Exact KB:', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _targetCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                        decoration: const InputDecoration(suffixText: 'KB', isDense: true),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed >= 5 && parsed <= 5000) {
                            setState(() => _targetKb = parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Compress Action Button
          FilledButton(
            onPressed: _isCompressing || _rawBytes == null ? null : _executeCompression,
            style: FilledButton.styleFrom(
              backgroundColor: SarkariTheme.cyanAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isCompressing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text('Compress to $_targetKb KB', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (_rawBytes != null) ...[
            const SizedBox(height: 16),
            ActionPipelineRibbon(
              imageBytes: _rawBytes!,
              activeTool: 'compress',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKbPill(int kb) {
    final isSel = _targetKb == kb;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _targetKb = kb;
            _targetCtrl.text = kb.toString();
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceBorder),
          ),
          child: Text(
            '$kb KB',
            style: TextStyle(
              color: isSel ? Colors.black : SarkariTheme.textSecondary,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

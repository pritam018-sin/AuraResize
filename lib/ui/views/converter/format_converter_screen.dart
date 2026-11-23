// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist Format Converter Studio

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/image_resizer_engine.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';
import '../../widgets/action_pipeline_ribbon.dart';
import '../result/sarkari_result_screen.dart';

class FormatConverterScreen extends StatefulWidget {
  final File? initialFile;

  const FormatConverterScreen({super.key, this.initialFile});

  static Future<void> open(BuildContext context, {File? file}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormatConverterScreen(initialFile: file),
      ),
    );
  }

  @override
  State<FormatConverterScreen> createState() => _FormatConverterScreenState();
}

class _FormatConverterScreenState extends State<FormatConverterScreen> {
  File? _file;
  Uint8List? _rawBytes;
  String _targetFormat = 'JPG';
  int _quality = 92;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
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

  String get _currentExtension {
    if (_file == null) return '';
    return _file!.path.split('.').last.toUpperCase();
  }

  Future<void> _executeConvert() async {
    if (_rawBytes == null || _file == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an image first')));
      return;
    }

    setState(() => _isConverting = true);
    HapticFeedback.mediumImpact();

    try {
      final convertedBytes = await ImageResizerEngine.instance.convertImageFormat(
        _rawBytes!,
        _targetFormat,
        quality: _quality,
      );

      final savedFile = await SarkariStorageService.instance.saveResizedFile(
        bytes: convertedBytes,
        baseName: 'Converted_$_targetFormat',
        extension: _targetFormat.toLowerCase(),
        examCategory: 'Converter',
        itemType: '$_currentExtension to $_targetFormat',
        widthPx: 0,
        heightPx: 0,
      );

      if (mounted) {
        setState(() => _isConverting = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SarkariResultScreen(
              file: savedFile,
              title: 'Converted Output',
              examCategory: 'Format',
              itemType: '$_targetFormat Document',
              widthPx: 0,
              heightPx: 0,
              originalSizeBytes: _rawBytes!.length,
              allowedKbString: 'Quality: $_quality%',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
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
        title: const Text('Format Converter'),
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
                    'Source Format: $_currentExtension • ${(_rawBytes!.length / 1024).toStringAsFixed(1)} KB',
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
          const SizedBox(height: 16),

          // 2. Output Format Selector
          const Text('OUTPUT FORMAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 8),

          _buildFormatTile(
            format: 'JPG',
            title: 'JPG / JPEG',
            desc: 'Standard compressed format for official portals and uploads',
          ),
          const SizedBox(height: 8),

          _buildFormatTile(
            format: 'PDF',
            title: 'Single-Page PDF',
            desc: 'Clean document container for certificates and records',
          ),
          const SizedBox(height: 8),

          _buildFormatTile(
            format: 'PNG',
            title: 'PNG',
            desc: 'Lossless graphic format with high fidelity',
          ),
          const SizedBox(height: 14),

          // 3. Quality Slider (if JPG/PDF)
          if (_targetFormat != 'PNG')
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
                      const Text('COMPRESSION QUALITY', style: TextStyle(color: SarkariTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      Text('$_quality%', style: const TextStyle(color: SarkariTheme.cyanAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: SarkariTheme.cyanAccent,
                      inactiveTrackColor: SarkariTheme.surfaceElevated,
                      thumbColor: SarkariTheme.cyanAccent,
                      overlayColor: SarkariTheme.cyanAccent.withAlpha(30),
                    ),
                    child: Slider(
                      value: _quality.toDouble(),
                      min: 40,
                      max: 100,
                      onChanged: (v) => setState(() => _quality = v.toInt()),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // 4. Action Button
          FilledButton(
            onPressed: _isConverting || _rawBytes == null ? null : _executeConvert,
            style: FilledButton.styleFrom(
              backgroundColor: SarkariTheme.cyanAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isConverting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text('Convert to $_targetFormat', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (_rawBytes != null) ...[
            const SizedBox(height: 16),
            ActionPipelineRibbon(
              imageBytes: _rawBytes!,
              activeTool: 'format',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatTile({
    required String format,
    required String title,
    required String desc,
  }) {
    final isSel = _targetFormat == format;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _targetFormat = format);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? SarkariTheme.surfaceElevated : SarkariTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceBorder,
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.textMuted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSel ? SarkariTheme.textPrimary : SarkariTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: SarkariTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

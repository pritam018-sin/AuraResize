// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist Signature & Document Paper Whitener

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../../services/image_resizer_engine.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';
import '../../widgets/action_pipeline_ribbon.dart';
import '../result/sarkari_result_screen.dart';

class SignatureCleanerScreen extends StatefulWidget {
  final File? initialFile;

  const SignatureCleanerScreen({super.key, this.initialFile});

  static Future<void> open(BuildContext context, {File? file}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureCleanerScreen(initialFile: file),
      ),
    );
  }

  @override
  State<SignatureCleanerScreen> createState() => _SignatureCleanerScreenState();
}

class _SignatureCleanerScreenState extends State<SignatureCleanerScreen> {
  File? _file;
  Uint8List? _rawBytes;
  Uint8List? _processedBytes;
  bool _isProcessing = false;
  final int _targetMaxKb = 20;

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
      _applyCleaning(bytes);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null && mounted) {
      _loadFile(File(picked.path));
    }
  }

  Future<void> _applyCleaning(Uint8List bytes) async {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final cleaned = await ImageResizerEngine.instance.processExamImage(
      ResizeTaskParams(
        imageBytes: bytes,
        normalizedCropRect: const Rect.fromLTWH(0, 0, 1, 1),
        targetWidthPx: (decoded.width * 0.8).round().clamp(140, 1000),
        targetHeightPx: (decoded.height * 0.8).round().clamp(60, 600),
        minKb: 5,
        maxKb: _targetMaxKb,
        cleanSignature: true,
        format: 'JPG',
      ),
    );

    if (mounted) {
      setState(() => _processedBytes = cleaned);
    }
  }

  Future<void> _saveAndDone() async {
    if (_processedBytes == null || _file == null) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final savedFile = await SarkariStorageService.instance.saveResizedFile(
      bytes: _processedBytes!,
      baseName: 'Cleaned_Signature',
      extension: 'jpg',
      examCategory: 'Signature',
      itemType: 'Cleaned White Signature',
      widthPx: 0,
      heightPx: 0,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SarkariResultScreen(
            file: savedFile,
            title: 'Cleaned Signature',
            examCategory: 'Signature',
            itemType: 'Pure White Background',
            widthPx: 0,
            heightPx: 0,
            originalSizeBytes: _rawBytes!.length,
            allowedKbString: 'Target: $_targetMaxKb KB',
          ),
        ),
      );
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
        title: const Text('Paper Whitener'),
        actions: [
          if (_processedBytes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: FilledButton(
                onPressed: _isProcessing ? null : _saveAndDone,
                style: FilledButton.styleFrom(
                  backgroundColor: SarkariTheme.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_processedBytes != null) ...[
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
                  const Text('CLEANED OUTPUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SarkariTheme.surfaceBorder),
                    ),
                    child: Image.memory(_processedBytes!, fit: BoxFit.contain, height: 180),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Size: ${(_processedBytes!.length / 1024).toStringAsFixed(1)} KB (Max: $_targetMaxKb KB)',
                    style: const TextStyle(color: SarkariTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Choose Another Image', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ActionPipelineRibbon(
              imageBytes: _processedBytes!,
              activeTool: 'signature',
            ),
          ] else ...[
            InkWell(
              onTap: () => _pickImage(ImageSource.gallery),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: SarkariTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SarkariTheme.surfaceBorder),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.draw_outlined, size: 40, color: SarkariTheme.cyanAccent),
                    SizedBox(height: 12),
                    Text(
                      'Select Signature or Document',
                      style: TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Removes shadows, lighting gradients, and paper yellowing to pure white #FFF.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SarkariTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

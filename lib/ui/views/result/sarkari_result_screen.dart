// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist Export Verification Screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';
import '../../widgets/action_pipeline_ribbon.dart';

class SarkariResultScreen extends StatelessWidget {
  final File file;
  final String title;
  final String examCategory;
  final String itemType;
  final int widthPx;
  final int heightPx;
  final int originalSizeBytes;
  final String? dimensionString;
  final String? allowedKbString;

  const SarkariResultScreen({
    super.key,
    required this.file,
    required this.title,
    required this.examCategory,
    required this.itemType,
    required this.widthPx,
    required this.heightPx,
    required this.originalSizeBytes,
    this.dimensionString,
    this.allowedKbString,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _saveToDevice(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final publicPath = await SarkariStorageService.instance.exportToPublicStorage(file);
    if (context.mounted) {
      if (publicPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SarkariTheme.surfaceElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: SarkariTheme.cyanAccent),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: SarkariTheme.cyanAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved to: ${publicPath.split(Platform.pathSeparator).take(publicPath.split(Platform.pathSeparator).length - 1).join("/")}',
                    style: const TextStyle(color: SarkariTheme.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File already saved in app storage.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newSizeBytes = file.lengthSync();
    final newSizeFormatted = _formatSize(newSizeBytes);
    final origSizeFormatted = _formatSize(originalSizeBytes);

    final isPdf = file.path.toLowerCase().endsWith('.pdf');

    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        title: const Text('Export Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Preview Container
          Center(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 280),
              decoration: BoxDecoration(
                color: SarkariTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SarkariTheme.surfaceBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isPdf
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_outlined, size: 48, color: SarkariTheme.cyanAccent),
                              SizedBox(height: 8),
                              Text('PDF Ready', style: TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.file(file, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Specifications Card
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
                const Text('SPECIFICATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                _buildSpecRow('File Size', newSizeFormatted, SarkariTheme.cyanAccent),
                const Divider(color: SarkariTheme.surfaceBorder, height: 16),
                if (widthPx > 0) ...[
                  _buildSpecRow('Resolution', '$widthPx × $heightPx px', SarkariTheme.textPrimary),
                  const Divider(color: SarkariTheme.surfaceBorder, height: 16),
                ],
                _buildSpecRow('Original Size', origSizeFormatted, SarkariTheme.textSecondary),
                const Divider(color: SarkariTheme.surfaceBorder, height: 16),
                _buildSpecRow('File Name', file.path.split(Platform.pathSeparator).last, SarkariTheme.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chained Action Pipeline Ribbon (Continue Editing in Any Tool)
          ActionPipelineRibbon(
            imageBytes: file.readAsBytesSync(),
          ),
          const SizedBox(height: 18),

          // 3. Actions: Save to Device + Share
          Row(
            children: [
              // Save to Device Button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveToDevice(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: SarkariTheme.cyanAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Save to Device', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              // Share Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Share.shareXFiles([XFile(file.path)], text: title);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SarkariTheme.textPrimary,
                    side: const BorderSide(color: SarkariTheme.surfaceBorder),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            style: OutlinedButton.styleFrom(
              foregroundColor: SarkariTheme.textSecondary,
              side: const BorderSide(color: Colors.transparent),
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: SarkariTheme.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}

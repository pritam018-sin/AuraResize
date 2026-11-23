// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Unified Multi-Tool Action Pipeline Ribbon

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/sarkari_theme.dart';
import '../views/background/background_studio_screen.dart';
import '../views/compressor/target_kb_compressor_screen.dart';
import '../views/converter/format_converter_screen.dart';
import '../views/custom/custom_dimension_screen.dart';

class ActionPipelineRibbon extends StatelessWidget {
  final Uint8List imageBytes;
  final String? activeTool; // E.g. 'bg', 'compress', 'crop', 'format', 'signature'
  final ValueChanged<Uint8List>? onBytesUpdated;

  const ActionPipelineRibbon({
    super.key,
    required this.imageBytes,
    this.activeTool,
    this.onBytesUpdated,
  });

  Future<File> _writeTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final isPng = imageBytes.length > 8 &&
        imageBytes[0] == 0x89 &&
        imageBytes[1] == 0x50 &&
        imageBytes[2] == 0x4E &&
        imageBytes[3] == 0x47;
    final ext = isPng ? 'png' : 'jpg';
    final tempPath = '${tempDir.path}${Platform.pathSeparator}pipeline_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final f = File(tempPath);
    await f.writeAsBytes(imageBytes);
    return f;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'CHAINED TOOLS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: SarkariTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (activeTool != 'bg')
                _buildActionPill(
                  label: 'Background',
                  icon: Icons.color_lens_outlined,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final f = await _writeTempFile();
                    if (context.mounted) {
                      BackgroundStudioScreen.open(context, file: f);
                    }
                  },
                ),
              if (activeTool != 'compress')
                _buildActionPill(
                  label: 'Target Size',
                  icon: Icons.compress_rounded,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final f = await _writeTempFile();
                    if (context.mounted) {
                      TargetKbCompressorScreen.open(context, file: f);
                    }
                  },
                ),
              if (activeTool != 'crop')
                _buildActionPill(
                  label: 'Dimension Crop',
                  icon: Icons.aspect_ratio_rounded,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final f = await _writeTempFile();
                    if (context.mounted) {
                      CustomDimensionScreen.open(context, file: f);
                    }
                  },
                ),
              if (activeTool != 'format')
                _buildActionPill(
                  label: 'Format',
                  icon: Icons.swap_horiz_rounded,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final f = await _writeTempFile();
                    if (context.mounted) {
                      FormatConverterScreen.open(context, file: f);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SarkariTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SarkariTheme.surfaceBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: SarkariTheme.cyanAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: SarkariTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

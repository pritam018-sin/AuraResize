// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist High-Utility Workspace

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';
import '../background/background_studio_screen.dart';
import '../compressor/target_kb_compressor_screen.dart';
import '../converter/format_converter_screen.dart';
import '../custom/custom_dimension_screen.dart';
import '../pdf/pdf_compressor_screen.dart';
import '../result/sarkari_result_screen.dart';
import '../signature/signature_cleaner_screen.dart';

class SarkariHomeScreen extends StatefulWidget {
  const SarkariHomeScreen({super.key});

  @override
  State<SarkariHomeScreen> createState() => _SarkariHomeScreenState();
}

class _SarkariHomeScreenState extends State<SarkariHomeScreen> {
  List<ResizedHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final items = await SarkariStorageService.instance.getHistory();
    if (mounted) {
      setState(() {
        _history = items;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        title: Row(
          children: [
            // Exact Matching App Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AuraResize',
              style: TextStyle(
                color: SarkariTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Core Feature Grid (4 Power Tools Only)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildCleanTile(
                          title: 'Custom Dimension',
                          icon: Icons.aspect_ratio_rounded,
                          onTap: () async {
                            await CustomDimensionScreen.open(context);
                            _loadHistory();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCleanTile(
                          title: 'Background Studio',
                          icon: Icons.color_lens_outlined,
                          onTap: () async {
                            await BackgroundStudioScreen.open(context);
                            _loadHistory();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCleanTile(
                          title: 'Target Size',
                          icon: Icons.compress_rounded,
                          onTap: () async {
                            await TargetKbCompressorScreen.open(context);
                            _loadHistory();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCleanTile(
                          title: 'Format Converter',
                          icon: Icons.swap_horiz_rounded,
                          onTap: () async {
                            await FormatConverterScreen.open(context);
                            _loadHistory();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCleanTile(
                          title: 'PDF Size Reducer',
                          icon: Icons.picture_as_pdf_rounded,
                          onTap: () async {
                            await PdfCompressorScreen.open(context);
                            _loadHistory();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCleanTile(
                          title: 'Signature Cleaner',
                          icon: Icons.draw_rounded,
                          onTap: () async {
                            await SignatureCleanerScreen.open(context);
                            _loadHistory();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Recent Exports Header
          if (_history.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    const Text(
                      'RECENT EXPORTS',
                      style: TextStyle(
                        color: SarkariTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await SarkariStorageService.instance.clearHistory();
                        _loadHistory();
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: SarkariTheme.textMuted,
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _history[index];
                    return _buildHistoryCard(item);
                  },
                  childCount: _history.length,
                ),
              ),
            ),
          ] else ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SarkariTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SarkariTheme.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: SarkariTheme.cyanAccent, size: 22),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, color: SarkariTheme.surfaceBorder, size: 14),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                color: SarkariTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ResizedHistoryItem item) {
    final file = File(item.path);
    final exists = file.existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: SarkariTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SarkariTheme.surfaceBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        dense: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: exists
              ? (item.name.endsWith('.pdf')
                  ? Container(
                      width: 40,
                      height: 40,
                      color: SarkariTheme.surfaceElevated,
                      child: const Icon(Icons.picture_as_pdf_outlined, color: SarkariTheme.cyanAccent, size: 18),
                    )
                  : Image.file(
                      file,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: SarkariTheme.textMuted),
                    ))
              : const Icon(Icons.image_not_supported_outlined, color: SarkariTheme.textMuted),
        ),
        title: Text(
          item.name,
          style: const TextStyle(color: SarkariTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${item.widthPx > 0 ? "${item.widthPx}×${item.heightPx} px • " : ""}${item.formattedSize}',
          style: const TextStyle(color: SarkariTheme.textMuted, fontSize: 10.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: SarkariTheme.textSecondary, size: 16),
              onPressed: exists
                  ? () => Share.shareXFiles([XFile(file.path)], text: item.name)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: SarkariTheme.textMuted, size: 16),
              onPressed: () async {
                await SarkariStorageService.instance.deleteFromHistory(item.path);
                _loadHistory();
              },
            ),
          ],
        ),
        onTap: exists
            ? () {
                if (item.name.toLowerCase().endsWith('.pdf')) {
                  PdfCompressorScreen.open(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SarkariResultScreen(
                        file: file,
                        title: item.name,
                        examCategory: item.examCategory,
                        itemType: item.itemType,
                        widthPx: item.widthPx,
                        heightPx: item.heightPx,
                        originalSizeBytes: item.sizeBytes,
                      ),
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }
}

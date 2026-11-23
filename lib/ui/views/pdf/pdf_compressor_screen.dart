// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist High-Precision PDF Size Reducer & Quality Inspection Studio

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/pdf_engine_service.dart';
import '../../../services/sarkari_storage_service.dart';
import '../../../theme/sarkari_theme.dart';

class PdfCompressorScreen extends StatefulWidget {
  const PdfCompressorScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PdfCompressorScreen()),
    );
  }

  @override
  State<PdfCompressorScreen> createState() => _PdfCompressorScreenState();
}

class _PdfCompressorScreenState extends State<PdfCompressorScreen> {
  File? _selectedPdf;
  int _pageCount = 0;
  int _currentPageIndex = 0;
  int _originalSizeBytes = 0;

  // Rendered preview bytes for inspection
  Uint8List? _originalPageBytes;
  Uint8List? _compressedPageBytes;
  bool _showingCompressed = false;

  // Compression configuration
  PdfCompressionLevel _selectedLevel = PdfCompressionLevel.balanced;
  final TextEditingController _targetKbController = TextEditingController(text: '200');
  bool _isCompressing = false;
  String _statusMessage = '';

  // Compressed Result
  File? _compressedPdf;
  int _compressedSizeBytes = 0;

  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _targetKbController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final path = await PdfEngineService.pickPdf();

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        final size = await file.length();
        final count = await PdfEngineService.getPageCount(file.path);

        setState(() {
          _selectedPdf = file;
          _originalSizeBytes = size;
          _pageCount = count;
          _currentPageIndex = 0;
          _compressedPdf = null;
          _compressedSizeBytes = 0;
          _compressedPageBytes = null;
          _showingCompressed = false;
          _originalPageBytes = null;
          _statusMessage = 'Loading preview...';
        });

        await _loadCurrentPagePreview();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting PDF: $e')),
      );
    }
  }

  Future<void> _loadCurrentPagePreview() async {
    if (_selectedPdf == null) return;
    try {
      final origBytes = await PdfEngineService.renderPage(
        _selectedPdf!.path,
        _currentPageIndex,
        scale: 1.2,
        quality: 90,
      );

      Uint8List? compBytes;
      if (_compressedPdf != null && _compressedPdf!.existsSync()) {
        compBytes = await PdfEngineService.renderPage(
          _compressedPdf!.path,
          _currentPageIndex,
          scale: 1.2,
          quality: 90,
        );
      }

      if (mounted) {
        setState(() {
          _originalPageBytes = origBytes;
          _compressedPageBytes = compBytes;
          _statusMessage = '';
        });
      }
    } catch (_) {}
  }

  Future<void> _changePage(int delta) async {
    final newIndex = _currentPageIndex + delta;
    if (newIndex >= 0 && newIndex < _pageCount) {
      setState(() {
        _currentPageIndex = newIndex;
        _originalPageBytes = null;
        _compressedPageBytes = null;
      });
      _transformController.value = Matrix4.identity();
      await _loadCurrentPagePreview();
    }
  }

  Future<void> _runCompression() async {
    if (_selectedPdf == null) return;

    setState(() {
      _isCompressing = true;
      _statusMessage = 'Optimizing and compressing pages...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      File result;
      if (_selectedLevel == PdfCompressionLevel.custom) {
        final targetKb = int.tryParse(_targetKbController.text.trim()) ?? 200;
        result = await PdfEngineService.compressPdfToTargetKb(
          inputPath: _selectedPdf!.path,
          outputPath: outputPath,
          targetKb: targetKb,
        );
      } else {
        result = await PdfEngineService.compressPdf(
          inputPath: _selectedPdf!.path,
          outputPath: outputPath,
          scale: _selectedLevel.scale,
          quality: _selectedLevel.quality,
        );
      }

      final compSize = await result.length();

      // Render compressed page preview
      final compPageBytes = await PdfEngineService.renderPage(
        result.path,
        _currentPageIndex,
        scale: 1.2,
        quality: 90,
      );

      if (mounted) {
        setState(() {
          _compressedPdf = result;
          _compressedSizeBytes = compSize;
          _compressedPageBytes = compPageBytes;
          _showingCompressed = true;
          _isCompressing = false;
          _statusMessage = '';
        });

        // Haptic feedback
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compression failed: $e')),
        );
      }
    }
  }

  Future<void> _saveToStorage() async {
    if (_compressedPdf == null || !_compressedPdf!.existsSync()) return;

    try {
      final bytes = await _compressedPdf!.readAsBytes();
      final baseName = _selectedPdf!.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');

      await SarkariStorageService.instance.saveResizedFile(
        bytes: bytes,
        baseName: '${baseName}_compressed',
        extension: 'pdf',
        examCategory: 'PDF Document',
        itemType: 'Compressed PDF',
        widthPx: 0,
        heightPx: 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SarkariTheme.surfaceElevated,
            content: Text(
              'PDF saved to AuraResized (${PdfEngineService.formatBytes(_compressedSizeBytes)})',
              style: const TextStyle(color: SarkariTheme.cyanAccent),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reductionPct = _originalSizeBytes > 0 && _compressedSizeBytes > 0
        ? (((_originalSizeBytes - _compressedSizeBytes) / _originalSizeBytes) * 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        title: const Text('PDF Size Reducer'),
        actions: [
          if (_selectedPdf != null)
            TextButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.file_upload_outlined, size: 16, color: SarkariTheme.cyanAccent),
              label: const Text('Change', style: TextStyle(color: SarkariTheme.cyanAccent, fontSize: 13)),
            ),
        ],
      ),
      body: _selectedPdf == null ? _buildEmptyState() : _buildEditor(reductionPct),
      bottomNavigationBar: _selectedPdf == null ? null : _buildBottomBar(reductionPct),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: SarkariTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SarkariTheme.surfaceBorder),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: SarkariTheme.cyanAccent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Compress & Inspect PDF',
              style: TextStyle(
                color: SarkariTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reduce document size for portal uploads without ruining text clarity. Inspect every page before saving.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SarkariTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _pickPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: SarkariTheme.cyanAccent,
                foregroundColor: SarkariTheme.darkBackground,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text(
                'Select PDF File',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(int reductionPct) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      children: [
        // 1. PDF File Metadata Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SarkariTheme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SarkariTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SarkariTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: SarkariTheme.cyanAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPdf!.path.split(Platform.pathSeparator).last,
                      style: const TextStyle(
                        color: SarkariTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${PdfEngineService.formatBytes(_originalSizeBytes)} • $_pageCount Pages',
                      style: const TextStyle(color: SarkariTheme.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Compression Level Selector
        const Text(
          'COMPRESSION LEVEL',
          style: TextStyle(
            color: SarkariTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _buildLevelSelector(),

        if (_selectedLevel == PdfCompressionLevel.custom) ...[
          const SizedBox(height: 10),
          _buildTargetKbInput(),
        ],

        const SizedBox(height: 16),

        // 3. Interactive PDF Preview & Quality Inspection Area
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'INSPECT CLARITY (PINCH TO ZOOM)',
              style: TextStyle(
                color: SarkariTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (_compressedPdf != null)
              Container(
                decoration: BoxDecoration(
                  color: SarkariTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SarkariTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    _buildTogglePill('Original', !_showingCompressed, () {
                      setState(() => _showingCompressed = false);
                    }),
                    _buildTogglePill('Compressed', _showingCompressed, () {
                      setState(() => _showingCompressed = true);
                    }),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Visual Page Viewer Card
        _buildPageViewerCard(),

        // Page Navigation Bar
        if (_pageCount > 1) ...[
          const SizedBox(height: 8),
          _buildPageNavBar(),
        ],
      ],
    );
  }

  Widget _buildLevelSelector() {
    return Container(
      decoration: BoxDecoration(
        color: SarkariTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SarkariTheme.surfaceBorder),
      ),
      child: Column(
        children: PdfCompressionLevel.values.map((lvl) {
          final isSelected = _selectedLevel == lvl;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedLevel = lvl;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: lvl != PdfCompressionLevel.custom
                      ? const BorderSide(color: SarkariTheme.surfaceBorder, width: 0.7)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? SarkariTheme.cyanAccent : SarkariTheme.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lvl.label,
                          style: TextStyle(
                            color: isSelected ? SarkariTheme.cyanAccent : SarkariTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lvl.description,
                          style: const TextStyle(color: SarkariTheme.textMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTargetKbInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SarkariTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SarkariTheme.cyanAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Target Size (KB):',
                style: TextStyle(color: SarkariTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                height: 36,
                child: TextField(
                  controller: _targetKbController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: SarkariTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: SarkariTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: SarkariTheme.surfaceBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('KB', style: TextStyle(color: SarkariTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [100, 200, 300, 500].map((kb) {
              final isCurrent = _targetKbController.text == kb.toString();
              return ActionChip(
                label: Text('$kb KB', style: TextStyle(fontSize: 11, color: isCurrent ? SarkariTheme.cyanAccent : SarkariTheme.textSecondary)),
                backgroundColor: isCurrent ? SarkariTheme.cyanAccent.withOpacity(0.15) : SarkariTheme.surfaceElevated,
                side: BorderSide(color: isCurrent ? SarkariTheme.cyanAccent : SarkariTheme.surfaceBorder),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                onPressed: () {
                  setState(() {
                    _targetKbController.text = kb.toString();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglePill(String title, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? SarkariTheme.cyanAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? SarkariTheme.darkBackground : SarkariTheme.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPageViewerCard() {
    final activeBytes = _showingCompressed ? _compressedPageBytes : _originalPageBytes;

    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SarkariTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SarkariTheme.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (activeBytes != null)
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 5.0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.memory(
                      activeBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SarkariTheme.cyanAccent),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage.isNotEmpty ? _statusMessage : 'Rendering page preview...',
                  style: const TextStyle(color: SarkariTheme.textMuted, fontSize: 12),
                ),
              ],
            ),

          // Double tap hint overlay
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: SarkariTheme.cyanAccent, size: 12),
                  SizedBox(width: 4),
                  Text('Pinch to zoom', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),

          // Showing Mode Badge
          if (_compressedPdf != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _showingCompressed ? SarkariTheme.emeraldAccent.withOpacity(0.9) : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _showingCompressed ? 'Viewing: Compressed' : 'Viewing: Original',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SarkariTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SarkariTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: _currentPageIndex > 0 ? SarkariTheme.cyanAccent : SarkariTheme.textMuted,
            onPressed: _currentPageIndex > 0 ? () => _changePage(-1) : null,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            'Page ${_currentPageIndex + 1} of $_pageCount',
            style: const TextStyle(color: SarkariTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: _currentPageIndex < _pageCount - 1 ? SarkariTheme.cyanAccent : SarkariTheme.textMuted,
            onPressed: _currentPageIndex < _pageCount - 1 ? () => _changePage(1) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int reductionPct) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: SarkariTheme.surfaceCard,
        border: Border(top: BorderSide(color: SarkariTheme.surfaceBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_compressedPdf != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RESULT SIZE', style: TextStyle(color: SarkariTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            PdfEngineService.formatBytes(_originalSizeBytes),
                            style: const TextStyle(color: SarkariTheme.textMuted, fontSize: 11, decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: SarkariTheme.cyanAccent, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            PdfEngineService.formatBytes(_compressedSizeBytes),
                            style: const TextStyle(color: SarkariTheme.emeraldAccent, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SarkariTheme.emeraldAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SarkariTheme.emeraldAccent.withOpacity(0.4)),
                    ),
                    child: Text(
                      '-$reductionPct% Saved',
                      style: const TextStyle(color: SarkariTheme.emeraldAccent, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_compressedPdf != null) {
                          Share.shareXFiles(
                            [XFile(_compressedPdf!.path)],
                            text: 'Compressed with AuraResize',
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SarkariTheme.cyanAccent,
                        side: const BorderSide(color: SarkariTheme.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveToStorage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SarkariTheme.cyanAccent,
                        foregroundColor: SarkariTheme.darkBackground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Save PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCompressing ? null : _runCompression,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SarkariTheme.cyanAccent,
                    foregroundColor: SarkariTheme.darkBackground,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isCompressing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SarkariTheme.darkBackground))
                      : const Icon(Icons.compress_rounded, size: 18),
                  label: Text(
                    _isCompressing ? 'Compressing...' : 'Compress PDF',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

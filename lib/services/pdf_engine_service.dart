// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - High-Performance Native PDF Engine & Compression Pipeline

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum PdfCompressionLevel {
  low(label: 'Low (Sharp Text)', description: '~30-40% reduction, best for fine text & prints', scale: 1.2, quality: 80),
  balanced(label: 'Balanced (Recommended)', description: '~60-70% reduction, ideal for govt/exam portals', scale: 1.0, quality: 65),
  maximum(label: 'Maximum (Smallest)', description: '~80-90% reduction, lowest size under strict limits', scale: 0.8, quality: 48),
  custom(label: 'Target KB', description: 'Compress strictly under your desired KB limit', scale: 1.0, quality: 65);

  final String label;
  final String description;
  final double scale;
  final int quality;

  const PdfCompressionLevel({
    required this.label,
    required this.description,
    required this.scale,
    required this.quality,
  });
}

class PdfEngineService {
  static const MethodChannel _channel = MethodChannel('com.aurastudio.aura_resize/pdf_renderer');

  static Future<String?> pickPdf() async {
    try {
      final path = await _channel.invokeMethod<String>('pickPdf');
      return path;
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      return null;
    }
  }

  static Future<int> getPageCount(String filePath) async {
    try {
      final count = await _channel.invokeMethod<int>('getPageCount', {'filePath': filePath});
      return count ?? 0;
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      return 0;
    }
  }

  static Future<Uint8List?> renderPage(
    String filePath,
    int pageIndex, {
    double scale = 1.0,
    int quality = 85,
  }) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('renderPage', {
        'filePath': filePath,
        'pageIndex': pageIndex,
        'scale': scale,
        'quality': quality,
      });
      return bytes;
    } catch (e) {
      debugPrint('Error rendering PDF page $pageIndex: $e');
      return null;
    }
  }

  static Future<List<Uint8List>> renderAllPages(
    String filePath, {
    double scale = 1.0,
    int quality = 85,
  }) async {
    try {
      final list = await _channel.invokeListMethod<Uint8List>('renderAllPages', {
        'filePath': filePath,
        'scale': scale,
        'quality': quality,
      });
      return list ?? [];
    } catch (e) {
      debugPrint('Error rendering all PDF pages: $e');
      return [];
    }
  }

  static Future<File> compressPdf({
    required String inputPath,
    required String outputPath,
    double scale = 1.0,
    int quality = 65,
  }) async {
    final pageImages = await renderAllPages(inputPath, scale: scale, quality: quality);
    if (pageImages.isEmpty) {
      throw Exception('Failed to render PDF pages for compression');
    }

    final doc = pw.Document(compress: true);
    for (final pageBytes in pageImages) {
      final image = pw.MemoryImage(pageBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );
    }

    final outputBytes = await doc.save();
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(outputBytes, flush: true);
    return outputFile;
  }

  static Future<File> compressPdfToTargetKb({
    required String inputPath,
    required String outputPath,
    required int targetKb,
  }) async {
    final pageCount = await getPageCount(inputPath);
    final pages = pageCount > 0 ? pageCount : 1;
    final targetBytesPerPg = (targetKb * 1024) ~/ pages;

    double scale = 1.0;
    int quality = 65;

    if (targetBytesPerPg < 45 * 1024) {
      scale = 0.65;
      quality = 40;
    } else if (targetBytesPerPg < 90 * 1024) {
      scale = 0.8;
      quality = 52;
    } else if (targetBytesPerPg < 160 * 1024) {
      scale = 0.95;
      quality = 62;
    } else if (targetBytesPerPg < 300 * 1024) {
      scale = 1.1;
      quality = 75;
    } else {
      scale = 1.25;
      quality = 85;
    }

    // Attempt first compression pass
    File result = await compressPdf(
      inputPath: inputPath,
      outputPath: outputPath,
      scale: scale,
      quality: quality,
    );

    // If still exceeds target KB, perform one tighter pass
    final len = await result.length();
    if (len > targetKb * 1024 && quality > 35) {
      final ratio = (targetKb * 1024) / len;
      final newScale = (scale * 0.85).clamp(0.5, 1.0);
      final newQuality = (quality * ratio * 0.9).toInt().clamp(30, 80);

      result = await compressPdf(
        inputPath: inputPath,
        outputPath: outputPath,
        scale: newScale,
        quality: newQuality,
      );
    }

    return result;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

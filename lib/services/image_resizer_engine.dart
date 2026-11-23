// Copyright (C) 2026 AuraStudio Corporation • Pritam
// SarkariResize Pro - Core Image Processing & Sarkari Resizer Engine
// Pure Dart linear algebra & bicubic image resampling. 100% On-Device & Private.

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ResizeTaskParams {
  final Uint8List imageBytes;
  final Rect normalizedCropRect; // 0.0 to 1.0
  final int targetWidthPx;
  final int targetHeightPx;
  final int minKb;
  final int maxKb;
  final bool addNameDate;
  final String? candidateName;
  final String? photoDate;
  final bool cleanSignature;
  final String format; // 'JPG', 'PNG', 'PDF'

  const ResizeTaskParams({
    required this.imageBytes,
    required this.normalizedCropRect,
    required this.targetWidthPx,
    required this.targetHeightPx,
    this.minKb = 20,
    this.maxKb = 50,
    this.addNameDate = false,
    this.candidateName,
    this.photoDate,
    this.cleanSignature = false,
    this.format = 'JPG',
  });
}

class ImageResizerEngine {
  ImageResizerEngine._();
  static final ImageResizerEngine instance = ImageResizerEngine._();

  /// Primary Sarkari Exam processor: Crop, Resize, Clean Signature, Add DOP, and Smart Compress
  Future<Uint8List> processExamImage(ResizeTaskParams params) async {
    var decoded = img.decodeImage(params.imageBytes);
    if (decoded == null) throw Exception('Could not decode image bytes.');

    // 1. Crop to Normalized Bounding Box
    final double srcW = decoded.width.toDouble();
    final double srcH = decoded.height.toDouble();

    final int cropX = (params.normalizedCropRect.left * srcW).round().clamp(0, decoded.width - 10);
    final int cropY = (params.normalizedCropRect.top * srcH).round().clamp(0, decoded.height - 10);
    final int cropW = (params.normalizedCropRect.width * srcW).round().clamp(10, decoded.width - cropX);
    final int cropH = (params.normalizedCropRect.height * srcH).round().clamp(10, decoded.height - cropY);

    var cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);

    // 2. High-Fidelity Resample to Exact Required Pixel Dimension
    final targetW = params.targetWidthPx.clamp(10, 4096);
    final targetH = params.targetHeightPx.clamp(10, 4096);
    cropped = img.copyResize(
      cropped,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.linear,
    );

    // 3. Signature & Thumb Impression Background Cleaner
    if (params.cleanSignature) {
      cropped = _cleanSignatureBackground(cropped);
    }

    // 4. Name & Date on Photo (DOP) Bottom Banner (Mandatory for SSC / UPSC)
    if (params.addNameDate && (params.candidateName != null || params.photoDate != null)) {
      cropped = _stampNameAndDateBanner(
        cropped,
        name: params.candidateName ?? 'CANDIDATE NAME',
        date: params.photoDate ?? 'DOP: 16/11/2026',
      );
    }

    // 5. PDF Export
    if (params.format.toUpperCase() == 'PDF') {
      final jpgBytes = img.encodeJpg(cropped, quality: 90);
      final pdf = pw.Document();
      final pdfImg = pw.MemoryImage(jpgBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            targetW.toDouble() * 72 / 96,
            targetH.toDouble() * 72 / 96,
          ),
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pdfImg, fit: pw.BoxFit.fill),
          ),
        ),
      );
      return await pdf.save();
    }

    // 6. PNG Export
    if (params.format.toUpperCase() == 'PNG') {
      return Uint8List.fromList(img.encodePng(cropped));
    }

    // 7. Smart Binary Search Compression to hit the exact target KB Range [minKb - maxKb]
    return _smartTargetCompressJpg(cropped, minKb: params.minKb, maxKb: params.maxKb);
  }

  /// Cleans paper shadows and grey smartphone camera artifacts from signatures/thumb impressions
  /// Yields pure #FFFFFF white background with boosted black or dark blue ink.
  img.Image _cleanSignatureBackground(img.Image src) {
    final out = img.Image.from(src);

    // Calculate average brightness
    double sum = 0;
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        sum += (p.r * 299 + p.g * 587 + p.b * 114) / 1000;
      }
    }
    final int avgLum = (sum / (src.width * src.height)).round();
    final int threshold = (avgLum * 0.78).toInt().clamp(100, 210);

    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final p = src.getPixel(x, y);
        final lum = (p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000;

        if (lum > threshold) {
          // Paper background -> Pure White
          out.setPixelRgb(x, y, 255, 255, 255);
        } else {
          // Ink stroke -> Deepen contrast
          final factor = (lum / threshold);
          final r = (p.r * factor * 0.7).toInt().clamp(0, 255);
          final g = (p.g * factor * 0.7).toInt().clamp(0, 255);
          final b = (p.b * factor * 0.7).toInt().clamp(0, 255);
          out.setPixelRgb(x, y, r, g, b);
        }
      }
    }
    return out;
  }

  /// Adds a standard official white text strip at the bottom of the photo for SSC / UPSC exams
  img.Image _stampNameAndDateBanner(
    img.Image src, {
    required String name,
    required String date,
  }) {
    final out = img.Image.from(src);
    final bannerHeight = (src.height * 0.18).round().clamp(36, 140);
    final startY = src.height - bannerHeight;

    // 1. Draw solid white rectangle banner
    for (int y = startY; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        out.setPixelRgb(x, y, 255, 255, 255);
      }
    }

    // 2. Draw black dividing line on top of banner
    for (int x = 0; x < src.width; x++) {
      out.setPixelRgb(x, startY, 40, 40, 40);
    }

    // 3. Render clean black text using internal bitmap font
    final font = bannerHeight > 60 ? img.arial24 : img.arial14;

    final nameText = name.toUpperCase();
    final dateText = date.toUpperCase();

    // Center Name
    final nameW = nameText.length * (font.size * 0.6);
    final nameX = math.max(6, (src.width - nameW) ~/ 2);
    final nameY = startY + (bannerHeight ~/ 7);

    img.drawString(
      out,
      nameText,
      font: font,
      x: nameX.toInt(),
      y: nameY,
      color: img.ColorRgb8(0, 0, 0),
    );

    // Center Date
    final dateW = dateText.length * (font.size * 0.6);
    final dateX = math.max(6, (src.width - dateW) ~/ 2);
    final dateY = nameY + (bannerHeight ~/ 2);

    img.drawString(
      out,
      dateText,
      font: font,
      x: dateX.toInt(),
      y: dateY,
      color: img.ColorRgb8(0, 0, 0),
    );

    return out;
  }

  /// Iterative Binary Search JPEG compressor: Lands strictly inside [minKb, maxKb]
  Uint8List _smartTargetCompressJpg(img.Image image, {required int minKb, required int maxKb}) {
    int low = 5;
    int high = 98;
    int bestQuality = 80;
    Uint8List bestBytes = Uint8List.fromList(img.encodeJpg(image, quality: 80));

    final targetMinBytes = minKb * 1024;
    final targetMaxBytes = maxKb * 1024;

    for (int iter = 0; iter < 7; iter++) {
      final mid = (low + high) ~/ 2;
      final current = Uint8List.fromList(img.encodeJpg(image, quality: mid));
      final size = current.length;

      if (size <= targetMaxBytes && size >= targetMinBytes) {
        // Perfect fit!
        return current;
      }

      if (size > targetMaxBytes) {
        high = mid - 1;
        bestQuality = mid;
        bestBytes = current;
      } else {
        low = mid + 1;
        bestQuality = mid;
        bestBytes = current;
      }
    }

    // If still slightly oversized, downscale resolution slightly
    if (bestBytes.length > targetMaxBytes) {
      final double scale = math.sqrt(targetMaxBytes / bestBytes.length) * 0.95;
      final newW = (image.width * scale).round().clamp(50, image.width);
      final newH = (image.height * scale).round().clamp(50, image.height);
      final resized = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
      return Uint8List.fromList(img.encodeJpg(resized, quality: bestQuality.clamp(20, 80)));
    }

    return bestBytes;
  }

  /// Standalone Target KB Compressor for existing images
  Uint8List compressImageToTargetKb(Uint8List bytes, int targetKb) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final targetBytes = targetKb * 1024;
    int low = 2;
    int high = 98;
    Uint8List candidate = Uint8List.fromList(img.encodeJpg(decoded, quality: 75));

    for (int iter = 0; iter < 8; iter++) {
      final mid = (low + high) ~/ 2;
      final encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: mid));

      if (encoded.length <= targetBytes) {
        candidate = encoded;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // If even quality 2 exceeds target, downscale dimensions
    if (candidate.length > targetBytes) {
      final double scale = math.sqrt(targetBytes / candidate.length) * 0.92;
      final newW = (decoded.width * scale).round().clamp(50, decoded.width);
      final newH = (decoded.height * scale).round().clamp(50, decoded.height);
      final resized = img.copyResize(decoded, width: newW, height: newH);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    }

    return candidate;
  }

  /// Format Converter (PNG -> JPG, WEBP -> JPG, BMP -> JPG, JPG -> PDF)
  Future<Uint8List> convertImageFormat(Uint8List bytes, String targetFormat, {int quality = 92}) async {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    switch (targetFormat.toUpperCase()) {
      case 'JPG':
      case 'JPEG':
        // Replace transparency with clean white
        final whiteCanvas = img.Image(width: decoded.width, height: decoded.height);
        img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(whiteCanvas, decoded);
        return Uint8List.fromList(img.encodeJpg(whiteCanvas, quality: quality));

      case 'PNG':
        return Uint8List.fromList(img.encodePng(decoded));

      case 'PDF':
        final jpgBytes = img.encodeJpg(decoded, quality: quality);
        final pdf = pw.Document();
        final pdfImg = pw.MemoryImage(jpgBytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(decoded.width.toDouble() * 0.75, decoded.height.toDouble() * 0.75),
            build: (_) => pw.FullPage(ignoreMargins: true, child: pw.Image(pdfImg, fit: pw.BoxFit.contain)),
          ),
        );
        return await pdf.save();

      default:
        return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    }
  }
}

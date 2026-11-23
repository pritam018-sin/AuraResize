// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - 100% Offline U-2-Net (rembg) On-Device Background Removal Engine
// Features: Guided Hair Strand Matting & Background Color Decontamination

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Parameters passed into background Isolate
class _U2NetParams {
  final Uint8List imageBytes;
  final Uint8List modelBytes;
  final int? targetColorValue; // ARGB int or null for transparent
  final double threshold;
  final double feather;
  final bool refineHair;

  _U2NetParams({
    required this.imageBytes,
    required this.modelBytes,
    this.targetColorValue,
    this.threshold = 0.50,
    this.feather = 0.12,
    this.refineHair = true,
  });
}

class U2NetBackgroundRemover {
  U2NetBackgroundRemover._();
  static final U2NetBackgroundRemover instance = U2NetBackgroundRemover._();

  static const String modelAsset = 'assets/models/u2netp.tflite';
  static const int inputDim = 320;

  Uint8List? _cachedModelBytes;

  /// Loads model bytes once from assets and caches in memory
  Future<Uint8List> _getModelBytes() async {
    if (_cachedModelBytes != null) return _cachedModelBytes!;
    final byteData = await rootBundle.load(modelAsset);
    _cachedModelBytes = byteData.buffer.asUint8List();
    return _cachedModelBytes!;
  }

  /// Primary Public Method:
  /// Runs on background Isolate to prevent UI frame drops.
  Future<Uint8List> removeBackground({
    required Uint8List bytes,
    Color? targetColor,
    double threshold = 0.50,
    double feather = 0.12,
    bool refineHair = true,
  }) async {
    final modelBytes = await _getModelBytes();

    final int? colorInt = (targetColor != null && (targetColor.a * 255).round() > 0)
        ? ((targetColor.a * 255).round() << 24) |
          ((targetColor.r * 255).round() << 16) |
          ((targetColor.g * 255).round() << 8) |
          (targetColor.b * 255).round()
        : null;

    final params = _U2NetParams(
      imageBytes: bytes,
      modelBytes: modelBytes,
      targetColorValue: colorInt,
      threshold: threshold,
      feather: feather,
      refineHair: refineHair,
    );

    // Isolate.run spawns a worker thread, executes, and cleans up automatically
    return await Isolate.run(() => _executeInIsolate(params));
  }

  /// Background Isolate Worker
  static Uint8List _executeInIsolate(_U2NetParams params) {
    // 1. Decode original high-resolution image
    final img.Image? original = img.decodeImage(params.imageBytes);
    if (original == null) {
      throw Exception('Failed to decode source image.');
    }

    final int origW = original.width;
    final int origH = original.height;

    // 2. Pre-processing: Resize copy to 320x320 using Bilinear Interpolation
    final img.Image resized320 = img.copyResize(
      original,
      width: inputDim,
      height: inputDim,
      interpolation: img.Interpolation.linear,
    );

    // 3. ImageNet Normalization (Used by U2Net & rembg)
    // Mean: [0.485, 0.456, 0.406], Std: [0.229, 0.224, 0.225]
    final Float32List inputBuffer = Float32List(1 * inputDim * inputDim * 3);
    int inIdx = 0;

    for (int y = 0; y < inputDim; y++) {
      for (int x = 0; x < inputDim; x++) {
        final p = resized320.getPixel(x, y);
        inputBuffer[inIdx++] = (p.r / 255.0 - 0.485) / 0.229;
        inputBuffer[inIdx++] = (p.g / 255.0 - 0.456) / 0.224;
        inputBuffer[inIdx++] = (p.b / 255.0 - 0.406) / 0.225;
      }
    }

    // 4. Initialize TFLite Interpreter from in-memory model buffer
    final Interpreter interpreter = Interpreter.fromBuffer(
      params.modelBytes,
      options: InterpreterOptions()..threads = 4,
    );

    final inputTensor = inputBuffer.reshape([1, inputDim, inputDim, 3]);

    // Inspect output shape dynamically to handle both [1, 320, 320, 1] and [1, 1, 320, 320]
    final List<int> outShape = interpreter.getOutputTensor(0).shape;

    // Allocate output tensor
    final outputTensor = List.generate(
      outShape[0],
      (_) => List.generate(
        outShape[1],
        (_) => List.generate(
          outShape[2],
          (_) => List.generate(outShape[3], (_) => 0.0),
        ),
      ),
    );

    // 5. Run inference
    interpreter.run(inputTensor, outputTensor);
    interpreter.close();

    // 6. Extract Saliency Scores & Min-Max Normalization
    final Float32List mask320 = Float32List(inputDim * inputDim);
    double minVal = double.infinity;
    double maxVal = -double.infinity;

    int maskIdx = 0;
    // Handle NHWC [1, 320, 320, 1] vs NCHW [1, 1, 320, 320]
    final bool isNchw = (outShape[1] == 1 && outShape[2] == inputDim);

    for (int y = 0; y < inputDim; y++) {
      for (int x = 0; x < inputDim; x++) {
        final double v = isNchw ? outputTensor[0][0][y][x] : outputTensor[0][y][x][0];
        mask320[maskIdx++] = v;
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }

    final double range = (maxVal - minVal) > 1e-6 ? (maxVal - minVal) : 1.0;
    for (int i = 0; i < mask320.length; i++) {
      mask320[i] = ((mask320[i] - minVal) / range).clamp(0.0, 1.0);
    }

    // 7. Post-processing (HD Upsampling to ORIGINAL Image Resolution):
    // Bilinear interpolation from 320x320 mask to (origW x origH)
    final bool isTransparent = params.targetColorValue == null;
    final img.Image output = img.Image(
      width: origW,
      height: origH,
      numChannels: isTransparent ? 4 : 3,
    );

    int bgR = 255, bgG = 255, bgB = 255;
    if (!isTransparent) {
      final c = params.targetColorValue!;
      bgR = (c >> 16) & 0xFF;
      bgG = (c >> 8) & 0xFF;
      bgB = c & 0xFF;
    }

    final double minThresh = (params.threshold - params.feather).clamp(0.05, 0.90);
    final double maxThresh = (params.threshold + params.feather).clamp(minThresh + 0.05, 0.98);
    final double threshRange = maxThresh - minThresh;

    final double scaleX = (inputDim - 1) / (origW > 1 ? origW - 1 : 1);
    final double scaleY = (inputDim - 1) / (origH > 1 ? origH - 1 : 1);

    final int hairZoneMaxY = (origH * 0.55).round();

    for (int y = 0; y < origH; y++) {
      final double gy = y * scaleY;
      final int y0 = gy.floor().clamp(0, inputDim - 1);
      final int y1 = (y0 + 1).clamp(0, inputDim - 1);
      final double sy = gy - y0;
      final int row0 = y0 * inputDim;
      final int row1 = y1 * inputDim;

      final bool inHairZone = params.refineHair && (y < hairZoneMaxY);

      for (int x = 0; x < origW; x++) {
        final double gx = x * scaleX;
        final int x0 = gx.floor().clamp(0, inputDim - 1);
        final int x1 = (x0 + 1).clamp(0, inputDim - 1);
        final double sx = gx - x0;

        // Bilinear mask interpolation
        final double c00 = mask320[row0 + x0];
        final double c10 = mask320[row0 + x1];
        final double c01 = mask320[row1 + x0];
        final double c11 = mask320[row1 + x1];

        double conf = (1.0 - sx) * (1.0 - sy) * c00 +
            sx * (1.0 - sy) * c10 +
            (1.0 - sx) * sy * c01 +
            sx * sy * c11;

        final p = original.getPixel(x, y);
        int pr = p.r.toInt();
        int pg = p.g.toInt();
        int pb = p.b.toInt();

        // 1. Hair Edge Matting & Strand Preservation:
        if (inHairZone && conf > 0.12 && conf < 0.88) {
          final double lum = 0.299 * pr + 0.587 * pg + 0.114 * pb;
          if (lum < 125.0) {
            // Dark strand boost
            final double darkRatio = (1.0 - (lum / 125.0)).clamp(0.0, 1.0);
            final double verticalWeight = (1.0 - (y / hairZoneMaxY)).clamp(0.3, 1.0);
            final double hairBoost = darkRatio * 0.28 * verticalWeight;
            conf = (conf + hairBoost).clamp(0.0, 1.0);
          }
        }

        if (conf >= maxThresh) {
          // Pure Foreground
          if (isTransparent) {
            output.setPixelRgba(x, y, pr, pg, pb, 255);
          } else {
            output.setPixelRgb(x, y, pr, pg, pb);
          }
        } else if (conf <= minThresh) {
          // Pure Background
          if (isTransparent) {
            output.setPixelRgba(x, y, 0, 0, 0, 0);
          } else {
            output.setPixelRgb(x, y, bgR, bgG, bgB);
          }
        } else {
          // Hermite Smoothstep Cubic Curve
          final double t = ((conf - minThresh) / threshRange).clamp(0.0, 1.0);
          final double alpha = t * t * (3.0 - 2.0 * t);

          // 2. Hair Color Decontamination (Anti-Halo Defringing):
          // In the transition boundary around hair, neutralize old background color bleed
          if (inHairZone && alpha > 0.03 && alpha < 0.95) {
            final double lum = 0.299 * pr + 0.587 * pg + 0.114 * pb;
            if (lum < 135.0) {
              final double decontam = (1.0 - alpha) * 0.60;
              final int hairTone = (lum * 0.85).round().clamp(0, 255);
              pr = (pr * (1.0 - decontam) + hairTone * decontam).round().clamp(0, 255);
              pg = (pg * (1.0 - decontam) + hairTone * decontam).round().clamp(0, 255);
              pb = (pb * (1.0 - decontam) + hairTone * decontam).round().clamp(0, 255);
            }
          }

          if (isTransparent) {
            final int outA = (255 * alpha).round().clamp(0, 255);
            output.setPixelRgba(x, y, pr, pg, pb, outA);
          } else {
            // Anti-halo edge blending with background color
            final int outR = (pr * alpha + bgR * (1.0 - alpha)).round().clamp(0, 255);
            final int outG = (pg * alpha + bgG * (1.0 - alpha)).round().clamp(0, 255);
            final int outB = (pb * alpha + bgB * (1.0 - alpha)).round().clamp(0, 255);
            output.setPixelRgb(x, y, outR, outG, outB);
          }
        }
      }
    }

    if (isTransparent) {
      return Uint8List.fromList(img.encodePng(output));
    }
    return Uint8List.fromList(img.encodeJpg(output, quality: 98));
  }
}

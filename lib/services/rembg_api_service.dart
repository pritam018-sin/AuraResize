// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - RemBG Cloud API Service (Seamless Internal Hybrid Processing)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';

class RembgApiService {
  RembgApiService._();
  static final RembgApiService instance = RembgApiService._();

  /// Calls RemBG Cloud API to remove background.
  /// Returns Uint8List bytes on success (HTTP 200).
  /// Returns null on any failure (offline, timeout, quota) so app silently falls back to on-device U2Net.
  Future<Uint8List?> removeBackground({
    required Uint8List bytes,
    Color? targetColor,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri = Uri.parse(AppConfig.remBgApiEndpoint);
      final request = await client.postUrl(uri);

      final String boundary = '----AuraBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set('x-api-key', AppConfig.remBgApiKey);
      request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

      final bool isTransparent = targetColor == null || (targetColor.a * 255).round() == 0;

      final List<int> body = [];

      // 1. Output format: png
      body.addAll(utf8.encode('--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="format"\r\n\r\npng\r\n'));

      // 2. Solid Background Color in hex (#rrggbbaa)
      if (!isTransparent) {
        final rHex = ((targetColor.r * 255).round()).toRadixString(16).padLeft(2, '0');
        final gHex = ((targetColor.g * 255).round()).toRadixString(16).padLeft(2, '0');
        final bHex = ((targetColor.b * 255).round()).toRadixString(16).padLeft(2, '0');
        final aHex = ((targetColor.a * 255).round()).toRadixString(16).padLeft(2, '0');
        final hexColor = '#$rHex$gHex$bHex$aHex';

        body.addAll(utf8.encode('--$boundary\r\n'));
        body.addAll(utf8.encode('Content-Disposition: form-data; name="bg_color"\r\n\r\n$hexColor\r\n'));
      }

      // 3. Image file bytes
      body.addAll(utf8.encode('--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="image"; filename="portrait.jpg"\r\n'));
      body.addAll(utf8.encode('Content-Type: image/jpeg\r\n\r\n'));
      body.addAll(bytes);
      body.addAll(utf8.encode('\r\n'));

      // 4. Closing boundary
      body.addAll(utf8.encode('--$boundary--\r\n'));

      request.contentLength = body.length;
      request.add(body);

      final response = await request.close().timeout(timeout);

      if (response.statusCode == 200) {
        final resultBytes = await consolidateHttpClientResponseBytes(response);
        return resultBytes;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}

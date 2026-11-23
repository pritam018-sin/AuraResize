// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - In-Memory Active Image Session for Continuous Action Pipeline

import 'dart:io';
import 'dart:typed_data';

class ImageSession {
  File? file;
  Uint8List bytes;
  String format; // 'JPG', 'PNG', 'PDF'
  int width;
  int height;
  String title;

  ImageSession({
    this.file,
    required this.bytes,
    this.format = 'JPG',
    this.width = 0,
    this.height = 0,
    this.title = 'Active Image',
  });

  /// Factory to initialize session from a picked File
  static Future<ImageSession> fromFile(File f, {String? title}) async {
    final b = await f.readAsBytes();
    final ext = f.path.split('.').last.toUpperCase();
    return ImageSession(
      file: f,
      bytes: b,
      format: ext == 'PNG' ? 'PNG' : (ext == 'PDF' ? 'PDF' : 'JPG'),
      title: title ?? f.path.split(Platform.pathSeparator).last,
    );
  }

  /// Create a fresh copy with updated bytes
  ImageSession copyWith({
    File? file,
    Uint8List? bytes,
    String? format,
    int? width,
    int? height,
    String? title,
  }) {
    return ImageSession(
      file: file ?? this.file,
      bytes: bytes ?? this.bytes,
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      title: title ?? this.title,
    );
  }
}

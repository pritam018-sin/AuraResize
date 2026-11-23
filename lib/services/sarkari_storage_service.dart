// Copyright (C) 2026 AuraStudio Corporation • Pritam
// SarkariResize Pro - File Storage & History Service

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResizedHistoryItem {
  final String path;
  final String name;
  final String examCategory;
  final String itemType;
  final int sizeBytes;
  final int widthPx;
  final int heightPx;
  final DateTime timestamp;

  ResizedHistoryItem({
    required this.path,
    required this.name,
    required this.examCategory,
    required this.itemType,
    required this.sizeBytes,
    required this.widthPx,
    required this.heightPx,
    required this.timestamp,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'examCategory': examCategory,
        'itemType': itemType,
        'sizeBytes': sizeBytes,
        'widthPx': widthPx,
        'heightPx': heightPx,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ResizedHistoryItem.fromJson(Map<String, dynamic> json) => ResizedHistoryItem(
        path: json['path'] as String,
        name: json['name'] as String,
        examCategory: json['examCategory'] as String,
        itemType: json['itemType'] as String,
        sizeBytes: json['sizeBytes'] as int,
        widthPx: json['widthPx'] as int,
        heightPx: json['heightPx'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class SarkariStorageService {
  SarkariStorageService._();
  static final SarkariStorageService instance = SarkariStorageService._();

  static const String _prefKey = 'sarkari_resized_history';

  Future<File> saveResizedFile({
    required Uint8List bytes,
    required String baseName,
    required String extension,
    required String examCategory,
    required String itemType,
    required int widthPx,
    required int heightPx,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final outputFolder = Directory('${dir.path}${Platform.pathSeparator}AuraResized');
    if (!outputFolder.existsSync()) {
      outputFolder.createSync(recursive: true);
    }

    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final fileName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';
    final outFile = File('${outputFolder.path}${Platform.pathSeparator}$fileName');
    await outFile.writeAsBytes(bytes);

    // Save to history
    final item = ResizedHistoryItem(
      path: outFile.path,
      name: fileName,
      examCategory: examCategory,
      itemType: itemType,
      sizeBytes: bytes.length,
      widthPx: widthPx,
      heightPx: heightPx,
      timestamp: DateTime.now(),
    );

    await _addToHistory(item);
    return outFile;
  }

  Future<String?> exportToPublicStorage(File sourceFile) async {
    try {
      final fileName = sourceFile.path.split(Platform.pathSeparator).last;
      final candidates = [
        Directory('/storage/emulated/0/Download/AuraResize'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Pictures/AuraResize'),
        Directory('/storage/emulated/0/Pictures'),
      ];

      for (final dir in candidates) {
        try {
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          final dest = File('${dir.path}${Platform.pathSeparator}$fileName');
          await sourceFile.copy(dest.path);
          return dest.path;
        } catch (_) {}
      }

      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dest = File('${ext.path}${Platform.pathSeparator}$fileName');
        await sourceFile.copy(dest.path);
        return dest.path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _addToHistory(ResizedHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final existingList = await getHistory();
    existingList.insert(0, item);

    // Keep up to 50 recent items
    final trimmed = existingList.take(50).toList();
    final jsonList = trimmed.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_prefKey, jsonList);
  }

  Future<List<ResizedHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefKey) ?? [];
    final items = <ResizedHistoryItem>[];

    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final item = ResizedHistoryItem.fromJson(decoded);
        if (File(item.path).existsSync()) {
          items.add(item);
        }
      } catch (_) {}
    }
    return items;
  }

  Future<void> deleteFromHistory(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final existingList = await getHistory();
    existingList.removeWhere((i) => i.path == path);
    final jsonList = existingList.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_prefKey, jsonList);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  Future<void> deleteHistoryItem(ResizedHistoryItem item) async {
    await deleteFromHistory(item.path);
  }
}

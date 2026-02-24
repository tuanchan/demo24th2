// save_flash_logic.dart
// =====================================================================
// SAVE FLASH: quét thư mục SaveFlash (cùng cấp AppMusicVol2),
// phát hiện file .mp3/.m4a mới, hiển thị popup để user chọn playlist.
// KHÔNG đụng logic/UI cũ.
// =====================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaveFlashFile {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  const SaveFlashFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  @override
  bool operator ==(Object other) =>
      other is SaveFlashFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class SaveFlashLogic extends ChangeNotifier {
  static const _kPrefSeen = 'saveflash.seen_paths.v1';

  late Directory _saveFlashDir;
  Set<String> _seenPaths = {};

  /// File mới (chưa được xử lý bởi user)
  List<SaveFlashFile> pendingFiles = [];

  bool _initialized = false;

  // ---------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final docs = await getApplicationDocumentsDirectory();
    // Cùng cấp AppMusicVol2
    _saveFlashDir = Directory(p.join(docs.path, 'SaveFlash'));

    if (!await _saveFlashDir.exists()) {
      await _saveFlashDir.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefSeen);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        _seenPaths = Set<String>.from(list);
      } catch (_) {
        _seenPaths = {};
      }
    }
  }

  // ---------------------------------------------------------------
  // SCAN – gọi mỗi khi app resume hoặc sau init
  // Trả về true nếu có file mới để show popup.
  // ---------------------------------------------------------------
  Future<bool> scan() async {
    await init();
    final found = <SaveFlashFile>[];

    await for (final entity
        in _saveFlashDir.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.mp3' && ext != '.m4a') continue;
      if (_seenPaths.contains(entity.path)) continue;

      final stat = await entity.stat();
      found.add(SaveFlashFile(
        path: entity.path,
        name: p.basename(entity.path),
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }

    // Sắp theo modified mới nhất lên đầu
    found.sort((a, b) => b.modified.compareTo(a.modified));
    pendingFiles = found;
    notifyListeners();
    return found.isNotEmpty;
  }

  // ---------------------------------------------------------------
  // Đánh dấu file đã xử lý (dù user nhập playlist hay bỏ qua)
  // ---------------------------------------------------------------
  Future<void> markSeen(List<String> paths) async {
    _seenPaths.addAll(paths);
    pendingFiles.removeWhere((f) => paths.contains(f.path));
    notifyListeners();
    await _persistSeen();
  }

  Future<void> _persistSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefSeen, jsonEncode(_seenPaths.toList()));
  }

  // ---------------------------------------------------------------
  // Đường dẫn thư mục (để UI hiển thị hint)
  // ---------------------------------------------------------------
  String get folderPath {
    if (!_initialized) return 'SaveFlash';
    return _saveFlashDir.path;
  }
}
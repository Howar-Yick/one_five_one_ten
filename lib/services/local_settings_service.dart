import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一个跨平台的键值存储服务。
///
/// - 优先使用 [SharedPreferences]，可覆盖所有支持平台；
/// - 若运行环境缺失对应平台插件（例如 Windows 构建时未正确生成插件注册信息），
///   会自动回退到本地 JSON 文件存储，确保同步模块依旧可用；
/// - 文件位于应用的 Support 目录下，文件名为 `sync_local_state.json`。
class LocalSettingsService {
  LocalSettingsService._();

  static final LocalSettingsService instance = LocalSettingsService._();

  SharedPreferences? _prefs;
  File? _file;
  final Map<String, dynamic> _fileCache = {};

  Future<void>? _initFuture;
  Future<void> _writeSerial = Future.value();

  /// 确保底层存储已准备就绪。
  Future<void> ensureInitialized() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      return;
    } on MissingPluginException {
      // 插件缺失，转到文件存储。
    } catch (_) {
      // 任何异常都视为 SharedPreferences 不可用。
    }
    await _initFileStore();
  }

  Future<void> _initFileStore() async {
    Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }

    final path = '${dir.path}/sync_local_state.json';
    _file = File(path);

    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
      return;
    }

    try {
      final raw = await _file!.readAsString();
      if (raw.trim().isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final k = key is String ? key : key.toString();
          _fileCache[k] = value;
        });
      }
    } catch (e) {
      // 读取失败时备份原文件，避免覆盖用户数据。
      final backupPath = '${path}.bak_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await _file!.copy(backupPath);
      } catch (_) {}
      _fileCache.clear();
      await _flushFile();
    }
  }

  bool get _usePrefs => _prefs != null;

  Future<String?> getString(String key) async {
    await ensureInitialized();
    if (_usePrefs) return _prefs!.getString(key);
    final value = _fileCache[key];
    return value is String ? value : value?.toString();
  }

  Future<bool?> getBool(String key) async {
    await ensureInitialized();
    if (_usePrefs) return _prefs!.getBool(key);
    final value = _fileCache[key];
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return null;
  }

  Future<int?> getInt(String key) async {
    await ensureInitialized();
    if (_usePrefs) return _prefs!.getInt(key);
    final value = _fileCache[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> setString(String key, String value) async {
    await ensureInitialized();
    if (_usePrefs) {
      await _prefs!.setString(key, value);
    } else {
      _fileCache[key] = value;
      await _flushFile();
    }
  }

  Future<void> setBool(String key, bool value) async {
    await ensureInitialized();
    if (_usePrefs) {
      await _prefs!.setBool(key, value);
    } else {
      _fileCache[key] = value;
      await _flushFile();
    }
  }

  Future<void> setInt(String key, int value) async {
    await ensureInitialized();
    if (_usePrefs) {
      await _prefs!.setInt(key, value);
    } else {
      _fileCache[key] = value;
      await _flushFile();
    }
  }

  Future<void> remove(String key) async {
    await ensureInitialized();
    if (_usePrefs) {
      await _prefs!.remove(key);
    } else {
      _fileCache.remove(key);
      await _flushFile();
    }
  }

  Future<void> _flushFile() {
    if (_file == null) return Future.value();
    _writeSerial = _writeSerial.then((_) async {
      try {
        await _file!.writeAsString(json.encode(_fileCache), flush: true);
      } catch (_) {
        // 忽略写入错误，避免同步流程崩溃。
      }
    });
    return _writeSerial;
  }
}

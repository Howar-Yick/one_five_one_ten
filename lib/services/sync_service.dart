import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxh3/xxh3.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/onedrive_service.dart';
import 'package:one_five_one_ten/models/cloud_manifest.dart';
import 'package:isar/isar.dart';

// 引入所有需要监听的模型
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';

class SyncService with WidgetsBindingObserver {
  static const _kLastSyncHash = 'last_sync_hash';
  static const _kLastSyncVersion = 'last_sync_ver'; 
  SyncService._();
  static final instance = SyncService._();

  final _od = OneDriveService();
  final _ds = DatabaseService();

  // 修正：将 _dbSub 替换为 _subs 列表定义
  final List<StreamSubscription<void>> _subs = [];
  Timer? _debounce;
  Timer? _poll;
  bool _syncing = false;
  bool _enabled = true;
  late String _deviceId;

  // 修正：创建一个 _onDbChanged 辅助函数
  void _onDbChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () {
      _safeSync(pushHint: true);
    });
  }

  // 修正：start 方法，改为调用 _startDbWatchers
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    final sp = await SharedPreferences.getInstance();
    _deviceId = sp.getString('device_id') ?? _genAndSaveDeviceId(sp);
    _enabled = sp.getBool('auto_sync_enabled') ?? true;

    if (!_enabled) return;

    // 启动数据库监听
    _startDbWatchers();

    _safeSync();

    _poll?.cancel();
    _poll = Timer.periodic(const Duration(minutes: 30), (_) => _safeSync());
  }

  Future<bool> _uploadSnapshot(String fileName) async {
  final tmp = File('${Directory.systemTemp.path}/ofot_${DateTime.now().millisecondsSinceEpoch}.isar');
  await _ds.isar.copyToFile(tmp.path);
  final bytes = await tmp.readAsBytes();
  await tmp.delete();
  return await _od.uploadBackup(Uint8List.fromList(bytes), fileName);
}

  // 修正：stop 方法，改为调用 _cancelDbWatchers
  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    _cancelDbWatchers(); // 调用正确的辅助函数
    _debounce?.cancel(); _debounce = null;
    _poll?.cancel(); _poll = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _enabled) {
      _safeSync();
    }
  }

  // 修正：添加 _startDbWatchers 方法
  void _startDbWatchers() {
    _cancelDbWatchers();
    final isar = _ds.isar;

    // 使用我们之前确认过的 isar.collection<T>() 这种可靠的方式
    _subs.addAll([
      isar.collection<Account>().watchLazy().listen((_) => _onDbChanged()),
      isar.collection<AccountTransaction>().watchLazy().listen((_) => _onDbChanged()),
      isar.collection<Asset>().watchLazy().listen((_) => _onDbChanged()),
      isar.collection<PositionSnapshot>().watchLazy().listen((_) => _onDbChanged()),
      isar.collection<Transaction>().watchLazy().listen((_) => _onDbChanged()),
    ]);
  }

  // 修正：添加 _cancelDbWatchers 方法
  void _cancelDbWatchers() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  Future<void> _safeSync({bool pushHint = false}) async {
    if (_syncing || !_enabled) return;
    _syncing = true;
    try {
      final pulled = await _pullIfRemoteNewer();
      if (!pulled || pushHint) {
        await _pushIfDirty();
      }
    } catch (_) {
      // 可以写到日志
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _pullIfRemoteNewer() async {
  final m = await _od.getManifest();
  if (m == null) return false;

  final sp = await SharedPreferences.getInstance();
  final baselineHash = sp.getString(_kLastSyncHash);
  final baselineVer  = sp.getInt(_kLastSyncVersion) ?? 0;

  final localHash = await _calcLocalDbHash();
  final remoteHash = m.dbHash;
  final remoteVer  = m.version;

  // 情况 A：本地未改动（等于基线）且云端版本号更高 -> 安全拉取并覆盖
  final localUnchanged = (baselineHash == null) || (localHash == baselineHash);
  if (localUnchanged && remoteVer > baselineVer && remoteHash != localHash) {
    final bytes = await _od.downloadBackupByName(m.fileName);
    if (bytes == null) return false;

    _cancelDbWatchers();
    final path = _ds.isar.path!;
    await _ds.isar.close();
    await File(path).writeAsBytes(bytes, flush: true);
    await DatabaseService().init();
    _startDbWatchers();

    await sp.setString(_kLastSyncHash, remoteHash);
    await sp.setInt(_kLastSyncVersion, remoteVer);
    return true;
  }

  // 情况 B：两端都改动（本地 != 基线 且 云端版本 > 基线）-> 冲突：不覆盖云端，上传一个本地冲突副本
  final localChanged = (baselineHash != null) && (localHash != baselineHash);
  final remoteAdvanced = remoteVer > baselineVer;
  final remoteChangedFromBaseline = (remoteHash != baselineHash) || remoteAdvanced;
  if (localChanged && remoteChangedFromBaseline) {
    final conflictName =
        'backup_conflict_${_deviceId}_${DateTime.now().toUtc().toIso8601String().replaceAll(':','-')}.isar';
    await _uploadSnapshot(conflictName);
    // 提示：可以在 UI 上给出“检测到冲突，已将本地另存为冲突快照”的 SnackBar
    return false;
  }

  // 其他情况：不需要拉
  return false;
}

  Future<void> _pushIfDirty() async {
    final sp = await SharedPreferences.getInstance();
    final m = await _od.getManifest();
    final baselineHash = sp.getString(_kLastSyncHash);
    final baselineVer  = sp.getInt(_kLastSyncVersion) ?? 0;

    final localHash = await _calcLocalDbHash();

    // 本地与云端完全一致 -> 基线同步修正即可
    if (m != null && localHash == m.dbHash) {
      if (localHash != baselineHash) {
        await sp.setString(_kLastSyncHash, localHash);
        await sp.setInt(_kLastSyncVersion, m.version);
      }
      return;
    }

    // 只有在“云端仍处于基线版本（或 manifest 不存在）”时，才安全推
    final canPush = (m == null) || (m.version == baselineVer && m.dbHash == baselineHash);
    if (!canPush) {
      // 云端比基线新，先给 _pullIfRemoteNewer 处理（含冲突检测）
      return;
    }

    // 安全推送：上传快照 + bump manifest 版本
    final fileName = 'backup_${DateTime.now().toUtc().toIso8601String().replaceAll(':','-')}.isar';
    final ok = await _uploadSnapshot(fileName);
    if (!ok) return;

    final newM = CloudManifest(
      version: (m?.version ?? 0) + 1,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      deviceId: _deviceId,
      dbHash: localHash,
      fileName: fileName,
    );
    await _od.putManifest(newM);

    await sp.setString(_kLastSyncHash, localHash);
    await sp.setInt(_kLastSyncVersion, newM.version);
  }

  Future<String> _calcLocalDbHash() async {
    final path = _ds.isar.path!;
    final bytes = await File(path).readAsBytes();
    final h = xxh3(bytes);
    return h.toRadixString(16);
  }

  Future<DateTime?> _readLocalUpdatedUtc() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('db_last_utc');
    return s == null ? null : DateTime.tryParse(s)?.toUtc();
  }

  String _genAndSaveDeviceId(SharedPreferences sp) {
    final id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000+DateTime.now().microsecond%9000)}';
    sp.setString('device_id', id);
    return id;
  }

  Future<void> setEnabled(bool enabled, {bool triggerSync = true}) async {
    final sp = await SharedPreferences.getInstance();
    _enabled = enabled;
    await sp.setBool('auto_sync_enabled', enabled);
    if (enabled) {
      await start();
      if(triggerSync) _safeSync();
    } else {
      await stop();
    }
  }
  
  Future<bool> isEnabled() async {
     final sp = await SharedPreferences.getInstance();
    _enabled = sp.getBool('auto_sync_enabled') ?? true;
    return _enabled;
  }
}
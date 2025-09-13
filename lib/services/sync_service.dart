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

    final localHash = await _calcLocalDbHash();
    if (localHash == m.dbHash) return false;

    final remoteTime = DateTime.tryParse(m.updatedAtUtc)?.toUtc();
    final localTime = await _readLocalUpdatedUtc();
    if (remoteTime == null) return false;

    if (localTime == null || remoteTime.isAfter(localTime)) {
      final latest = await _od.downloadLatestBackup();
      if (latest == null) return false;
      final (_, bytes) = latest;

      final path = _ds.isar.path!;
      
      // 关键：在关闭前，取消所有数据库监听
      _cancelDbWatchers();
      await _ds.isar.close();
      
      await File(path).writeAsBytes(bytes, flush: true);

      // 使用 DatabaseService().init() 重开数据库
      await DatabaseService().init();

      // 重开库后必须重新挂载监听
      _startDbWatchers();

      final sp = await SharedPreferences.getInstance();
      await sp.setString('db_last_utc', remoteTime.toIso8601String());
      await sp.setString('db_last_hash', m.dbHash);
      return true;
    }
    return false;
  }

  Future<void> _pushIfDirty() async {
    final sp = await SharedPreferences.getInstance();
    final localHash = await _calcLocalDbHash();
    final lastHash = sp.getString('db_last_hash');

    if (lastHash == localHash) return;

    final tmp = File('${Directory.systemTemp.path}/ofot_${DateTime.now().millisecondsSinceEpoch}.isar');
    await _ds.isar.copyToFile(tmp.path);
    final bytes = await tmp.readAsBytes();
    await tmp.delete();

    final fileName = 'backup_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.isar';
    final ok = await _od.uploadBackup(Uint8List.fromList(bytes), fileName);
    if (!ok) return;

    final manifest = CloudManifest(
      version: ((await _od.getManifest())?.version ?? 0) + 1,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      deviceId: _deviceId,
      dbHash: localHash,
      fileName: fileName,
    );
    await _od.putManifest(manifest);

    await sp.setString('db_last_hash', localHash);
    await sp.setString('db_last_utc', manifest.updatedAtUtc);
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
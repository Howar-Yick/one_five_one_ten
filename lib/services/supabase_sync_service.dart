// File: lib/services/supabase_sync_service.dart
// Version: CHATGPT-1.07-20251015-SNAPSHOT-TIMESTAMP
//
// 变更要点：
// 1) 把 PositionSnapshot / AccountTransaction / Transaction 的 date 统一视为“事件时间（含时分秒）”。
//    - 保存：使用本地时刻（若仅选了日期则与当前本地时间合并），再 toUtc() 入库；
//    - 读取：fromSupabase 后统一 toLocal() 展示与排序；
// 2) 仍保留 deletions 墓碑表、全量校准(LWW)、Realtime 监听与竞态处理；
// 3) 其他时间戳（updatedAt）保持：入库 toUtc()，读取 toLocal()。

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/services/database_service.dart';

// 模型
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/deletion.dart';

// 全局 Supabase
import 'package:one_five_one_ten/main.dart';

class SupabaseSyncService {
  final Isar _isar = DatabaseService().isar;
  final SupabaseClient _client = supabase;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  RealtimeChannel? _realtimeChannel;

  // ========= 时间工具 =========

  /// 一般时间戳：入库 UTC
  DateTime _toSupaTs(DateTime dt) => dt.toUtc();

  /// 一般时间戳：出库本地
  DateTime _fromSupaTs(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

  /// 当 UI 只给出“日期（零点）”时，把“当前本地时间的时分秒”合并进来，形成“当天该时刻”的本地时间
  DateTime _mergeLocalDateWithNowTime(DateTime localPickedDate) {
    final now = DateTime.now();
    final isZeroTime = localPickedDate.hour == 0 &&
        localPickedDate.minute == 0 &&
        localPickedDate.second == 0 &&
        localPickedDate.millisecond == 0 &&
        localPickedDate.microsecond == 0;
    if (!isZeroTime) return localPickedDate;
    return DateTime(
      localPickedDate.year,
      localPickedDate.month,
      localPickedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  /// “事件时间（含时分秒）”入库：保证有本地时刻，再转 UTC
  DateTime _eventDateToSupa(DateTime localDateOrDateTime) =>
      _toSupaTs(_mergeLocalDateWithNowTime(localDateOrDateTime));

  // ========= 认证 =========
  Future<User?> signUp(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    if (res.user != null) {
      await startSync();
    }
    return res.user;
  }

  Future<User?> login(String email, String password) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user != null) {
      await startSync();
    }
    return res.user;
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    stopSync();
  }

  Future<void> checkLoginAndStartSync() async {
    _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        stopSync();
      } else if (data.event == AuthChangeEvent.signedIn) {
        if (_realtimeChannel == null) {
          startSync();
        }
      }
    });

    if (isLoggedIn) {
      await startSync();
    }
  }

  // ========= 同步控制 =========
  Future<void> startSync() async {
    if (!isLoggedIn || _realtimeChannel != null) return;

    print('启动同步服务...');

    await _fullInitialSync();

    print('全量同步完成。正在启动实时侦听器...');

    _realtimeChannel = _client.channel('public_tables_channel');
    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: _onCloudChange,
        )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Supabase Realtime 已连接!');
      }
      if (error != null) {
        print('Supabase Realtime 错误: $error');
      }
    });
  }

  void stopSync() {
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      print('Supabase Realtime 已断开');
    }
  }

  // ========= 启动全量同步 =========
  Future<void> _fullInitialSync() async {
    try {
      await _syncDeletions();

      await _reconcileTable<Account>('Account', _isar.accounts, Account.fromSupabaseJson);
      await _reconcileTable<Asset>('Asset', _isar.assets, Asset.fromSupabaseJson);
      await _reconcileTable<Transaction>('Transaction', _isar.transactions, Transaction.fromSupabaseJson);
      await _reconcileTable<AccountTransaction>('AccountTransaction', _isar.accountTransactions, AccountTransaction.fromSupabaseJson);
      await _syncPositionSnapshotsFromRemote();
    } catch (e) {
      print('首次全量同步失败: $e');
    }
  }

  /// PositionSnapshot 的专用同步：
  /// - 采用分页拉取，避免 >1000 记录被截断；
  /// - 仅做 UPSERT，不因远端缺少记录而删除本地，防止多端互相覆盖。
  Future<void> _syncPositionSnapshotsFromRemote() async {
    print('[SupabaseSync] Reconciling table with paging: PositionSnapshot');

    const batchSize = 500;
    int offset = 0;

    while (true) {
      final response = await _client
          .from('PositionSnapshot')
          .select()
          .order('created_at', ascending: true)
          .range(offset, offset + batchSize - 1);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        break;
      }

      await _isar.writeTxn(() async {
        for (final raw in data) {
          final snap = PositionSnapshot.fromSupabaseJson(raw as Map<String, dynamic>);

          // 统一时间为本地显示
          snap.date = _fromSupaTs(snap.date);
          if (snap.updatedAt != null) snap.updatedAt = _fromSupaTs(snap.updatedAt!);

          // UPSERT：存在则沿用本地 id 更新；不存在则插入
          final existing = await _isar.positionSnapshots.where().supabaseIdEqualTo(snap.supabaseId).findFirst();
          if (existing != null) {
            snap.id = existing.id;
          }

          await _isar.positionSnapshots.put(snap);
        }
      });

      if (data.length < batchSize) {
        break;
      }
      offset += batchSize;
    }

    print('[SupabaseSync] PositionSnapshot paging sync completed');
  }

  // ========= 删除记录同步（墓碑表） =========
  Future<void> _syncDeletions() async {
    final lastDeletion = await _isar.deletions.where().sortByDeletedAtDesc().findFirst();
    final base = lastDeletion?.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final lastDeletionTimeUtc = _toSupaTs(base);

    final deletionsResponse = await _client
        .from('deletions')
        .select()
        .gte('deleted_at', lastDeletionTimeUtc.toIso8601String());

    if (deletionsResponse.isEmpty) return;

    print('[SupabaseSync] Fetched ${deletionsResponse.length} new deletion records.');

    await _isar.writeTxn(() async {
      for (final deletionData in (deletionsResponse as List<dynamic>)) {
        final raw = deletionData['deleted_at'] as String;
        DateTime parsed = DateTime.parse(raw);
        if (!parsed.isUtc) parsed = DateTime.parse('${raw}Z');
        final localDeletedAt = _fromSupaTs(parsed);

        final deletion = Deletion()
          ..tableName = deletionData['table_name']
          ..deletedRecordId = deletionData['deleted_record_id']
          ..deletedAt = localDeletedAt;

        final supabaseId = deletion.deletedRecordId;
        switch (deletion.tableName) {
          case 'Account':
            await _isar.accounts.where().supabaseIdEqualTo(supabaseId).deleteAll();
            break;
          case 'Asset':
            await _isar.assets.where().supabaseIdEqualTo(supabaseId).deleteAll();
            break;
          case 'Transaction':
            await _isar.transactions.where().supabaseIdEqualTo(supabaseId).deleteAll();
            break;
          case 'AccountTransaction':
            await _isar.accountTransactions.where().supabaseIdEqualTo(supabaseId).deleteAll();
            break;
          case 'PositionSnapshot':
            await _isar.positionSnapshots.where().supabaseIdEqualTo(supabaseId).deleteAll();
            break;
        }
        await _isar.deletions.put(deletion);
      }
    });
  }

  // ========= 通用全量校准（LWW） =========
  Future<void> _reconcileTable<T>(
    String tableName,
    IsarCollection<T> isarCollection,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    print('[SupabaseSync] Reconciling table: $tableName');

    final remoteResponse = await _client.from(tableName).select();
    final List<T> remoteItems = (remoteResponse as List<dynamic>)
        .map((doc) => fromJson(doc as Map<String, dynamic>))
        .toList();

    // —— 统一时间字段 —— //
    for (final item in remoteItems) {
      final dyn = item as dynamic;

      // updatedAt：本地展示
      final ua = dyn.updatedAt;
      if (ua is DateTime) dyn.updatedAt = _fromSupaTs(ua);

      // 事件时间：本地展示与排序
      if (item is PositionSnapshot) {
        item.date = _fromSupaTs(item.date);
      }
      if (item is AccountTransaction) {
        try { item.date = _fromSupaTs(item.date); } catch (_) {}
      }
      if (item is Transaction) {
        if (item.date is DateTime) {
          item.date = _fromSupaTs(item.date);
        }
      }
    }

    final remoteSupabaseIds = remoteItems.map((e) => (e as dynamic).supabaseId as String?).toSet();
    final localItems = await isarCollection.where().findAll();
    final localItemsMap = {for (var item in localItems) (item as dynamic).supabaseId: item};

    final List<Id> isarIdsToDelete = [];
    for (final localItem in localItems) {
      final supabaseId = (localItem as dynamic).supabaseId;
      if (supabaseId != null && !remoteSupabaseIds.contains(supabaseId)) {
        isarIdsToDelete.add((localItem as dynamic).id);
      }
    }

    await _isar.writeTxn(() async {
      if (isarIdsToDelete.isNotEmpty) {
        await isarCollection.deleteAll(isarIdsToDelete);
        print('[SupabaseSync] Deleted ${isarIdsToDelete.length} stale local records from $tableName.');
      }

      for (final remoteItem in remoteItems) {
        final remoteSupabaseId = (remoteItem as dynamic).supabaseId;
        final localItem = localItemsMap[remoteSupabaseId];
        await _performLWWPut(localItem, remoteItem, isarCollection);
      }
    });
  }

  // ========= Realtime 变更处理 =========
  Future<void> _onCloudChange(PostgresChangePayload payload) async {
    final eventType = payload.eventType;
    final tableName = payload.table;

    try {
      if (tableName == 'deletions' && eventType == PostgresChangeEvent.insert) {
        final deletionData = payload.newRecord;
        final supabaseId = deletionData['deleted_record_id'] as String?;
        final targetTable = deletionData['table_name'] as String?;
        if (supabaseId != null && targetTable != null) {
          print('[SupabaseSync] Realtime event: DELETION on $targetTable / $supabaseId');
          await _handleDelete(supabaseId, targetTable);
        }
      } else if (eventType == PostgresChangeEvent.insert || eventType == PostgresChangeEvent.update) {
        final remoteData = payload.newRecord;
        await _handleUpsert(remoteData, tableName);
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldData = payload.oldRecord;
        final supabaseId = (oldData as Map<String, dynamic>?)?['id'] as String?;
        if (supabaseId != null) {
          await _handleDelete(supabaseId, tableName);
        }
      }
    } catch (e) {
      print('处理实时变更失败 ($tableName): $e');
    }
  }

  Future<void> _handleUpsert(Map<String, dynamic> remoteData, String tableName) async {
    print('[SupabaseSync] Realtime event: $tableName / ${remoteData['id']} -> processing...');

    await _isar.writeTxn(() async {
      try {
        switch (tableName) {
          case 'Account': {
            final remoteItem = Account.fromSupabaseJson(remoteData);
            final localItem = await _isar.accounts.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            if (remoteItem.updatedAt != null) remoteItem.updatedAt = _fromSupaTs(remoteItem.updatedAt!);
            await _performLWWPut(localItem, remoteItem, _isar.accounts);
            break;
          }
          case 'Asset': {
            final remoteItem = Asset.fromSupabaseJson(remoteData);
            final localItem = await _isar.assets.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            if (remoteItem.updatedAt != null) remoteItem.updatedAt = _fromSupaTs(remoteItem.updatedAt!);
            await _performLWWPut(localItem, remoteItem, _isar.assets);
            break;
          }
          case 'Transaction': {
            final remoteItem = Transaction.fromSupabaseJson(remoteData);
            final localItem = await _isar.transactions.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            if (remoteItem.updatedAt != null) remoteItem.updatedAt = _fromSupaTs(remoteItem.updatedAt!);
            if (remoteItem.date is DateTime) {
              remoteItem.date = _fromSupaTs(remoteItem.date);
            }
            await _performLWWPut(localItem, remoteItem, _isar.transactions);
            break;
          }
          case 'AccountTransaction': {
            final remoteItem = AccountTransaction.fromSupabaseJson(remoteData);
            final localItem = await _isar.accountTransactions.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            if (remoteItem.updatedAt != null) remoteItem.updatedAt = _fromSupaTs(remoteItem.updatedAt!);
            try { remoteItem.date = _fromSupaTs(remoteItem.date); } catch (_) {}
            await _performLWWPut(localItem, remoteItem, _isar.accountTransactions);
            break;
          }
          case 'PositionSnapshot': {
            final remoteItem = PositionSnapshot.fromSupabaseJson(remoteData);
            final localItem = await _isar.positionSnapshots.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            remoteItem.date = _fromSupaTs(remoteItem.date);
            if (remoteItem.updatedAt != null) remoteItem.updatedAt = _fromSupaTs(remoteItem.updatedAt!);
            await _performLWWPut(localItem, remoteItem, _isar.positionSnapshots);
            break;
          }
        }
        print('[SupabaseSync] Realtime event: $tableName / ${remoteData['id']} -> processed successfully');
      } catch (e) {
        print('[SupabaseSync] Realtime event: $tableName / ${remoteData['id']} -> failed: $e');
      }
    });
  }

  Future<void> _handleDelete(String supabaseId, String tableName) async {
    await _isar.writeTxn(() async {
      switch (tableName) {
        case 'Account':
          await _isar.accounts.where().supabaseIdEqualTo(supabaseId).deleteAll();
          break;
        case 'Asset':
          await _isar.assets.where().supabaseIdEqualTo(supabaseId).deleteAll();
          break;
        case 'Transaction':
          await _isar.transactions.where().supabaseIdEqualTo(supabaseId).deleteAll();
          break;
        case 'AccountTransaction':
          await _isar.accountTransactions.where().supabaseIdEqualTo(supabaseId).deleteAll();
          break;
        case 'PositionSnapshot':
          await _isar.positionSnapshots.where().supabaseIdEqualTo(supabaseId).deleteAll();
          break;
      }
    });
  }

  // ========= LWW 写入 =========
  Future<void> _performLWWPut<T>(
    T? localItem,
    T remoteItem,
    IsarCollection<T> collection,
  ) async {
    final remoteUpdatedAt = (remoteItem as dynamic).updatedAt as DateTime?;
    final remoteSupabaseId = (remoteItem as dynamic).supabaseId as String?;
    final remoteUpdatedAtUtc = remoteUpdatedAt?.toUtc();

    if (localItem == null) {
      try {
        await collection.put(remoteItem);
        print('[SupabaseSync] LWW: Created new local record for $remoteSupabaseId');
      } catch (e) {
        if (e.toString().contains('Unique index violated')) {
          print('[SupabaseSync] LWW: Unique constraint violated for $remoteSupabaseId - ignoring (likely race condition)');
          return;
        }
        rethrow;
      }
    } else {
      final localUpdatedAt = (localItem as dynamic).updatedAt as DateTime?;
      final localUpdatedAtUtc = localUpdatedAt?.toUtc();

      final shouldUpdate = (localUpdatedAtUtc == null && remoteUpdatedAtUtc != null)
          || (remoteUpdatedAtUtc != null && localUpdatedAtUtc != null && remoteUpdatedAtUtc.isAfter(localUpdatedAtUtc));

      if (shouldUpdate) {
        (remoteItem as dynamic).id = (localItem as dynamic).id;
        await collection.put(remoteItem);
        print('[SupabaseSync] LWW: Updated local record for $remoteSupabaseId');
      } else {
        print('[SupabaseSync] LWW: Skipped update for $remoteSupabaseId (local newer or equal)');
      }
    }
  }

  Future<void> _saveWithRaceConditionHandling<T>(
    T definitiveItem,
    Id isarId,
    String? definitiveSupaId,
    T isarObject,
    IsarCollection<T> isarCollection,
  ) async {
    bool saveSuccessful = false;
    int retryCount = 0;
    const maxRetries = 3;

    while (!saveSuccessful && retryCount < maxRetries) {
      try {
        await _isar.writeTxn(() => isarCollection.put(definitiveItem));
        saveSuccessful = true;
        print('[SupabaseSync] Successfully saved with ID $isarId (attempt ${retryCount + 1})');
        break;
      } catch (e) {
        retryCount++;

        if (e.toString().contains('Unique index violated') && definitiveSupaId != null) {
          print('[SupabaseSync] Race condition detected (attempt $retryCount) for $definitiveSupaId, cleaning up...');

          dynamic duplicateFromListener;
          if (isarObject is Account) {
            duplicateFromListener = await _isar.accounts.where().supabaseIdEqualTo(definitiveSupaId).filter().not().idEqualTo(isarId).findFirst();
          } else if (isarObject is Asset) {
            duplicateFromListener = await _isar.assets.where().supabaseIdEqualTo(definitiveSupaId).filter().not().idEqualTo(isarId).findFirst();
          } else if (isarObject is Transaction) {
            duplicateFromListener = await _isar.transactions.where().supabaseIdEqualTo(definitiveSupaId).filter().not().idEqualTo(isarId).findFirst();
          } else if (isarObject is AccountTransaction) {
            duplicateFromListener = await _isar.accountTransactions.where().supabaseIdEqualTo(definitiveSupaId).filter().not().idEqualTo(isarId).findFirst();
          } else if (isarObject is PositionSnapshot) {
            duplicateFromListener = await _isar.positionSnapshots.where().supabaseIdEqualTo(definitiveSupaId).filter().not().idEqualTo(isarId).findFirst();
          }

          if (duplicateFromListener != null) {
            print('[SupabaseSync] Found duplicate record with ID ${(duplicateFromListener as dynamic).id}, deleting...');
            await _isar.writeTxn(() => isarCollection.delete((duplicateFromListener as dynamic).id));
            print('[SupabaseSync] Deleted duplicate record, retrying save...');
          } else {
            print('[SupabaseSync] No duplicate found but unique constraint violated. Breaking.');
            break;
          }
        } else {
          rethrow;
        }
      }
    }

    if (!saveSuccessful) {
      throw Exception('Failed to save after $maxRetries attempts due to race conditions');
    }
  }

  // ========= Push / 写入 API =========
  Future<void> _saveObject<T>(
    String tableName,
    T isarObject,
    IsarCollection<T> isarCollection,
    dynamic fromSupabaseJson,
  ) async {
    if (!isLoggedIn) throw Exception("未登录");

    // —— 强制更新时间戳（UTC） —— //
    (isarObject as dynamic).updatedAt = _toSupaTs(DateTime.now());

    // —— 事件时间字段：保存前统一归一（本地→合并时分秒→UTC） —— //
    if (isarObject is PositionSnapshot) {
      isarObject.date = _eventDateToSupa(isarObject.date);
    }
    if (isarObject is AccountTransaction) {
      try { isarObject.date = _eventDateToSupa(isarObject.date); } catch (_) {}
    }
    if (isarObject is Transaction) {
      isarObject.date = _eventDateToSupa(isarObject.date);
    }

    // 先写入本地（含新时间）
    await _isar.writeTxn(() => isarCollection.put(isarObject));

    // 准备上行数据
    final jsonData = (isarObject as dynamic).toSupabaseJson();

    // 兜底 updated_at 字段为 UTC 字符串
    if (jsonData.containsKey('updated_at') && jsonData['updated_at'] is String == false) {
      final ua = (isarObject as dynamic).updatedAt as DateTime?;
      if (ua != null) jsonData['updated_at'] = ua.toUtc().toIso8601String();
    }
    // 兜底事件 date 字段为 UTC 字符串（如果模型的 toSupabaseJson 未做处理）
    void _ensureUtcText(String key, DateTime value) {
      if (jsonData.containsKey(key)) {
        jsonData[key] = value.toUtc().toIso8601String();
      }
    }
    if (isarObject is PositionSnapshot) {
      _ensureUtcText('date', isarObject.date);
    }
    if (isarObject is AccountTransaction) {
      try { _ensureUtcText('date', isarObject.date); } catch (_) {}
    }
    if (isarObject is Transaction) {
      _ensureUtcText('date', isarObject.date);
    }

    final isarId = (isarObject as dynamic).id;
    final supabaseId = (isarObject as dynamic).supabaseId as String?;
    if (isarId == null) {
      throw Exception("SaveObject 失败: 对象的 Isar ID 为 null。");
    }
    if (supabaseId != null) {
      jsonData['id'] = supabaseId;
    }

    try {
      final response = await _client.from(tableName).upsert(jsonData).select();
      if (response.isEmpty) {
        throw Exception('Upsert 成功，但 RLS 策略阻止了 SELECT 返回数据。');
      }

      final savedData = response.first as Map<String, dynamic>;
      final definitiveItem = fromSupabaseJson(savedData) as T;
      final definitiveSupaId = (definitiveItem as dynamic).supabaseId as String?;

      // 读回：统一时间（事件时间 toLocal）
      final dyn = definitiveItem as dynamic;
      final ua = dyn.updatedAt;
      if (ua is DateTime) dyn.updatedAt = _fromSupaTs(ua);

      if (definitiveItem is PositionSnapshot) {
        definitiveItem.date = _fromSupaTs(definitiveItem.date);
      }
      if (definitiveItem is AccountTransaction) {
        try { definitiveItem.date = _fromSupaTs(definitiveItem.date); } catch (_) {}
      }
      if (definitiveItem is Transaction) {
        definitiveItem.date = _fromSupaTs(definitiveItem.date);
      }

      (definitiveItem as dynamic).id = isarId;

      await _saveWithRaceConditionHandling(
        definitiveItem,
        isarId,
        definitiveSupaId,
        isarObject,
        isarCollection,
      );
    } catch (e) {
      print('Supabase Save ($tableName) 失败: $e');
      rethrow;
    }
  }

  Future<void> _deleteObject<T>(
    String tableName,
    T isarObject,
    IsarCollection<T> isarCollection,
  ) async {
    if (!isLoggedIn) return;

    final supabaseId = (isarObject as dynamic).supabaseId as String?;
    final isarId = (isarObject as dynamic).id as Id;

    await _isar.writeTxn(() => isarCollection.delete(isarId));

    if (supabaseId == null) {
      return;
    }

    try {
      await _client.from('deletions').insert({
        'table_name': tableName,
        'deleted_record_id': supabaseId,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _client.from(tableName).delete().eq('id', supabaseId);

      print('[SupabaseSync] Successfully deleted and logged tombstone for $tableName/$supabaseId');
    } catch (e) {
      print('Supabase Delete ($tableName) 失败: $e');
      // TODO: 离线删除队列
    }
  }

  // ========= 对外保存/删除接口（签名不变） =========
  Future<void> saveAccount(Account acc) => _saveObject(
        'Account',
        acc,
        _isar.accounts,
        (json) => Account.fromSupabaseJson(json as Map<String, dynamic>),
      );

  Future<void> deleteAccount(Account acc) =>
      _deleteObject('Account', acc, _isar.accounts);

  Future<void> saveAsset(Asset asset) => _saveObject(
        'Asset',
        asset,
        _isar.assets,
        (json) => Asset.fromSupabaseJson(json as Map<String, dynamic>),
      );

  Future<void> deleteAsset(Asset asset) =>
      _deleteObject('Asset', asset, _isar.assets);

  Future<void> saveTransaction(Transaction tx) => _saveObject(
        'Transaction',
        tx,
        _isar.transactions,
        (json) => Transaction.fromSupabaseJson(json as Map<String, dynamic>),
      );

  Future<void> deleteTransaction(Transaction tx) =>
      _deleteObject('Transaction', tx, _isar.transactions);

  Future<void> saveAccountTransaction(AccountTransaction tx) => _saveObject(
        'AccountTransaction',
        tx,
        _isar.accountTransactions,
        (json) => AccountTransaction.fromSupabaseJson(json as Map<String, dynamic>),
      );

  Future<void> deleteAccountTransaction(AccountTransaction tx) =>
      _deleteObject('AccountTransaction', tx, _isar.accountTransactions);

  Future<void> savePositionSnapshot(PositionSnapshot snap) => _saveObject(
        'PositionSnapshot',
        snap,
        _isar.positionSnapshots,
        (json) => PositionSnapshot.fromSupabaseJson(json as Map<String, dynamic>),
      );

  Future<void> deletePositionSnapshot(PositionSnapshot snap) =>
      _deleteObject('PositionSnapshot', snap, _isar.positionSnapshots);
}

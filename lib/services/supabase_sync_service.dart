// 文件: lib/services/supabase_sync_service.dart
// (这是完整、已修复的文件代码)

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/services/database_service.dart';

// 导入所有需要同步的模型
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';

// 从 main.dart 导入全局 supabase 客户端
import 'package:one_five_one_ten/main.dart'; 


class SupabaseSyncService {
  final Isar _isar = DatabaseService().isar;
  // 我们使用在 main.dart 中定义的全局客户端
  final SupabaseClient _client = supabase; 

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // 用于保存我们的实时侦听器
  RealtimeChannel? _realtimeChannel;

  // --- 认证 ---
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

  // --- 同步控制 ---
  Future<void> startSync() async {
    if (!isLoggedIn || _realtimeChannel != null) return; 

    print('启动同步服务...');

    // --- 1. 同步首次拉取 (Fetch on Start) ---
    await _isar.writeTxn(() async {
      try {
        // --- 1.1 拉取 Accounts ---
        final accResponse = await _client.from('Account').select();
        for (final doc in (accResponse as List<dynamic>)) {
          final remoteItem = Account.fromSupabaseJson(doc as Map<String, dynamic>);
          final localItem = await _isar.accounts.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
          await _performLWWPut(localItem, remoteItem, _isar.accounts);
        }
        
        // --- 1.2 拉取 Assets ---
        final assetResponse = await _client.from('Asset').select();
        for (final doc in (assetResponse as List<dynamic>)) {
          final remoteItem = Asset.fromSupabaseJson(doc as Map<String, dynamic>);
          final localItem = await _isar.assets.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
          await _performLWWPut(localItem, remoteItem, _isar.assets);
        }

        // --- 1.3 拉取 Transactions ---
        final txResponse = await _client.from('Transaction').select();
        for (final doc in (txResponse as List<dynamic>)) {
          final remoteItem = Transaction.fromSupabaseJson(doc as Map<String, dynamic>);
          final localItem = await _isar.transactions.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
          await _performLWWPut(localItem, remoteItem, _isar.transactions);
        }

        // --- 1.4 拉取 AccountTransactions ---
        final accTxResponse = await _client.from('AccountTransaction').select();
        for (final doc in (accTxResponse as List<dynamic>)) {
          final remoteItem = AccountTransaction.fromSupabaseJson(doc as Map<String, dynamic>);
          final localItem = await _isar.accountTransactions.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
          await _performLWWPut(localItem, remoteItem, _isar.accountTransactions);
        }

        // --- 1.5 拉取 PositionSnapshots ---
        final snapResponse = await _client.from('PositionSnapshot').select();
        for (final doc in (snapResponse as List<dynamic>)) {
          final remoteItem = PositionSnapshot.fromSupabaseJson(doc as Map<String, dynamic>);
          final localItem = await _isar.positionSnapshots.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
          await _performLWWPut(localItem, remoteItem, _isar.positionSnapshots);
        }

      } catch (e) {
        print('首次全量拉取失败: $e');
      }
    });

    print('全量拉取完成。正在启动实时侦听器...');
    
    // --- 2. 订阅实时变化 (Realtime) ---
    _realtimeChannel = _client.channel('public_tables_channel'); 
    _realtimeChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all, 
        schema: 'public',
        callback: _onCloudChange      
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

  // --- 内部：拉取 (Pull) / 侦听回调 ---
  Future<void> _onCloudChange(PostgresChangePayload payload) async { 
    final eventType = payload.eventType;
    final tableName = payload.table;
    
    try {
      if (eventType == PostgresChangeEvent.insert || eventType == PostgresChangeEvent.update) {
        final remoteData = payload.newRecord;
        await _handleUpsert(remoteData, tableName);
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldData = payload.oldRecord;
        final supabaseId = oldData['id'] as String?;
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
          case 'Account':
            final remoteItem = Account.fromSupabaseJson(remoteData);
            final localItem = await _isar.accounts.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            await _performLWWPut(localItem, remoteItem, _isar.accounts);
            break;
          case 'Asset':
            final remoteItem = Asset.fromSupabaseJson(remoteData);
            final localItem = await _isar.assets.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            await _performLWWPut(localItem, remoteItem, _isar.assets);
            break;
          case 'Transaction':
            final remoteItem = Transaction.fromSupabaseJson(remoteData);
            final localItem = await _isar.transactions.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            await _performLWWPut(localItem, remoteItem, _isar.transactions);
            break;
          case 'AccountTransaction':
            final remoteItem = AccountTransaction.fromSupabaseJson(remoteData);
            final localItem = await _isar.accountTransactions.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            await _performLWWPut(localItem, remoteItem, _isar.accountTransactions);
            break;
          case 'PositionSnapshot':
            final remoteItem = PositionSnapshot.fromSupabaseJson(remoteData);
            final localItem = await _isar.positionSnapshots.where().supabaseIdEqualTo(remoteItem.supabaseId).findFirst();
            await _performLWWPut(localItem, remoteItem, _isar.positionSnapshots);
            break;
        }
        print('[SupabaseSync] Realtime event: $tableName / ${remoteData['id']} -> processed successfully');
      } catch (e) {
        print('[SupabaseSync] Realtime event: $tableName / ${remoteData['id']} -> failed: $e');
        // 不重新抛出错误，避免中断实时监听器
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

  /// 辅助方法：执行 Last-Write-Wins (LWW) 逻辑并写入 Isar
  Future<void> _performLWWPut<T>(T? localItem, T remoteItem, IsarCollection<T> collection) async {
    final remoteUpdatedAt = (remoteItem as dynamic).updatedAt as DateTime?;
    final remoteSupabaseId = (remoteItem as dynamic).supabaseId as String?;

    if (localItem == null) {
      // 本地不存在，直接写入
      try {
        await collection.put(remoteItem);
        print('[SupabaseSync] LWW: Created new local record for $remoteSupabaseId');
      } catch (e) {
        if (e.toString().contains('Unique index violated')) {
          print('[SupabaseSync] LWW: Unique constraint violated for $remoteSupabaseId - ignoring (likely race condition)');
          // 忽略这个错误，可能是并发创建导致的
          return;
        }
        rethrow;
      }
    } else {
      final localUpdatedAt = (localItem as dynamic).updatedAt as DateTime?;
      // 远端版本较新，或者本地没有时间戳，就覆盖本地
      if (localUpdatedAt == null || (remoteUpdatedAt != null && remoteUpdatedAt.isAfter(localUpdatedAt))) {
        (remoteItem as dynamic).id = (localItem as dynamic).id; // 关键：保留本地的 Isar Id
        await collection.put(remoteItem);
        print('[SupabaseSync] LWW: Updated local record for $remoteSupabaseId');
      } else {
        print('[SupabaseSync] LWW: Skipped update for $remoteSupabaseId (local newer or equal)');
      }
      // else: 本地版本较新或相同，忽略
    }
  }

  /// 通用的保存方法 - 处理竞态条件的关键逻辑
  Future<void> _saveWithRaceConditionHandling<T>(
    T definitiveItem,
    Id isarId,
    String? definitiveSupaId,
    T isarObject,
    IsarCollection<T> isarCollection
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
          
          // 找到并删除监听器创建的重复记录
          dynamic duplicateFromListener;
          if (isarObject is Account) {
            duplicateFromListener = await _isar.accounts
                .where()
                .supabaseIdEqualTo(definitiveSupaId)
                .filter()
                .not()
                .idEqualTo(isarId)
                .findFirst();
          } else if (isarObject is Asset) {
            duplicateFromListener = await _isar.assets
                .where()
                .supabaseIdEqualTo(definitiveSupaId)
                .filter()
                .not()
                .idEqualTo(isarId)
                .findFirst();
          } else if (isarObject is Transaction) {
            duplicateFromListener = await _isar.transactions
                .where()
                .supabaseIdEqualTo(definitiveSupaId)
                .filter()
                .not()
                .idEqualTo(isarId)
                .findFirst();
          } else if (isarObject is AccountTransaction) {
            duplicateFromListener = await _isar.accountTransactions
                .where()
                .supabaseIdEqualTo(definitiveSupaId)
                .filter()
                .not()
                .idEqualTo(isarId)
                .findFirst();
          } else if (isarObject is PositionSnapshot) {
            duplicateFromListener = await _isar.positionSnapshots
                .where()
                .supabaseIdEqualTo(definitiveSupaId)
                .filter()
                .not()
                .idEqualTo(isarId)
                .findFirst();
          }

          if (duplicateFromListener != null) {
            print('[SupabaseSync] Found duplicate record with ID ${(duplicateFromListener as dynamic).id}, deleting...');
            await _isar.writeTxn(() => isarCollection.delete((duplicateFromListener as dynamic).id));
            print('[SupabaseSync] Deleted duplicate record, retrying save...');
            // 继续循环重试
          } else {
            print('[SupabaseSync] No duplicate found but unique constraint violated. Breaking.');
            break;
          }
        } else {
          // 其他类型的错误，重新抛出
          rethrow;
        }
      }
    }
    
    if (!saveSuccessful) {
      throw Exception('Failed to save after $maxRetries attempts due to race conditions');
    }
  }

  // --- 外部：推送 (Push) / 写入 API ---
  
  /// 通用的保存方法 (创建或更新)
// 在你的 SupabaseSyncService 中，找到 _saveObject 方法，替换成这个版本：

Future<void> _saveObject<T>(
  String tableName, 
  T isarObject,
  IsarCollection<T> isarCollection,
  Map<String, dynamic> jsonData,
  dynamic fromSupabaseJson
) async {
  if (!isLoggedIn) throw Exception("未登录");

  final isarId = (isarObject as dynamic).id;
  final supabaseId = (isarObject as dynamic).supabaseId as String?;

  if (isarId == null) {
     throw Exception("SaveObject 失败: 传入对象的 Isar ID 为 null。必须先在本地保存。");
  }

  if (supabaseId != null) {
    jsonData['id'] = supabaseId; 
  }

  try {
    // 1. 推送到 Supabase
    final response = await _client.from(tableName).upsert(jsonData).select();
    
    if (response.isEmpty) {
       throw Exception('Upsert 成功，但 RLS 策略阻止了 SELECT 返回数据。');
    }
    
    final savedData = response.first as Map<String, dynamic>;
    final definitiveItem = fromSupabaseJson(savedData) as T;
    final definitiveSupaId = (definitiveItem as dynamic).supabaseId as String?;
    
    // 2. 写回本地
    (definitiveItem as dynamic).id = isarId; 
    
    // 使用专门的竞态条件处理方法
    await _saveWithRaceConditionHandling(
      definitiveItem, 
      isarId, 
      definitiveSupaId, 
      isarObject, 
      isarCollection
    );

    // 关键修复：在这里直接返回，不要继续到 catch 块
    return;

  } catch (e) {
    print('Supabase Save ($tableName) 失败: $e');
    
    // 只有在真正失败时才进行回退操作和重新抛出异常
    // 检查错误信息，如果包含成功信息就不抛出
    if (!e.toString().contains('Successfully saved')) {
      // 回退逻辑
      (isarObject as dynamic).id = isarId;
      try {
        await _isar.writeTxn(() => isarCollection.put(isarObject));
      } catch (e2) {
        print('Supabase Fallback Save 失败: $e2');
      }
      rethrow; // 只有真正失败时才重新抛出
    }
    // 如果包含成功信息，就什么也不做，让方法正常结束
  }
}

  /// 通用的删除方法
  Future<void> _deleteObject<T>(
    String tableName, 
    T isarObject, 
    IsarCollection<T> isarCollection
  ) async {
    if (!isLoggedIn) return;
    
    final supabaseId = (isarObject as dynamic).supabaseId as String?;
    final isarId = (isarObject as dynamic).id as Id;

    // 1. 先从本地删除 (UI 立即响应)
    await _isar.writeTxn(() => isarCollection.delete(isarId));
    
    if (supabaseId == null) {
       return; // 这个对象还未被同步过，直接本地删除即可
    }

    try {
      // 2. 从云端删除 (Supabase 实时服务会通知其他设备删除)
      await _client.from(tableName).delete().eq('id', supabaseId);
    } catch (e) {
      print('Supabase Delete ($tableName) 失败: $e');
      // TODO: 实现离线删除队列
    }
  }
  
  // --- 为每个模型创建公共的 save/delete 方法 ---
  
  Future<void> saveAccount(Account acc) => _saveObject(
      'Account', acc, _isar.accounts, acc.toSupabaseJson(), 
      (json) => Account.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteAccount(Account acc) => _deleteObject('Account', acc, _isar.accounts);

  Future<void> saveAsset(Asset asset) => _saveObject(
      'Asset', asset, _isar.assets, asset.toSupabaseJson(), 
      (json) => Asset.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteAsset(Asset asset) => _deleteObject('Asset', asset, _isar.assets);
  
  Future<void> saveTransaction(Transaction tx) => _saveObject(
      'Transaction', tx, _isar.transactions, tx.toSupabaseJson(),
      (json) => Transaction.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteTransaction(Transaction tx) => _deleteObject('Transaction', tx, _isar.transactions);
  
  Future<void> saveAccountTransaction(AccountTransaction tx) => _saveObject(
      'AccountTransaction', tx, _isar.accountTransactions, tx.toSupabaseJson(),
      (json) => AccountTransaction.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteAccountTransaction(AccountTransaction tx) => _deleteObject('AccountTransaction', tx, _isar.accountTransactions);
  
  Future<void> savePositionSnapshot(PositionSnapshot snap) => _saveObject(
      'PositionSnapshot', snap, _isar.positionSnapshots, snap.toSupabaseJson(),
      (json) => PositionSnapshot.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deletePositionSnapshot(PositionSnapshot snap) => _deleteObject('PositionSnapshot', snap, _isar.positionSnapshots);
}
// 文件: lib/services/supabase_sync_service.dart
// (这是最终的、基于你原有完整代码的修复版本)

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
import 'package:one_five_one_ten/models/deletion.dart'; // 1. (*** 新增导入 ***)

// 从 main.dart 导入全局 supabase 客户端
import 'package:one_five_one_ten/main.dart'; 


class SupabaseSyncService {
  final Isar _isar = DatabaseService().isar;
  final SupabaseClient _client = supabase; 

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  RealtimeChannel? _realtimeChannel;

  // --- 认证 (保持不变) ---
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

    // (*** 2. 关键修改：将原有的首次拉取逻辑替换为更完整的校准同步 ***)
    await _fullInitialSync();

    print('全量同步完成。正在启动实时侦听器...');
    
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

  // --- 内部：同步逻辑 ---

  /// 启动时执行的完整同步和校准流程
  Future<void> _fullInitialSync() async {
    try {
      // --- 1.1 同步删除记录 ---
      await _syncDeletions();

      // --- 1.2 同步数据表 (包含校准) ---
      // 这里的事务被移入 _reconcileTable 内部，避免嵌套
      await _reconcileTable<Account>('Account', _isar.accounts, Account.fromSupabaseJson);
      await _reconcileTable<Asset>('Asset', _isar.assets, Asset.fromSupabaseJson);
      await _reconcileTable<Transaction>('Transaction', _isar.transactions, Transaction.fromSupabaseJson);
      await _reconcileTable<AccountTransaction>('AccountTransaction', _isar.accountTransactions, AccountTransaction.fromSupabaseJson);
      await _reconcileTable<PositionSnapshot>('PositionSnapshot', _isar.positionSnapshots, PositionSnapshot.fromSupabaseJson);

    } catch (e) {
      print('首次全量同步失败: $e');
    }
  }
  
  /// (*** 3. 新增：同步删除记录的方法 ***)
  Future<void> _syncDeletions() async {
    final lastDeletion = await _isar.deletions.where().sortByDeletedAtDesc().findFirst();
    final lastDeletionTime = lastDeletion?.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    final deletionsResponse = await _client
        .from('deletions')
        .select()
        .gte('deleted_at', lastDeletionTime.toIso8601String());

    if (deletionsResponse.isEmpty) return;

    print('[SupabaseSync] Fetched ${deletionsResponse.length} new deletion records.');
    
    await _isar.writeTxn(() async {
      for (final deletionData in (deletionsResponse as List<dynamic>)) {
        final deletion = Deletion()
          ..tableName = deletionData['table_name']
          ..deletedRecordId = deletionData['deleted_record_id']
          ..deletedAt = DateTime.parse(deletionData['deleted_at']);
        
        // 此处直接执行删除逻辑，不再调用会嵌套事务的 _handleDelete
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

  /// (*** 4. 新增：通用的校准方法 ***)
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
    final remoteSupabaseIds = remoteItems.map((e) => (e as dynamic).supabaseId as String?).toSet();

    final localItems = await isarCollection.where().findAll();
    
    final localItemsMap = { for (var item in localItems) (item as dynamic).supabaseId: item };

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

  Future<void> _onCloudChange(PostgresChangePayload payload) async { 
    final eventType = payload.eventType;
    final tableName = payload.table;
    
    try {
      // (*** 5. 关键修改：增加对 deletions 表的实时监听 ***)
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

  Future<void> _performLWWPut<T>(T? localItem, T remoteItem, IsarCollection<T> collection) async {
    final remoteUpdatedAt = (remoteItem as dynamic).updatedAt as DateTime?;
    final remoteSupabaseId = (remoteItem as dynamic).supabaseId as String?;

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
      if (localUpdatedAt == null || (remoteUpdatedAt != null && remoteUpdatedAt.isAfter(localUpdatedAt))) {
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

  // --- 外部：推送 (Push) / 写入 API ---
  
  // (*** 6. 关键修改：重写 _saveObject 以强制更新时间戳并简化 ***)
  Future<void> _saveObject<T>(
    String tableName, 
    T isarObject,
    IsarCollection<T> isarCollection,
    dynamic fromSupabaseJson
  ) async {
    if (!isLoggedIn) throw Exception("未登录");

    // --- 核心修复：强制更新时间戳 ---
    (isarObject as dynamic).updatedAt = DateTime.now();
    
    // 立即将更新（包括新时间戳）写入本地
    await _isar.writeTxn(() => isarCollection.put(isarObject));
    
    final jsonData = (isarObject as dynamic).toSupabaseJson();
    
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
      
      (definitiveItem as dynamic).id = isarId; 
      
      // 使用你原有的健壮的竞态条件处理逻辑
      await _saveWithRaceConditionHandling(
        definitiveItem, 
        isarId, 
        definitiveSupaId, 
        isarObject, 
        isarCollection
      );
    } catch (e) {
      print('Supabase Save ($tableName) 失败: $e');
      rethrow;
    }
  }

  // (*** 7. 关键修改：重写 _deleteObject 以使用“墓碑表” ***)
  Future<void> _deleteObject<T>(
    String tableName, 
    T isarObject, 
    IsarCollection<T> isarCollection
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
        'deleted_at': DateTime.now().toIso8601String(),
      });
      
      await _client.from(tableName).delete().eq('id', supabaseId);

      print('[SupabaseSync] Successfully deleted and logged tombstone for $tableName/$supabaseId');

    } catch (e) {
      print('Supabase Delete ($tableName) 失败: $e');
      // TODO: 实现离线删除队列
    }
  }
  
  // (*** 8. 关键修改：更新所有公共 save 方法以匹配新的 _saveObject 签名 ***)
  
  Future<void> saveAccount(Account acc) => _saveObject(
      'Account', acc, _isar.accounts, 
      (json) => Account.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteAccount(Account acc) => _deleteObject('Account', acc, _isar.accounts);

  Future<void> saveAsset(Asset asset) => _saveObject(
      'Asset', asset, _isar.assets, 
      (json) => Asset.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteAsset(Asset asset) => _deleteObject('Asset', asset, _isar.assets);
  
  Future<void> saveTransaction(Transaction tx) => _saveObject(
      'Transaction', tx, _isar.transactions,
      (json) => Transaction.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteTransaction(Transaction tx) => _deleteObject('Transaction', tx, _isar.transactions);
  
  Future<void> saveAccountTransaction(AccountTransaction tx) => _saveObject(
      'AccountTransaction', tx, _isar.accountTransactions,
      (json) => AccountTransaction.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deleteAccountTransaction(AccountTransaction tx) => _deleteObject('AccountTransaction', tx, _isar.accountTransactions);
  
  Future<void> savePositionSnapshot(PositionSnapshot snap) => _saveObject(
      'PositionSnapshot', snap, _isar.positionSnapshots,
      (json) => PositionSnapshot.fromSupabaseJson(json as Map<String, dynamic>)
  );
  Future<void> deletePositionSnapshot(PositionSnapshot snap) => _deleteObject('PositionSnapshot', snap, _isar.positionSnapshots);
}
// 文件: lib/services/supabase_sync_service.dart

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
    // (*** 已修正：不再使用通用的 _fetchAllObjects，而是使用 5 个特定的拉取来避免 Isar 过滤器错误 ***)
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
        // 如果 RLS 策略 (Row Level Security) 没设置对，这里会报错
      }
    });

    print('全量拉取完成。正在启动实时侦听器...');
    
    // --- 2. 订阅实时变化 (Realtime) ---
    // (*** 这是针对 V2 语法的修正 ***)
    _realtimeChannel = _client.channel('public_tables_channel'); // 频道名称可以是任意字符串
    _realtimeChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all, // 1. 这是新的 Enum
        schema: 'public',
        // 2. 我们将侦听所有表的变化，然后在回调中区分
        callback: _onCloudChange      // 3. 这是新的回调方式
      )
      .subscribe((status, [error]) { // 4. .on() 和 .subscribe() 是分开调用的
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
  Future<void> _onCloudChange(PostgresChangePayload payload) async { // 修正了 Payload 类型
    final eventType = payload.eventType;
    final tableName = payload.table;
    
    try {
      if (eventType == PostgresChangeEvent.insert || eventType == PostgresChangeEvent.update) {
        final remoteData = payload.newRecord;
        await _handleUpsert(remoteData, tableName);
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldData = payload.oldRecord;
         // DELETE 事件只包含 old data（或只有主键，取决于您的 REPLICA IDENTITY）
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
    await _isar.writeTxn(() async {
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

    if (localItem == null) {
      // 本地不存在，直接写入
      await collection.put(remoteItem);
    } else {
      final localUpdatedAt = (localItem as dynamic).updatedAt as DateTime?;
      // 远端版本较新，或者本地没有时间戳，就覆盖本地
      if (localUpdatedAt == null || (remoteUpdatedAt != null && remoteUpdatedAt.isAfter(localUpdatedAt))) {
        (remoteItem as dynamic).id = (localItem as dynamic).id; // 关键：保留本地的 Isar Id
        await collection.put(remoteItem);
      }
      // else: 本地版本较新或相同，忽略
    }
  }

  // --- 外部：推送 (Push) / 写入 API ---
  
  /// 通用的保存方法 (创建或更新)
  Future<void> _saveObject<T>(
    String tableName, 
    T isarObject, // 包含 Isar ID 和本地更改的对象
    IsarCollection<T> isarCollection,
    Map<String, dynamic> jsonData, // isarObject.toSupabaseJson() 的结果
    dynamic fromSupabaseJson // 例如：(json) => Asset.fromSupabaseJson(json)
  ) async {
    if (!isLoggedIn) throw Exception("未登录");

    final isarId = (isarObject as dynamic).id;
    final supabaseId = (isarObject as dynamic).supabaseId as String?;

    // 如果是更新，我们需要将 'id' (Supabase UUID) 添加到数据中，以便 .upsert() 知道要更新哪一行
    if (supabaseId != null) {
      jsonData['id'] = supabaseId; 
    }
    // 'user_id' 会被我们在第 0 步设置的 SQL (DEFAULT auth.uid()) 自动处理

    try {
      // 1. (推送) 使用 .upsert() 将数据写入 Supabase。
      // .select() 会将刚刚写入或更新的完整行数据返回给我们
      final response = await _client.from(tableName).upsert(jsonData).select();
      
      final savedData = response.first as Map<String, dynamic>;

      // 2. (回写) 我们收到了来自 Supabase 的权威数据 (包含新的 'supabaseId' (如果之前没有) 和 'updated_at')
      final definitiveItem = fromSupabaseJson(savedData) as T;
      
      // 3. 将这个权威版本写回本地 Isar，同时保留我们原始的本地 Isar ID
      (definitiveItem as dynamic).id = isarId; 
      await _isar.writeTxn(() => isarCollection.put(definitiveItem));

    } catch (e) {
      print('Supabase Save ($tableName) 失败: $e');
      // 即使推送失败，数据仍然保存在本地 Isar 中（尽管没有最新的时间戳）
      (isarObject as dynamic).id = isarId; // 确保 Isar ID 还在
      await _isar.writeTxn(() => isarCollection.put(isarObject)); // 至少保存本地更改
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
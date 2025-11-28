import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 一次性：修正因占位 UUID 产生的账户 ID 分裂问题
class SupabaseIdMigrationService {
  SupabaseIdMigrationService({required this.syncService});

  final SupabaseSyncService syncService;

  String _nameCurrencyKey(String name, String currency) =>
      '${name.trim().toLowerCase()}|${currency.trim().toLowerCase()}';

  String _normalizeManualKey(String raw) {
    final parts = raw.split('|');
    if (parts.length >= 2) {
      return _nameCurrencyKey(parts.first, parts.sublist(1).join('|'));
    }
    return raw.trim().toLowerCase();
  }

  /// 运行迁移
  ///
  /// [manualNameCurrencyMap]：可选的手动映射，键为 `账户名|币种`（如 `现金|CNY`），
  /// 值为 Supabase 端的真实 UUID。
  Future<void> runAccountIdMigration({
    Map<String, String> manualNameCurrencyMap = const {},
  }) async {
    if (!syncService.isLoggedIn) {
      print('[SupabaseIdMigration] 未登录，跳过账户 ID 迁移。');
      return;
    }

    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      print('[SupabaseIdMigration] Supabase 未初始化，跳过。');
      return;
    }

    final remoteResponse = await client.from('Account').select();
    final remoteAccounts = (remoteResponse as List<dynamic>)
        .map((json) => Account.fromSupabaseJson(json as Map<String, dynamic>))
        .where((acc) => acc.supabaseId != null)
        .toList();

    final remoteIds = remoteAccounts.map((e) => e.supabaseId!).toSet();
    final remoteKeyMap = <String, List<Account>>{};

    for (final acc in remoteAccounts) {
      final key = _nameCurrencyKey(acc.name, acc.currency);
      remoteKeyMap.putIfAbsent(key, () => []).add(acc);
    }

    final manualLowerCase = <String, String>{
      for (final entry in manualNameCurrencyMap.entries)
        _normalizeManualKey(entry.key): entry.value,
    };

    final isar = DatabaseService().isar;
    final accounts = await isar.accounts.where().findAll();

    for (final acc in accounts) {
      final oldId = acc.supabaseId;
      if (oldId != null && remoteIds.contains(oldId)) continue;

      final key = _nameCurrencyKey(acc.name, acc.currency);
      final manualId = manualLowerCase[key];
      final remoteCandidates = remoteKeyMap[key] ?? const <Account>[];
      final hasUniqueRemote = remoteCandidates.length == 1;

      String? targetId;
      if (manualId != null && remoteIds.contains(manualId)) {
        targetId = manualId;
      } else if (manualId != null && !remoteIds.contains(manualId)) {
        print(
          '[SupabaseIdMigration] 手动映射的 ID $manualId 未在服务器找到，忽略。',
        );
      }

      targetId ??= hasUniqueRemote ? remoteCandidates.first.supabaseId : null;

      if (targetId == null || targetId == oldId) continue;

      print(
          '[SupabaseIdMigration] 回写账户 ${acc.name}(${acc.currency}) 的 ID: $oldId -> $targetId');
      await DatabaseService().applySupabaseIdMigration(
        account: acc,
        oldSupabaseId: oldId,
        newSupabaseId: targetId,
      );

      // 触发重新上行，确保关系表也更新
      await syncService.saveAccount(acc);
    }
  }
}

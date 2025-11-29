// File: lib/services/database_service.dart
// Version: CHATGPT-ALLOC-STEP2-DB-SCHEMAS-ADD

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/asset_bucket_map.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/models/deletion.dart';

// ▼ 新增：资产配置模型
import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_plan_item.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  late Isar isar;

  Future<void> init() async {
    if (Isar.instanceNames.isNotEmpty) {
      isar = Isar.getInstance()!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    // ★★★ 一定要把两个新表的 Schema 一起注册 ★★★
    isar = await Isar.open(
      [
        AccountSchema,
        AccountTransactionSchema,
        AssetSchema,
        PositionSnapshotSchema,
        TransactionSchema,
        DeletionSchema,

        // 新增：资产配置
        AllocationPlanSchema,
        AllocationPlanItemSchema,
        AssetBucketMapSchema,
      ],
      directory: dir.path,
      name: 'one_five_one_ten_db',
    );

    await _backfillLocalSupabaseIds();
    await _repairOrphanRelations();
  }

  String _nameCurrencyKey(String name, String currency) =>
      '${name.trim().toLowerCase()}|${currency.trim().toLowerCase()}';

  /// 回填本地账户缺失的 Supabase ID
  ///
  /// 规则：
  /// - 仅在「已登录」且 Supabase SDK 可用时运行；
  /// - 优先使用线上账户（按“名称+币种”唯一匹配）写回本地 ID；
  /// - 不再离线生成占位 UUID，避免与服务器产生冲突。
  Future<void> _backfillLocalSupabaseIds() async {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      // 未初始化 Supabase 时不做回填
    }

    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      print('[DatabaseService] 跳过 Supabase ID 回填：未登录或 Supabase 未初始化。');
      return;
    }

    final remoteResponse = await client.from('Account').select();
    final remoteAccounts = (remoteResponse as List<dynamic>)
        .map((json) => Account.fromSupabaseJson(json as Map<String, dynamic>))
        .where((acc) => acc.supabaseId != null)
        .toList();

    final remoteIds = remoteAccounts.map((e) => e.supabaseId!).toSet();
    final remoteKeyMap = <String, Account>{};
    final multiKeyFlags = <String, bool>{};

    for (final acc in remoteAccounts) {
      final key = _nameCurrencyKey(acc.name, acc.currency);
      if (remoteKeyMap.containsKey(key)) {
        multiKeyFlags[key] = true;
      } else {
        remoteKeyMap[key] = acc;
      }
    }

    final accounts = await isar.accounts.where().findAll();

    for (final acc in accounts) {
      final oldId = acc.supabaseId;
      final hasValidRemoteId =
          oldId != null && _uuidRegex.hasMatch(oldId) && remoteIds.contains(oldId);
      if (hasValidRemoteId) continue;

      final key = _nameCurrencyKey(acc.name, acc.currency);
      if (multiKeyFlags[key] == true) continue; // 同名同币种多条，避免误配

      final remote = remoteKeyMap[key];
      final newId = remote?.supabaseId;
      if (newId == null || newId == oldId) continue;

      await applySupabaseIdMigration(
        account: acc,
        oldSupabaseId: oldId,
        newSupabaseId: newId,
      );
    }
  }

  /// 在本地更新账户的 Supabase ID，并同步修正关联的资产与账户流水
  Future<void> applySupabaseIdMigration({
    required Account account,
    required String? oldSupabaseId,
    required String newSupabaseId,
  }) async {
    final relatedAssets = <Asset>[];
    final relatedAccountTxns = <AccountTransaction>[];

    if (oldSupabaseId != null) {
      relatedAssets.addAll(await isar.assets
          .where()
          .accountSupabaseIdEqualTo(oldSupabaseId)
          .findAll());
      relatedAccountTxns.addAll(await isar.accountTransactions
          .where()
          .accountSupabaseIdEqualTo(oldSupabaseId)
          .findAll());
    }

    await isar.writeTxn(() async {
      account.supabaseId = newSupabaseId;
      await isar.accounts.put(account);

      for (final asset in relatedAssets) {
        asset.accountSupabaseId = newSupabaseId;
        await isar.assets.put(asset);
      }

      for (final txn in relatedAccountTxns) {
        txn.accountSupabaseId = newSupabaseId;
        await isar.accountTransactions.put(txn);
      }
    });
  }

  /// 修复旧版本遗留的“无账户标记”记录，避免资产/交易找不到所属账户
  ///
  /// 策略：
  /// - 只有 1 个账户时，全部归入唯一账户；
  /// - 多账户时，按 currency 唯一匹配（同币种仅 1 个账户时归入该账户）；
  /// - 其它无法判定的记录保持空，避免错配。
  Future<void> _repairOrphanRelations() async {
    final accounts = await isar.accounts.where().findAll();
    if (accounts.isEmpty) return;

    final soleAccount = accounts.length == 1 ? accounts.first : null;
    final uniqueCurrencyAccount = <String, Account>{};
    final multiCurrencyFlag = <String, bool>{};

    for (final acc in accounts) {
      final lowerCurrency = acc.currency.toLowerCase();
      if (uniqueCurrencyAccount.containsKey(lowerCurrency)) {
        multiCurrencyFlag[lowerCurrency] = true;
      } else {
        uniqueCurrencyAccount[lowerCurrency] = acc;
      }
    }

    final orphanAssets = await isar.assets.where().accountSupabaseIdIsNull().findAll();
    final orphanAccountTxns =
        await isar.accountTransactions.where().accountSupabaseIdIsNull().findAll();

    if (orphanAssets.isEmpty && orphanAccountTxns.isEmpty) return;

    await isar.writeTxn(() async {
      for (final asset in orphanAssets) {
        final account = _resolveAccountForCurrency(
          currency: asset.currency,
          soleAccount: soleAccount,
          uniqueCurrencyAccount: uniqueCurrencyAccount,
          multiCurrencyFlag: multiCurrencyFlag,
        );
        if (account == null || account.supabaseId == null) continue;
        asset.accountSupabaseId = account.supabaseId;
        await isar.assets.put(asset);
      }

      for (final accTxn in orphanAccountTxns) {
        final account = _resolveAccountForCurrency(
          currency: null, // 账户交易无币种，只用兜底策略
          soleAccount: soleAccount,
          uniqueCurrencyAccount: uniqueCurrencyAccount,
          multiCurrencyFlag: multiCurrencyFlag,
        );
        if (account == null || account.supabaseId == null) continue;
        accTxn.accountSupabaseId = account.supabaseId;
        await isar.accountTransactions.put(accTxn);
      }
    });
  }

  Account? _resolveAccountForCurrency({
    required String? currency,
    required Account? soleAccount,
    required Map<String, Account> uniqueCurrencyAccount,
    required Map<String, bool> multiCurrencyFlag,
  }) {
    if (soleAccount != null) return soleAccount;
    if (currency == null) return null;
    final key = currency.toLowerCase();
    if (multiCurrencyFlag[key] == true) return null;
    return uniqueCurrencyAccount[key];
  }
}

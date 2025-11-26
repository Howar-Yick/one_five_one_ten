// File: lib/services/database_service.dart
// Version: CHATGPT-ALLOC-STEP2-DB-SCHEMAS-ADD

import 'dart:math';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

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

  static final _random = Random();

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  /// 本地生成一个符合 UUID v4 规范的占位符，确保离线/未登录时也能有稳定 ID
  static String generateLocalSupabaseId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // 设置版本与变种位
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

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

  /// 兼容老数据：为缺失 supabaseId 的账户生成本地 ID，避免页面依赖非空字段时崩溃
  Future<void> _backfillLocalSupabaseIds() async {
    final accounts = await isar.accounts.where().findAll();

    final migrations = <_SupabaseIdMigration>[];
    for (final acc in accounts) {
      final oldId = acc.supabaseId;
      final isValid = oldId != null && _uuidRegex.hasMatch(oldId);
      if (isValid) continue;

      final newId = generateLocalSupabaseId();
      migrations.add(
        _SupabaseIdMigration(
          account: acc,
          oldSupabaseId: oldId,
          newSupabaseId: newId,
        ),
      );
    }

    if (migrations.isEmpty) return;

    final relatedAssets = <String, List<Asset>>{};
    final relatedAccountTxns = <String, List<AccountTransaction>>{};

    for (final migration in migrations) {
      final oldId = migration.oldSupabaseId;
      if (oldId == null) continue;
      relatedAssets[oldId] = await isar.assets
          .where()
          .accountSupabaseIdEqualTo(oldId)
          .findAll();
      relatedAccountTxns[oldId] = await isar.accountTransactions
          .where()
          .accountSupabaseIdEqualTo(oldId)
          .findAll();
    }

    await isar.writeTxn(() async {
      for (final migration in migrations) {
        final oldId = migration.oldSupabaseId;
        final newId = migration.newSupabaseId;

        migration.account.supabaseId = newId;
        await isar.accounts.put(migration.account);

        if (oldId != null) {
          for (final asset in relatedAssets[oldId] ?? const <Asset>[]) {
            asset.accountSupabaseId = newId;
            await isar.assets.put(asset);
          }
          for (final txn in relatedAccountTxns[oldId] ?? const <AccountTransaction>[]) {
            txn.accountSupabaseId = newId;
            await isar.accountTransactions.put(txn);
          }
        }
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

class _SupabaseIdMigration {
  _SupabaseIdMigration({
    required this.account,
    required this.oldSupabaseId,
    required this.newSupabaseId,
  });

  final Account account;
  final String? oldSupabaseId;
  final String newSupabaseId;
}

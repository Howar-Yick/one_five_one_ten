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

  /// 本地生成一个可作为 Supabase 主键的占位符，确保离线/未登录时也能有稳定 ID
  static String generateLocalSupabaseId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0xFFFFFF);
    return '$prefix-$timestamp-$salt';
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
  }

  /// 兼容老数据：为缺失 supabaseId 的账户生成本地 ID，避免页面依赖非空字段时崩溃
  Future<void> _backfillLocalSupabaseIds() async {
    final accountsWithoutId =
        await isar.accounts.filter().supabaseIdIsNull().findAll();
    if (accountsWithoutId.isEmpty) return;

    await isar.writeTxn(() async {
      for (final acc in accountsWithoutId) {
        acc.supabaseId = generateLocalSupabaseId('acc');
        await isar.accounts.put(acc);
      }
    });
  }
}

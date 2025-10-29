// File: lib/services/database_service.dart
// Version: CHATGPT-ALLOC-STEP2-DB-SCHEMAS-ADD

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
  }
}

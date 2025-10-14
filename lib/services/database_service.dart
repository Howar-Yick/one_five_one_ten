// File: lib/services/database_service.dart
// Version: CHATGPT-1.03-20251014-VB-FILTER-HOTFIX
//
// 说明：保持你的原始实现，不新增不存在的字段/方法；仅保留你新增的 DeletionSchema。
// 若后续你希望我把“清仓判定”下沉到 DB 层，可再开一版，但本热修复不做侵入更改。

import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:one_five_one_ten/models/deletion.dart'; // ✅ 你已添加的 Deletion 模型

class DatabaseService {
  late Isar isar;
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  Future<void> init() async {
    if (Isar.instanceNames.isNotEmpty) {
      isar = Isar.getInstance()!;
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        AccountSchema,
        AccountTransactionSchema,
        AssetSchema,
        PositionSnapshotSchema,
        TransactionSchema,
        DeletionSchema, // ✅ 保留
      ],
      directory: dir.path,
      name: 'one_five_one_ten_db',
    );
  }
}

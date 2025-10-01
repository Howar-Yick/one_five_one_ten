// 文件: lib/services/database_service.dart
// (这是基于你提供的最新文件进行的修复)

import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:one_five_one_ten/models/deletion.dart'; // <--- 1. 关键修改：新增 Deletion 模型的导入

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
        DeletionSchema, // <--- 2. 关键修改：在这里添加新的 DeletionSchema
      ],
      directory: dir.path,
      name: 'one_five_one_ten_db',
    );
  }
}
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart'; // <--- 新增 import
import 'package:path_provider/path_provider.dart';

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
        TransactionSchema, // <--- 在这里添加新模型
      ],
      directory: dir.path,
      name: 'one_five_one_ten_db',
    );
  }
}
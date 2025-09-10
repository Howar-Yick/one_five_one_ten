import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  late final Isar isar;

  // 私有构造函数
  DatabaseService._();

  // 单例实例
  static final DatabaseService _instance = DatabaseService._();

  // 工厂构造函数，返回单例
  factory DatabaseService() => _instance;

  Future<void> init() async {
    if (Isar.instanceNames.isNotEmpty) {
      // 如果已经初始化，则直接返回
      isar = Isar.getInstance()!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        // 在这里注册所有的数据模型 Schema
        AccountSchema,
        AccountTransactionSchema,
        AssetSchema,
        PositionSnapshotSchema,
      ],
      directory: dir.path,
      name: 'one_five_one_ten_db',
    );
  }
}
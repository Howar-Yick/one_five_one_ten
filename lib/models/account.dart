import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'account.g.dart';

@collection
class Account {
  Id id = Isar.autoIncrement;
  late String name;
  late DateTime createdAt;
  String? description;
  
  // --- 新增：币种字段 ---
  @Index()
  String currency = 'CNY'; // 默认为人民币

  @Backlink(to: "account")
  final transactions = IsarLinks<AccountTransaction>();
  @Backlink(to: "account")
  final trackedAssets = IsarLinks<Asset>();
}
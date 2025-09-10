import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'account.g.dart';

@collection
class Account {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name; // 账户名称, e.g., "国金证券"

  late DateTime createdAt; // 创建日期

  String? description; // 描述

  // Isar会自动管理这些关联关系
  // 关联的宏观交易记录
  @Backlink(to: "account")
  final transactions = IsarLinks<AccountTransaction>();

  // 关联的微观跟踪资产
  @Backlink(to: "account")
  final trackedAssets = IsarLinks<Asset>();
}

import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';

part 'asset.g.dart';

enum AssetTrackingMethod {
  valueBased,
  shareBased,
}

// --- 新增：资产子类型枚举 ---
enum AssetSubType {
  stock,      // 股票
  etf,        // 场内基金
  mutualFund, // 场外基金
  other,      // 其他
}

@collection
class Asset {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;

  String code = '';
  double latestPrice = 0;
  DateTime? priceUpdateDate;

  @Enumerated(EnumType.name)
  late AssetTrackingMethod trackingMethod;

  // --- 新增：资产子类型字段 ---
  @Enumerated(EnumType.name)
  late AssetSubType subType;

  final account = IsarLink<Account>();

  @Backlink(to: "asset")
  final snapshots = IsarLinks<PositionSnapshot>();
  
  @Backlink(to: "asset")
  final transactions = IsarLinks<Transaction>();
}
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';

part 'asset.g.dart';

enum AssetTrackingMethod {
  valueBased,
  shareBased,
}

enum AssetSubType {
  stock,
  etf,
  mutualFund,
  other,
}

@collection
class Asset {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;
  String code = '';
  double latestPrice = 0;
  DateTime? priceUpdateDate;

  // --- 新增：币种字段 ---
  @Index()
  String currency = 'CNY'; // 默认为人民币

  @Enumerated(EnumType.name)
  late AssetTrackingMethod trackingMethod;
  @Enumerated(EnumType.name)
  late AssetSubType subType;

  final account = IsarLink<Account>();

  @Backlink(to: "asset")
  final snapshots = IsarLinks<PositionSnapshot>();
  
  @Backlink(to: "asset")
  final transactions = IsarLinks<Transaction>();
}
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';

part 'asset.g.dart';

enum AssetTrackingMethod {
  valueBased,
  shareBased,
}

@collection
class Asset {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;

  String code = '';
  double latestPrice = 0;
  
  // --- 新增：价格更新日期 ---
  DateTime? priceUpdateDate;

  @Enumerated(EnumType.name)
  late AssetTrackingMethod trackingMethod;

  final account = IsarLink<Account>();

  @Backlink(to: "asset")
  final snapshots = IsarLinks<PositionSnapshot>();
  
  @Backlink(to: "asset")
  final transactions = IsarLinks<Transaction>();
}
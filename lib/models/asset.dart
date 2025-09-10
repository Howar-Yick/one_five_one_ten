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

  // --- 修正：将 String? code 修改为 String code = '' ---
  String code = ''; // 资产代码, 给予一个默认的空值

  @Enumerated(EnumType.name)
  late AssetTrackingMethod trackingMethod;

  final account = IsarLink<Account>();

  @Backlink(to: "asset")
  final snapshots = IsarLinks<PositionSnapshot>();
  
  @Backlink(to: "asset")
  final transactions = IsarLinks<Transaction>();
}
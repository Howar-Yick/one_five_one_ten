import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';

part 'asset.g.dart';

@collection
class Asset {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name; // 资产名称, e.g., "贵州茅台"

  late String code; // 资产代码, e.g., "600519.SH"

  // 指向所属的账户
  final account = IsarLink<Account>();

  // 关联的持仓快照历史
  @Backlink(to: "asset")
  final snapshots = IsarLinks<PositionSnapshot>();
}
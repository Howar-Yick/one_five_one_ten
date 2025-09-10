import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'position_snapshot.g.dart';

@collection
class PositionSnapshot {
  Id id = Isar.autoIncrement;

  late DateTime date;

  late double totalShares; // 总份额

  late double averageCost; // 单位成本

  // 指向所属的资产
  final asset = IsarLink<Asset>();
}
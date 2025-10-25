// File: lib/models/allocation_bucket.dart
import 'package:isar/isar.dart';

part 'allocation_bucket.g.dart';

@collection
class AllocationBucket {
  Id id = Isar.autoIncrement;

  /// 桶名称：如 “美股 / A股 / 黄金 / 固收 / 现金”
  @Index(unique: true, caseSensitive: false)
  late String name;

  /// 目标权重（0~1），当 plan 未覆盖时使用
  @Index()
  double targetWeight = 0;

  /// UI 用颜色（可选），形如 #RRGGBB 或 #AARRGGBB
  String? colorHex;

  /// 排序（越小越靠前）
  @Index()
  int order = 0;

  /// 是否启用（逻辑删除或临时隐藏用）
  @Index()
  bool isActive = true;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

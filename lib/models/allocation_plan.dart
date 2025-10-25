// File: lib/models/allocation_plan.dart
import 'package:isar/isar.dart';

part 'allocation_plan.g.dart';

/// 资产配置“方案”表（支持多方案）
@collection
class AllocationPlan {
  Id id = Isar.autoIncrement;

  /// 方案名称（例如：长期配置 / 稳健配置 / 实验组合）
  @Index(caseSensitive: false)
  late String name;

  /// 备注说明
  String? note;

  /// 是否为当前启用方案（后续可支持多启用或单启用策略）
  @Index()
  bool isActive = true;

  /// 方案创建/更新时间
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

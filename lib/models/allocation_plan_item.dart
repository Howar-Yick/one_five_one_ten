// File: lib/models/allocation_plan_item.dart
import 'package:isar/isar.dart';

part 'allocation_plan_item.g.dart';

/// 资产配置“条目”表（某个方案下的若干目标项）
/// 为了尽量不侵入你现有资产模型，这里仅做轻量字段：
/// - 通过 planId 归属到某个 AllocationPlan
/// - 用 label 表示条目名称（如“美股”、“A股”、“黄金”、“固收”等）
/// - targetPercent 目标占比（0~1）
/// - rule 表达式/标签，之后可用来将现有资产手动分配到该类别（先留字段）
@collection
class AllocationPlanItem {
  Id id = Isar.autoIncrement;

  /// 归属方案 id（外键，简化起见用数值字段；如需链接可改为 IsarLink）
  @Index()
  late int planId;

  /// 条目名称（类别名）
  @Index(caseSensitive: false)
  late String label;

  /// 目标占比（0~1），例如 0.25 代表 25%
  @Index()
  double targetPercent = 0.0;

  /// 手动匹配规则（先预留，后续可用于把现有资产分配进来）
  String? includeRule;

  /// 备注
  String? note;

  /// 排序（同方案内的展示顺序）
  @Index()
  int sortOrder = 0;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

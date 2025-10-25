// File: lib/models/allocation_models.dart
// Step 2 - Allocation Planner: Isar local-only models (safe & isolated)

import 'package:isar/isar.dart';
part 'allocation_models.g.dart';

@collection
class AllocationScheme {
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  late String name;

  /// 是否默认方案（可选，方便将来做快速读取）
  @Index()
  bool isDefault = false;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  /// 桶集合
  final buckets = IsarLinks<AllocationBucket>();
}

@collection
class AllocationBucket {
  Id id = Isar.autoIncrement;

  /// 归属的方案（IsarLinks 反向）
  final scheme = IsarLink<AllocationScheme>();

  /// 显示名（如 “美股”、“A股”、“港股”、“黄金”、“固收”）
  @Index(caseSensitive: false)
  late String name;

  /// 目标权重（0~1之间），例如 0.25 = 25%
  @Index()
  double targetWeight = 0.0;

  /// 标签/类型（可选），无需严格约束，方便后续筛选
  String tag = '';

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  /// 资产映射（多对多）：哪些资产属于这个桶
  final assetLinks = IsarLinks<AssetAllocationLink>();
}

@collection
class AssetAllocationLink {
  Id id = Isar.autoIncrement;

  /// 目标桶
  final bucket = IsarLink<AllocationBucket>();

  /// 资产的 Supabase 外键（与你现有 Asset 模型一致）
  @Index()
  String? assetSupabaseId;

  /// 可选：手工覆盖该资产在本桶中的权重（0~1）
  double? weightOverride;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

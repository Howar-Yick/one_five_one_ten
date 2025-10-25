// File: lib/models/allocation_plan_bucket.dart
import 'package:isar/isar.dart';

part 'allocation_plan_bucket.g.dart';

/// Plan 与 Bucket 的多对多 + 覆盖目标权重
/// 采用“独立集合+Id引用”的方式，避免 IsarLinks 带来的生成 & 迁移复杂度
@collection
class AllocationPlanBucket {
  Id id = Isar.autoIncrement;

  /// 所属方案
  @Index()
  late int planId;

  /// 目标桶
  @Index()
  late int bucketId;

  /// 覆盖权重（可空；为空时使用 AllocationBucket.targetWeight）
  double? targetWeightOverride;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  /// 复合索引：同一 plan + bucket 仅一条
  @Index(composite: [CompositeIndex('bucketId')], unique: true)
  int get _planIndex => planId;
}

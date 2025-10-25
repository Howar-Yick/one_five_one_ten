// File: lib/models/allocation_plan.dart
import 'package:isar/isar.dart';

part 'allocation_plan.g.dart';

@collection
class AllocationPlan {
  Id id = Isar.autoIncrement;

  /// 方案名称：如 “进取型-2025Q1”
  @Index(unique: true, caseSensitive: false)
  late String name;

  /// 是否默认方案（全局唯一建议用 UI 层约束，这里不加唯一索引，避免写入冲突）
  @Index()
  bool isDefault = false;

  /// 方案描述（可选）
  String? description;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

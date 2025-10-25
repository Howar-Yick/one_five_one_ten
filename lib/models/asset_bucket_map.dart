// File: lib/models/asset_bucket_map.dart
import 'package:isar/isar.dart';

part 'asset_bucket_map.g.dart';

/// 资产 → 桶 的归类映射
/// 优先用 assetSupabaseId 做“跨设备/库”的稳定映射；如果没有可用本地 assetId 填充
@collection
class AssetBucketMap {
  Id id = Isar.autoIncrement;

  /// 资产 SupabaseId（优先字段）；为空时用 assetId
  @Index(caseSensitive: false)
  String? assetSupabaseId;

  /// 本地 Isar 资产 id（兜底）
  @Index()
  int? assetId;

  /// 方案（可空：为空表示“默认方案”下生效）
  @Index()
  int? planId;

  /// 目标桶
  @Index()
  late int bucketId;

  /// 备注（可选）
  String? note;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  /// 复合唯一：同一“资产标识+planId”仅一条
  /// 为简化：对 supabaseId 与 assetId 分别做唯一约束（两套可并存）
  @Index(composite: [CompositeIndex('planId')], unique: true, caseSensitive: false)
  String get _supabaseKey => assetSupabaseId ?? '';

  @Index(composite: [CompositeIndex('planId')], unique: true)
  int get _localAssetKey => assetId ?? -1;
}

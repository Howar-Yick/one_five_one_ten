// lib/models/position_snapshot.dart
import 'package:isar/isar.dart';

part 'position_snapshot.g.dart';

@collection
class PositionSnapshot {
  Id id = Isar.autoIncrement;

  late DateTime date;

  /// 总份额
  late double totalShares;

  /// 单位成本（资产币种计价）
  late double averageCost;

  /// 快照记录时的资产币种 -> 人民币汇率（便于后续收益拆分）
  double? fxRateToCny;

  /// 快照对应的人民币成本（如有）
  double? costBasisCny;

  /// 关联 Asset 的 Supabase UUID
  @Index()
  String? assetSupabaseId;

  /// 自己在 Supabase 的 UUID
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId;

  late DateTime createdAt;
  DateTime? updatedAt;

  PositionSnapshot();

  // ================= Supabase 映射 =================

  factory PositionSnapshot.fromSupabaseJson(Map<String, dynamic> json) {
    final snap = PositionSnapshot();

    snap.supabaseId = json['id'] as String?;
    snap.updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String).toLocal()
        : null;
    snap.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String).toLocal()
        : DateTime.now();

    snap.date = DateTime.parse(json['date'] as String).toLocal();
    snap.totalShares = (json['total_shares'] as num?)?.toDouble() ?? 0.0;

    // ---- 关键修复：优先使用旧字段 cost_basis，其次才是 average_cost ----
    // 1. 兼容旧结构：老数据只在 cost_basis，有值；average_cost 为 0 或 NULL
    // 2. 新结构：两个字段都写同样的值
    // 3. 为了防止 0 把真实值盖掉，这里显式判断：
    num? rawAvg;

    final dynamic legacy = json['cost_basis'];
    final dynamic avgCol = json['average_cost'];

    if (legacy is num && legacy != 0) {
      // 老数据优先
      rawAvg = legacy;
    } else if (avgCol is num && avgCol != 0) {
      // 新数据
      rawAvg = avgCol;
    } else if (legacy is num) {
      // 两边都为 0 或只有 0，这时就按 0 处理（确实是 0 或已经被污染）
      rawAvg = legacy;
    } else if (avgCol is num) {
      rawAvg = avgCol;
    } else {
      rawAvg = null;
    }

    snap.averageCost = rawAvg?.toDouble() ?? 0.0;
    // ---- 修复结束 ----

    snap.fxRateToCny = (json['fx_rate_to_cny'] as num?)?.toDouble();
    snap.costBasisCny = (json['cost_basis_cny'] as num?)?.toDouble();

    snap.assetSupabaseId = json['asset_id'] as String?;
    return snap;
  }

  Map<String, dynamic> toSupabaseJson() {
    final map = <String, dynamic>{
      'date': date.toIso8601String(),
      'total_shares': totalShares,

      // 为了兼容 & 满足 NOT NULL 约束 —— 两个字段都写
      'average_cost': averageCost,
      'cost_basis': averageCost,

      'asset_id': assetSupabaseId,
      'created_at': createdAt.toIso8601String(),
    };

    if (fxRateToCny != null) {
      map['fx_rate_to_cny'] = fxRateToCny;
    }
    if (costBasisCny != null) {
      map['cost_basis_cny'] = costBasisCny;
    }

    return map;
  }
}

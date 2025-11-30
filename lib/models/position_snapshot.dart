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

    // ---- 关键修复：兼容旧字段 cost_basis，避免 0 覆盖有效值 ----
    // 优先使用非 0 的 cost_basis；其次使用非 0 的 average_cost；都为 0/NULL 时按 0 处理。
    final dynamic legacy = json['cost_basis'];
    final dynamic avgCol = json['average_cost'];

    num? rawAvg;
    if (legacy is num && legacy != 0) {
      rawAvg = legacy;
    } else if (avgCol is num && avgCol != 0) {
      rawAvg = avgCol;
    } else if (legacy is num) {
      rawAvg = legacy; // 包含“确实为 0”的场景
    } else if (avgCol is num) {
      rawAvg = avgCol; // 兜底 NULL -> 0 的场景
    }

    snap.averageCost = rawAvg?.toDouble() ?? 0.0;

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

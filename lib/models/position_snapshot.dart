// 文件: lib/models/position_snapshot.dart
// (这是修复了 'cost_basis' 字段映射错误的代码)
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'position_snapshot.g.dart';

@collection
class PositionSnapshot {
  Id id = Isar.autoIncrement;

  late DateTime date;

  late double totalShares; // 总份额

  late double averageCost; // 单位成本 (Dart 内部使用的名字)

  /// 快照记录时的资产币种 -> 人民币汇率（便于后续收益拆分）
  double? fxRateToCny;

  /// 快照对应的人民币成本（如有）
  double? costBasisCny;

  @Index()
  String? assetSupabaseId; 

  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; 

  late DateTime createdAt;
  DateTime? updatedAt;
  
  PositionSnapshot();
  
  // --- Supabase 序列化/反序列化方法 ---
  
  factory PositionSnapshot.fromSupabaseJson(Map<String, dynamic> json) {
    final snap = PositionSnapshot();
    snap.supabaseId = json['id'];
    snap.updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']).toLocal() 
        : null;
    snap.createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at']).toLocal() 
        : DateTime.now();

    snap.date = DateTime.parse(json['date']).toLocal();
    snap.totalShares = (json['total_shares'] as num?)?.toDouble() ?? 0.0;

    // --- 关键修复：从 'cost_basis' 读取 ---
    snap.averageCost = (json['cost_basis'] as num?)?.toDouble() ?? 0.0; // <-- 修正
    // --- 修复结束 ---

    snap.fxRateToCny = (json['fx_rate_to_cny'] as num?)?.toDouble();
    snap.costBasisCny = (json['cost_basis_cny'] as num?)?.toDouble();
    
    snap.assetSupabaseId = json['asset_id']; 
    return snap;
  }
  
  Map<String, dynamic> toSupabaseJson() {
    return {
      'date': date.toIso8601String(),
      'total_shares': totalShares,
      
      // --- 关键修复：写入到 'cost_basis' ---
      'cost_basis': averageCost, // <-- 修正: Dart 属性 'averageCost' 映射到数据库列 'cost_basis'
      // --- 修复结束 ---

      'fx_rate_to_cny': fxRateToCny,
      'cost_basis_cny': costBasisCny,

      'asset_id': assetSupabaseId,
      'created_at': createdAt.toIso8601String(),
    };
  }
  // --- 新增结束 ---
}
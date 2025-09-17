// 文件: lib/models/position_snapshot.dart
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'position_snapshot.g.dart';

@collection
class PositionSnapshot {
  Id id = Isar.autoIncrement;

  late DateTime date;

  late double totalShares; // 总份额

  late double averageCost; // 单位成本

  // --- 关键变更：替换 IsarLink 为 SupabaseId 引用 ---
  // final asset = IsarLink<Asset>(); // <-- 旧的
  @Index()
  String? assetSupabaseId; // <-- 新的：存储所属 Asset 的 Supabase UUID
  // --- 变更结束 ---

  // --- 新增：Supabase 同步字段 ---
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; // 此 PositionSnapshot 自己的 Supabase UUID

  late DateTime createdAt;
  DateTime? updatedAt;
  // --- 新增结束 ---
  
  // --- 新增：空的构造函数 (Isar 需要) ---
  PositionSnapshot();
  
  // --- 新增：Supabase 序列化/反序列化方法 ---
  
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
    snap.averageCost = (json['average_cost'] as num?)?.toDouble() ?? 0.0;
    
    snap.assetSupabaseId = json['asset_id']; // 关联 Asset 的 UUID
    return snap;
  }
  
  Map<String, dynamic> toSupabaseJson() {
    return {
      'date': date.toIso8601String(),
      'total_shares': totalShares,
      'average_cost': averageCost,
      'asset_id': assetSupabaseId, // 同步关系链接
      'created_at': createdAt.toIso8601String(),
    };
  }
  // --- 新增结束 ---
}
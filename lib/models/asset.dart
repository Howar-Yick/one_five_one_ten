// 文件: lib/models/asset.dart
// (这是已修复 import 错误的完整文件)

import 'package:isar/isar.dart'; // ★★★ 修复点: 修正了此处的 import 路径 ★★★
part 'asset.g.dart';

// --- 资产大类 (这个枚举保持不变) ---
enum AssetClass {
  equity, // 权益类
  fixedIncome, // 固定收益类
  cashEquivalent, // 现金及等价物
  alternative, // 另类投资
  other, // 其他
}

// 跟踪方法 (保持不变)
enum AssetTrackingMethod {
  valueBased,
  shareBased,
}

// --- 资产类型 (SubType) ---
enum AssetSubType {
  stock, // 股票
  etf, // 场内基金
  mutualFund, // 场外基金
  wealthManagement, // 理财
  
  other, // 其他
}

@collection
class Asset {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;
  String code = '';
  double latestPrice = 0;
  DateTime? priceUpdateDate;

  @Index()
  String currency = 'CNY';

  @Enumerated(EnumType.name)
  late AssetTrackingMethod trackingMethod;
  @Enumerated(EnumType.name)
  late AssetSubType subType;

  @Index()
  @Enumerated(EnumType.name)
  AssetClass assetClass = AssetClass.other; 

  @Index()
  String? accountSupabaseId; 

  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; 

  late DateTime createdAt;
  DateTime? updatedAt;
  
  // ★★★ 新增字段 ★★★
  @Index()
  bool isArchived = false;
  // ★★★ 新增结束 ★★★
  
  Asset();

  factory Asset.fromSupabaseJson(Map<String, dynamic> json) {
    final asset = Asset();
    asset.supabaseId = json['id'];
    asset.updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at']).toLocal()
        : null;
    asset.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at']).toLocal()
        : DateTime.now();

    asset.name = json['name'] ?? '';
    asset.code = json['code'] ?? '';
    asset.latestPrice = (json['latest_price'] as num?)?.toDouble() ?? 0.0;
    asset.priceUpdateDate = json['price_update_date'] != null
        ? DateTime.parse(json['price_update_date']).toLocal()
        : null;
    asset.currency = json['currency'] ?? 'CNY';
    asset.trackingMethod = AssetTrackingMethod.values
        .byName(json['tracking_method'] ?? 'valueBased');
    asset.subType =
        AssetSubType.values.byName(json['sub_type'] ?? 'other');
    asset.assetClass =
        AssetClass.values.byName(json['asset_class'] ?? 'other');
    asset.accountSupabaseId = json['account_id'];

    // ★★★ 新增字段的解析 ★★★
    asset.isArchived = json['is_archived'] ?? false;
    // ★★★ 新增结束 ★★★
    
    return asset;
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'name': name,
      'code': code,
      'latest_price': latestPrice,
      'price_update_date': priceUpdateDate?.toIso8601String(),
      'currency': currency,
      'tracking_method': trackingMethod.name,
      'sub_type': subType.name,
      'asset_class': assetClass.name,
      'account_id': accountSupabaseId,
      'created_at': createdAt.toIso8601String(),
      // ★★★ 新增要同步的字段 ★★★
      'is_archived': isArchived,
      // ★★★ 新增结束 ★★★
    };
  }
}
// 文件: lib/models/asset.dart
import 'package:isar/isar.dart';
// 我们不再需要从这里导入 Account, PositionSnapshot 或 Transaction
// import 'package:one_five_one_ten/models/account.dart';
// import 'package:one_five_one_ten/models/position_snapshot.dart';
// import 'package:one_five_one_ten/models/transaction.dart';

part 'asset.g.dart';

// --- 新增：资产大类 ---
enum AssetClass {
  equity, // 权益类 (如: 股票, 股票型基金)
  fixedIncome, // 固定收益类 (如: 债券, 债券基金, 银行理财, 存款)
  cashEquivalent, // 现金及等价物 (如: 货币基金, 活期存款)
  alternative, // 另类投资 (如: 黄金, REITS)
  other, // 其他 (默认或未分类)
}
// --- 新增结束 ---


// Enums 保持不变
enum AssetTrackingMethod {
  valueBased,
  shareBased,
}

enum AssetSubType {
  stock,
  etf,
  mutualFund,
  // (*** 1. 关键修改：新增 "理财" ***)
  wealthManagement,
  // (*** 修改结束 ***)
  other,
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

  // --- 新增：资产大类字段 ---
  @Index() // 增加索引以便快速查询和分组
  @Enumerated(EnumType.name)
  AssetClass assetClass = AssetClass.other; // 资产大类，默认为 "other"
  // --- 新增结束 ---

  // --- 关键变更：替换 IsarLink 为 SupabaseId 引用 ---
  @Index()
  String? accountSupabaseId; // <-- 保留这个 (这定义了关系)
  // --- 变更结束 ---

  // --- 新增：Supabase 同步字段 ---
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; // 此 Asset 自己的 Supabase UUID

  late DateTime createdAt;
  DateTime? updatedAt;
  // --- 新增结束 ---

  // --- 已移除 ---
  // @Backlink(to: ...)
  // final snapshots = IsarLinks<PositionSnapshot>(); // <-- 移除
  // @Backlink(to: ...)
  // final transactions = IsarLinks<Transaction>(); // <-- 移除
  // --- 移除结束 ---

  // --- 新增：空的构造函数 (Isar 需要) ---
  Asset();

  // --- Supabase 序列化/反序列化方法 (保持不变) ---

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

    // --- 变更：读取新增字段 ---
    // 默认为 'other'，以兼容数据库中可能还没有此字段的旧数据
    asset.assetClass =
        AssetClass.values.byName(json['asset_class'] ?? 'other');
    // --- 变更结束 ---

    asset.accountSupabaseId = json['account_id']; // 关联 Account 的 UUID
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
      
      // --- 变更：同步新增字段 ---
      'asset_class': assetClass.name,
      // --- 变更结束 ---

      'account_id': accountSupabaseId, // 同步关系链接
      'created_at': createdAt.toIso8601String(),
    };
  }
// --- 新增结束 ---
}
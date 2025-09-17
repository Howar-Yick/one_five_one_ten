// 文件: lib/models/account.dart
import 'package:isar/isar.dart';
// 我们不再需要从这里导入 Asset 或 AccountTransaction
// import 'package:one_five_one_ten/models/account_transaction.dart';
// import 'package:one_five_one_ten/models/asset.dart';

part 'account.g.dart';

@collection
class Account {
  Id id = Isar.autoIncrement; // 本地 ID 保持不变
  late String name;
  late DateTime createdAt; 
  String? description;
  
  @Index()
  String currency = 'CNY'; 

  // --- 新增：Supabase 同步字段 ---
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; // Supabase 的主键 (UUID 字符串)

  DateTime? updatedAt; // Supabase 自动管理的 updated_at 时间戳
  // --- 新增结束 ---

  // --- 已移除 ---
  // @Backlink(to: ...)
  // final transactions = IsarLinks<AccountTransaction>(); // <-- 移除
  // @Backlink(to: ...)
  // final trackedAssets = IsarLinks<Asset>(); // <-- 移除
  // --- 移除结束 ---


  // --- 新增：空的构造函数 (Isar 需要) ---
  Account();

  // --- Supabase 序列化/反序列化方法 (保持不变) ---
  factory Account.fromSupabaseJson(Map<String, dynamic> json) {
    final acc = Account();
    acc.supabaseId = json['id'];
    acc.updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']).toLocal() 
        : null;
    acc.createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at']).toLocal()
        : DateTime.now(); 
        
    acc.name = json['name'] ?? '';
    acc.description = json['description'];
    acc.currency = json['currency'] ?? 'CNY';
    return acc;
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'name': name,
      'description': description,
      'currency': currency,
      'created_at': createdAt.toIso8601String(), 
    };
  }
}
// 文件: lib/models/transaction.dart
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'transaction.g.dart';

// Enum 保持不变
enum TransactionType {
  invest,   
  withdraw, 
  updateValue,
  buy,        
  sell,       
  dividend, 
}

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  late TransactionType type;

  late DateTime date;

  late double amount; 
  double? shares;   
  double? price;    

  String? note; 

  // --- 关键变更：替换 IsarLink 为 SupabaseId 引用 ---
  // final asset = IsarLink<Asset>(); // <-- 旧的
  @Index()
  String? assetSupabaseId; // <-- 新的：存储所属 Asset 的 Supabase UUID
  // --- 变更结束 ---

  // --- 新增：Supabase 同步字段 ---
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; // 此 Transaction 自己的 Supabase UUID

  late DateTime createdAt;
  DateTime? updatedAt;
  // --- 新增结束 ---
  
  // --- 新增：空的构造函数 (Isar 需要) ---
  Transaction();
  
  // --- 新增：Supabase 序列化/反序列化方法 ---
  
  factory Transaction.fromSupabaseJson(Map<String, dynamic> json) {
    final tx = Transaction();
    tx.supabaseId = json['id'];
    tx.updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']).toLocal() 
        : null;
    tx.createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at']).toLocal() 
        : DateTime.now();

    tx.type = TransactionType.values.byName(json['type'] ?? 'invest');
    tx.date = DateTime.parse(json['date']).toLocal();
    tx.amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    tx.shares = (json['quantity'] as num?)?.toDouble(); // 修正：从 'quantity' 字段读取
    tx.price = (json['price'] as num?)?.toDouble();
    tx.note = json['notes']; // 修正：从 'notes' 字段读取
    
    tx.assetSupabaseId = json['asset_id']; // 关联 Asset 的 UUID
    return tx;
  }
  
  Map<String, dynamic> toSupabaseJson() {
    final json = <String, dynamic>{};
    
    // 基本必需字段
    json['type'] = type.name;
    json['date'] = date.toIso8601String();
    json['amount'] = amount;
    json['asset_id'] = assetSupabaseId;
    json['created_at'] = createdAt.toIso8601String();
    json['updated_at'] = (updatedAt ?? DateTime.now()).toIso8601String();
    
    // 可选字段 - 只在有值时才添加，避免null值问题
    if (shares != null) {
      json['quantity'] = shares; // 映射到数据库的 'quantity' 字段
    }
    if (price != null) {
      json['price'] = price;
    }
    if (note != null && note!.isNotEmpty) {
      json['notes'] = note; // 映射到数据库的 'notes' 字段
    }
    
    return json;
  }
  // --- 新增结束 ---
}
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
    tx.shares = (json['shares'] as num?)?.toDouble();
    tx.price = (json['price'] as num?)?.toDouble();
    tx.note = json['note'];
    
    tx.assetSupabaseId = json['asset_id']; // 关联 Asset 的 UUID
    return tx;
  }
  
  Map<String, dynamic> toSupabaseJson() {
    return {
      'type': type.name,
      'date': date.toIso8601String(),
      'amount': amount,
      'shares': shares,
      'price': price,
      'note': note,
      'asset_id': assetSupabaseId, // 同步关系链接
      'created_at': createdAt.toIso8601String(),
    };
  }
  // --- 新增结束 ---
}
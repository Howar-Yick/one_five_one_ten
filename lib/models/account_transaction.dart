// 文件: lib/models/account_transaction.dart
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/transaction.dart'; // 引入统一的Transaction模型

part 'account_transaction.g.dart';

// 此文件中不再定义 TransactionType，而是使用从 transaction.dart 引入的

@collection
class AccountTransaction {
  Id id = Isar.autoIncrement;

  late DateTime date;

  @Enumerated(EnumType.name)
  late TransactionType type; // 来自 transaction.dart

  late double amount;

  // --- 关键变更：替换 IsarLink 为 SupabaseId 引用 ---
  // final account = IsarLink<Account>(); // <-- 旧的
  @Index()
  String? accountSupabaseId; // <-- 新的：存储所属 Account 的 Supabase UUID
  // --- 变更结束 ---

  // --- 新增：Supabase 同步字段 ---
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId; // 此 AccountTransaction 自己的 Supabase UUID

  late DateTime createdAt;
  DateTime? updatedAt;
  // --- 新增结束 ---
  
  // --- 新增：空的构造函数 (Isar 需要) ---
  AccountTransaction();

  // --- 新增：Supabase 序列化/反序列化方法 ---
  
  factory AccountTransaction.fromSupabaseJson(Map<String, dynamic> json) {
    final accTx = AccountTransaction();
    accTx.supabaseId = json['id'];
    accTx.updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']).toLocal() 
        : null;
    accTx.createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at']).toLocal() 
        : DateTime.now();
        
    accTx.date = DateTime.parse(json['date']).toLocal();
    accTx.type = TransactionType.values.byName(json['type'] ?? 'invest');
    accTx.amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    
    accTx.accountSupabaseId = json['account_id']; // 关联 Account 的 UUID
    return accTx;
  }
  
  Map<String, dynamic> toSupabaseJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.name,
      'amount': amount,
      'account_id': accountSupabaseId, // 同步关系链接
      'created_at': createdAt.toIso8601String(),
    };
  }
  // --- 新增结束 ---
}
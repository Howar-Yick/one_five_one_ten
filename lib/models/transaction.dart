// 文件: lib/models/transaction.dart
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'transaction.g.dart';

/// 交易类型
enum TransactionType {
  invest,      // 资产层资金投入
  withdraw,    // 资产层资金转出
  updateValue, // 更新价值法资产总值
  buy,         // 份额法买入
  sell,        // 份额法卖出
  dividend,    // 分红/利息
}

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  late TransactionType type;

  /// 事件发生时间（本地时区）
  late DateTime date;

  /// 金额：
  /// - 价值法：此次资金变动金额（资产币种）
  /// - 份额法：成交金额（资产币种，买入为正，卖出为负）
  late double amount;

  /// 份额法才用到的成交份额
  double? shares;

  /// 份额法才用到的成交价格（资产币种）
  double? price;

  /// 资产交易发生时的资产币种 -> 人民币汇率
  ///
  /// 例如：USD 资产，则为 USD→CNY 的汇率。
  double? fxRateToCny;

  /// 该笔交易折算成人民币的金额（买入为正，卖出为负）
  ///
  /// 主要用于后续拆分“标的自身收益”和“汇率收益”。
  double? amountCny;

  /// 备注
  String? note;

  /// 所属资产的 Supabase UUID（替代 IsarLink）
  @Index()
  String? assetSupabaseId;

  /// 本条交易自身的 Supabase UUID
  @Index(type: IndexType.value, unique: true, caseSensitive: false)
  String? supabaseId;

  /// 创建时间（本地）
  late DateTime createdAt;

  /// 最近更新时间（本地）
  DateTime? updatedAt;

  Transaction();

  // ===== Supabase 映射 =====

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory Transaction.fromSupabaseJson(Map<String, dynamic> json) {
    final tx = Transaction();

    tx.supabaseId = json['id'] as String?;
    tx.updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String).toLocal()
        : null;
    tx.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String).toLocal()
        : DateTime.now();

    final typeStr = (json['type'] as String?) ?? 'invest';
    tx.type = TransactionType.values.byName(typeStr);

    tx.date = DateTime.parse(json['date'] as String).toLocal();

    tx.amount = _parseNum(json['amount']) ?? 0.0;
    tx.shares = _parseNum(json['quantity']);
    tx.price = _parseNum(json['price']);
    tx.note = json['notes'] as String?;

    tx.fxRateToCny = _parseNum(json['fx_rate_to_cny']);
    tx.amountCny = _parseNum(json['amount_cny']);

    tx.assetSupabaseId = json['asset_id'] as String?;

    return tx;
  }

  Map<String, dynamic> toSupabaseJson() {
    final json = <String, dynamic>{};

    // 基本必填字段
    json['type'] = type.name;
    json['date'] = date.toUtc().toIso8601String();
    json['amount'] = amount;
    json['asset_id'] = assetSupabaseId;
    json['created_at'] = createdAt.toUtc().toIso8601String();
    json['updated_at'] = (updatedAt ?? DateTime.now()).toUtc().toIso8601String();

    // FX 相关字段：只在非 null 时写入
    if (fxRateToCny != null) {
      json['fx_rate_to_cny'] = fxRateToCny;
    }
    if (amountCny != null) {
      json['amount_cny'] = amountCny;
    }

    // 可选字段
    if (shares != null) {
      json['quantity'] = shares;
    }
    if (price != null) {
      json['price'] = price;
    }
    if (note != null && note!.isNotEmpty) {
      json['notes'] = note;
    }

    // id 由 Supabase 分配，这里不主动写入；_saveObject 会在有 supabaseId 时补上 json['id']
    return json;
  }
}

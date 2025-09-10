import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';

part 'transaction.g.dart';

// 这个枚举比 AccountTransaction 的更丰富
enum TransactionType {
  invest,     // 投入 (价值法)
  withdraw,   // 转出 (价值法)
  updateValue,// 更新总价值 (价值法)
  buy,        // 买入 (份额法)
  sell,       // 卖出 (份额法)
  dividend,   // 分红 (份额法)
}

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  late TransactionType type;

  late DateTime date;

  late double amount; // 交易总金额
  double? shares;   // 交易份额 (份额法专属)
  double? price;    // 交易价格 (份额法专属)

  String? note; // 备注

  // 反向链接到所属的资产
  final asset = IsarLink<Asset>();
}
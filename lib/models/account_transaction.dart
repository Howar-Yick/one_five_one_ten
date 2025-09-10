import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';

part 'account_transaction.g.dart';

enum TransactionType {
  invest,
  withdraw,
  updateTotalValue,
}

@collection
class AccountTransaction {
  Id id = Isar.autoIncrement;

  late DateTime date;

  @Enumerated(EnumType.name) // 数据库中以字符串形式存储枚举值，更具可读性
  late TransactionType type;

  late double amount; // 交易金额

  // 指向所属的账户
  final account = IsarLink<Account>();
}
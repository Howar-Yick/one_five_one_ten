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
  late TransactionType type; // 现在这个类型来自 transaction.dart

  late double amount;

  final account = IsarLink<Account>();
}
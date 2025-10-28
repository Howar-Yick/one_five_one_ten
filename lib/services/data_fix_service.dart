// 文件: lib/services/data_fix_service.dart
// 这是一个一次性的数据修复服务，用于修正历史数据
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/transaction.dart'; // 引入 TransactionType 枚举
import 'package:one_five_one_ten/services/database_service.dart';

class DataFixService {
  
  /// 查找所有类型为 'invest' 或 'withdraw' 但金额为负数的记录，
  /// 并将它们的金额修正为正数（取绝对值）。
  static Future<void> fixNegativeTransactions() async {
    final isar = DatabaseService().isar;

    // 1. 查找所有金额为负的 "投入" 记录
    final badInvestTxs = await isar.accountTransactions
        .where()
        .filter()
        .typeEqualTo(TransactionType.invest)
        .and()
        .amountLessThan(0)
        .findAll();

    // 2. 查找所有金额为负的 "转出" 记录 (以防万一)
    final badWithdrawTxs = await isar.accountTransactions
        .where()
        .filter()
        .typeEqualTo(TransactionType.withdraw)
        .and()
        .amountLessThan(0)
        .findAll();

    final List<AccountTransaction> txsToFix = [];
    txsToFix.addAll(badInvestTxs);
    txsToFix.addAll(badWithdrawTxs);

    if (txsToFix.isEmpty) {
      print('[DataFixService] 未找到需要修复的错误数据。');
      return;
    }

    print('[DataFixService] 找到 ${txsToFix.length} 条需要修复的记录。');

    // 3. 遍历所有找到的记录，将 amount 修正为绝对值（正数）
    for (var tx in txsToFix) {
      print('[DataFixService] 修复中: ID ${tx.id}, 类型 ${tx.type.name}, 错误金额 ${tx.amount}');
      tx.amount = tx.amount.abs(); // 取绝对值
    }

    // 4. 将所有修复后的记录一次性写回数据库
    await isar.writeTxn(() async {
      await isar.accountTransactions.putAll(txsToFix);
    });

    print('[DataFixService] 修复完成！');
  }
}
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/utils/xirr.dart'; // <--- 关键修改：引入本地的xirr.dart

class CalculatorService {
  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    await account.transactions.load();
    final transactions = account.transactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // 确保按日期排序

    double totalInvested = 0;
    double totalWithdrawn = 0;
    AccountTransaction? lastUpdate;

    for (var txn in transactions) {
      if (txn.type == TransactionType.invest) {
        totalInvested += txn.amount;
      } else if (txn.type == TransactionType.withdraw) {
        totalWithdrawn += txn.amount;
      } else if (txn.type == TransactionType.updateTotalValue) {
        lastUpdate = txn;
      }
    }

    final double netInvestment = totalInvested - totalWithdrawn;
    final double currentValue = lastUpdate?.amount ?? 0.0;
    final double totalProfit = currentValue - netInvestment;
    final double profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;

    double annualizedReturn = 0.0;
    final cashflows = <double>[];
    final dates = <DateTime>[];

    for (var txn in transactions) {
      if (txn.type == TransactionType.invest) {
        cashflows.add(-txn.amount);
        dates.add(txn.date);
      } else if (txn.type == TransactionType.withdraw) {
        cashflows.add(txn.amount);
        dates.add(txn.date);
      }
    }

    if (lastUpdate != null && cashflows.isNotEmpty) {
      cashflows.add(currentValue);
      dates.add(lastUpdate.date);
      if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
        try {
          // --- 关键修改：直接调用本地函数，无需 await ---
          final result = xirr(dates, cashflows);
          annualizedReturn = result; // 返回值已经是小数
        } catch (e) {
          annualizedReturn = 0.0;
        }
      }
    }
    
    return {
      'currentValue': currentValue,
      'netInvestment': netInvestment,
      'totalProfit': totalProfit,
      'profitRate': profitRate,
      'annualizedReturn': annualizedReturn,
    };
  }
}
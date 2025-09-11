import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/utils/xirr.dart';

class CalculatorService {
  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    await account.transactions.load();
    final transactions = account.transactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

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
          final result = xirr(dates, cashflows);
          annualizedReturn = result;
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

  Future<Map<String, dynamic>> calculateShareAssetPerformance(Asset asset) async {
    await asset.snapshots.load();
    final snapshots = asset.snapshots.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (snapshots.isEmpty) {
      return {
        'marketValue': 0.0, 'totalCost': 0.0, 'totalProfit': 0.0,
        'profitRate': 0.0, 'annualizedReturn': 0.0,
        'totalShares': 0.0, 'averageCost': 0.0, 'latestPrice': 0.0,
      };
    }

    final latestSnapshot = snapshots.last;
    final totalShares = latestSnapshot.totalShares;
    final averageCost = latestSnapshot.averageCost;
    final totalCost = totalShares * averageCost;
    
    // TODO: 暂时手动设置最新价，后续从网络同步
    final latestPrice = asset.latestPrice == 0 ? averageCost : asset.latestPrice; 
    final marketValue = totalShares * latestPrice;
    final totalProfit = marketValue - totalCost;
    final profitRate = totalCost == 0 ? 0 : totalProfit / totalCost;

    double annualizedReturn = 0.0;
    if (snapshots.length >= 1) { // 只要有一次快照就可以开始计算
      final dates = <DateTime>[];
      final cashflows = <double>[];

      dates.add(snapshots.first.date);
      cashflows.add(-(snapshots.first.totalShares * snapshots.first.averageCost));

      for (int i = 1; i < snapshots.length; i++) {
        final prevCost = snapshots[i - 1].totalShares * snapshots[i - 1].averageCost;
        final currentCost = snapshots[i].totalShares * snapshots[i].averageCost;
        final costChange = currentCost - prevCost;
        if (costChange.abs() > 0.01) {
          dates.add(snapshots[i].date);
          cashflows.add(-costChange);
        }
      }
      
      // 使用当前日期或快照最后日期作为终点
      dates.add(DateTime.now().difference(snapshots.last.date).inDays > 1 ? DateTime.now() : snapshots.last.date);
      cashflows.add(marketValue);
      
      try {
        if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
          annualizedReturn = xirr(dates, cashflows);
        }
      } catch (e) {
        // 计算失败
      }
    }

    return {
      'marketValue': marketValue,
      'totalCost': totalCost,
      'totalProfit': totalProfit,
      'profitRate': profitRate,
      'annualizedReturn': annualizedReturn,
      'totalShares': totalShares,
      'averageCost': averageCost,
      'latestPrice': latestPrice,
    };
  }
}
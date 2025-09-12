import 'package:fl_chart/fl_chart.dart'; 
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/utils/xirr.dart';
import 'package:one_five_one_ten/services/database_service.dart'; // <--- 修正：添加这一行

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
      } else if (txn.type == TransactionType.updateValue) {
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
    
    final latestPrice = asset.latestPrice == 0 ? averageCost : asset.latestPrice; 
    final marketValue = totalShares * latestPrice;
    final totalProfit = marketValue - totalCost;
    final profitRate = totalCost == 0 ? 0 : totalProfit / totalCost;

    double annualizedReturn = 0.0;
    if (snapshots.length >= 1) {
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
      
      final lastDate = snapshots.last.date;
      dates.add(DateTime.now().difference(lastDate).inDays > 1 ? DateTime.now() : lastDate);
      cashflows.add(marketValue);
      
      try {
        if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
          annualizedReturn = xirr(dates, cashflows);
        }
      } catch (e) {
        //
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

  Future<List<FlSpot>> getAccountValueHistory(Account account) async {
    await account.transactions.load();
    final transactions = account.transactions.toList();
    if (transactions.isEmpty) return [];

    transactions.sort((a, b) => a.date.compareTo(b.date));

    final List<FlSpot> spots = [];
    double latestValue = 0;

    final Map<DateTime, double> dailyValues = {};

    for (var txn in transactions) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      if (txn.type == TransactionType.updateValue) {
        dailyValues[day] = txn.amount;
      }
    }

    if (dailyValues.isEmpty) return [];

    final startDate = transactions.first.date;
    final endDate = DateTime.now();

    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final day = DateTime(startDate.year, startDate.month, startDate.day + i);

      if (dailyValues.containsKey(day)) {
        latestValue = dailyValues[day]!;
      }

      spots.add(FlSpot(day.millisecondsSinceEpoch.toDouble(), latestValue));
    }

    return spots;
  }

  Future<List<FlSpot>> getGlobalValueHistory() async {
    final isar = DatabaseService().isar;
    final allTransactions = await isar.collection<AccountTransaction>().where().findAll();
    if (allTransactions.isEmpty) return [];

    allTransactions.sort((a, b) => a.date.compareTo(b.date));

    final Map<DateTime, Map<int, double>> dailyAccountValues = {};

    for (var txn in allTransactions) {
      if (txn.type == TransactionType.updateValue) {
        final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
        final accountId = txn.account.value?.id ?? -1;
        if(accountId == -1) continue;

        dailyAccountValues.putIfAbsent(day, () => {});
        dailyAccountValues[day]![accountId] = txn.amount;
      }
    }

    if (dailyAccountValues.isEmpty) return [];

    final List<FlSpot> spots = [];
    final startDate = allTransactions.first.date;
    final endDate = DateTime.now();

    Map<int, double> latestValues = {};

    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final day = DateTime(startDate.year, startDate.month, startDate.day + i);

      if (dailyAccountValues.containsKey(day)) {
        dailyAccountValues[day]!.forEach((accountId, value) {
          latestValues[accountId] = value;
        });
      }

      double totalValue = latestValues.values.fold(0.0, (sum, item) => sum + item);
      spots.add(FlSpot(day.millisecondsSinceEpoch.toDouble(), totalValue));
    }

    return spots;
  }

  Future<Map<String, dynamic>> calculateValueAssetPerformance(Asset asset) async {
    await asset.transactions.load();
    final transactions = asset.transactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double totalInvested = 0;
    double totalWithdrawn = 0;
    Transaction? lastUpdate;

    for (var txn in transactions) {
      if (txn.type == TransactionType.invest) {
        totalInvested += txn.amount;
      } else if (txn.type == TransactionType.withdraw) {
        totalWithdrawn += txn.amount;
      } else if (txn.type == TransactionType.updateValue) {
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
          annualizedReturn = xirr(dates, cashflows);
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

  Future<Map<AssetSubType, double>> calculateAssetAllocation() async {
    final isar = DatabaseService().isar;
    final allAssets = await isar.assets.where().findAll();

    final Map<AssetSubType, double> allocation = {};

    for (final asset in allAssets) {
      Map<String, dynamic> performance;
      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        performance = await calculateShareAssetPerformance(asset);
        // 对于份额法，我们使用 marketValue
        final value = (performance['marketValue'] ?? 0.0) as double;
        // 按子类型累加
        allocation.update(asset.subType, (existing) => existing + value, ifAbsent: () => value);
      } else { // 价值法
        performance = await calculateValueAssetPerformance(asset);
        // 对于价值法，我们使用 currentValue
        final value = (performance['currentValue'] ?? 0.0) as double;
        // 价值法资产的子类型我们默认为 other
        allocation.update(AssetSubType.other, (existing) => existing + value, ifAbsent: () => value);
      }
    }

    // 移除总价值为0或负数的类别，避免在饼图中显示
    allocation.removeWhere((key, value) => value <= 0);

    return allocation;
  }  

  Future<Map<String, dynamic>> calculateGlobalPerformance() async {
    final isar = DatabaseService().isar;
    final allAccounts = await isar.accounts.where().anyId().findAll();
    // 同时获取所有顶层交易记录
    final allTransactions = await isar.collection<AccountTransaction>().where().findAll();

    double totalValue = 0;
    double totalNetInvestment = 0;
    double totalInvested = 0; // 需要总投入来计算总收益率

    for (final account in allAccounts) {
      // 复用账户计算逻辑来获取每个账户的当前价值和净投入
      final performance = await calculateAccountPerformance(account);
      totalValue += (performance['currentValue'] ?? 0.0) as double;
      totalNetInvestment += (performance['netInvestment'] ?? 0.0) as double;
    }
    
    // 为了计算总收益率，我们需要遍历所有交易来获取总投入
    for (final txn in allTransactions) {
      if (txn.type == TransactionType.invest) {
        totalInvested += txn.amount;
      }
    }

    final double totalProfit = totalValue - totalNetInvestment;
    final double totalProfitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;

    // --- 新增：计算全局年化收益率 ---
    double globalAnnualizedReturn = 0.0;
    final cashflows = <double>[];
    final dates = <DateTime>[];

    for (var txn in allTransactions) {
      if (txn.type == TransactionType.invest) {
        cashflows.add(-txn.amount);
        dates.add(txn.date);
      } else if (txn.type == TransactionType.withdraw) {
        cashflows.add(txn.amount);
        dates.add(txn.date);
      }
    }

    // 只要有现金流发生，并且总资产有价值，就进行计算
    if (cashflows.isNotEmpty && totalValue > 0) {
      cashflows.add(totalValue);
      dates.add(DateTime.now()); // 以今天作为最终价值的日期
      
      if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
        try {
          globalAnnualizedReturn = xirr(dates, cashflows);
        } catch (e) {
          // 计算失败
        }
      }
    }

    return {
      'totalValue': totalValue,
      'totalProfit': totalProfit,
      'totalProfitRate': totalProfitRate,
      'globalAnnualizedReturn': globalAnnualizedReturn, // 返回新计算出的值
    };
  }
}
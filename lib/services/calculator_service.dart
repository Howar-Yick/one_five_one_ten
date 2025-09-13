import 'package:fl_chart/fl_chart.dart'; 
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/utils/xirr.dart';
import 'package:one_five_one_ten/services/database_service.dart'; // <--- 修正：添加这一行
import 'package:intl/intl.dart';

// ----- 辅助类：用于处理价值法计算和图表的数据点 -----
class _ValueHistoryPoint {
  final DateTime date;
  double value; // 当天最终的资产总值
  double cashFlow; // 当天的现金流 (+代表转出, -代表投入)

  _ValueHistoryPoint({required this.date, this.value = 0, this.cashFlow = 0});
}

class CalculatorService {
/// 辅助函数：根据新的混合逻辑处理价值法交易列表 (AccountTransaction 或 Transaction)
  List<_ValueHistoryPoint> _processValueTransactions(List<dynamic> transactions) {
    if (transactions.isEmpty) {
      return [];
    }

    // 确保按完整日期时间排序
    transactions.sort((a, b) => a.date.compareTo(b.date));

    final Map<DateTime, _ValueHistoryPoint> dailyPoints = {};
    double runningValue = 0.0;
    
    // 跟踪上一个已知值，用于结转
    _ValueHistoryPoint? lastPoint;

    for (final txn in transactions) {
      // 1. 获取当天（剥离时间）
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);

      // 2. 结转上一天的价值
      if (!dailyPoints.containsKey(day)) {
        // 如果这是新的一天，它的初始值等于上一天（或上一个点）的最终值
        runningValue = lastPoint?.value ?? 0.0;
        dailyPoints[day] = _ValueHistoryPoint(date: day, value: runningValue, cashFlow: 0);
      }

      // 3. 应用当前交易的逻辑
      if (txn.type == TransactionType.invest) {
        runningValue += txn.amount;
        dailyPoints[day]!.cashFlow -= txn.amount; // 投入是负现金流
      } else if (txn.type == TransactionType.withdraw) {
        runningValue -= txn.amount;
        dailyPoints[day]!.cashFlow += txn.amount; // 转出是正现金流
      } else if (txn.type == TransactionType.updateValue) {
        runningValue = txn.amount; // 手动快照，覆盖自动值
      }

      // 4. 将当天的最终值（处理完所有交易后）更新到Map中
      dailyPoints[day]!.value = runningValue;
      lastPoint = dailyPoints[day]; // 更新“上一个点”
    }

    // 5. 将Map转为排序后的列表 (Map的key已按日期排序，values会按插入顺序)
    return dailyPoints.values.toList();
  }

  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    await account.transactions.load();
    // 使用新的混合逻辑处理器
    final historyPoints = _processValueTransactions(account.transactions.toList());

    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    double totalInvested = 0;
    double netInvestment = 0;
    final cashflows = <double>[];
    final dates = <DateTime>[];

    for (final point in historyPoints) {
      if (point.cashFlow < 0) { // 投入
        totalInvested += -point.cashFlow;
      }
      netInvestment += -point.cashFlow; // 净投入 = 投入 - 转出
      
      if(point.cashFlow != 0) {
        cashflows.add(point.cashFlow);
        dates.add(point.date);
      }
    }
    
    final currentValue = historyPoints.last.value;
    final totalProfit = currentValue - netInvestment;
    final profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;

    double annualizedReturn = 0.0;
    if (cashflows.isNotEmpty) {
      cashflows.add(currentValue);
      dates.add(DateTime.now()); 
      
      if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
        try {
          annualizedReturn = xirr(dates, cashflows);
        } catch (e) { /* 计算失败 */ }
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
    final historyPoints = _processValueTransactions(account.transactions.toList());
    
    if (historyPoints.length < 2) return [];
    
    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  }

  Future<List<FlSpot>> getGlobalValueHistory() async {
    final isar = DatabaseService().isar;
    final allTransactions = await isar.collection<AccountTransaction>().where().anyId().findAll();
    
    final historyPoints = _processValueTransactions(allTransactions);

    if (historyPoints.length < 2) return [];
    
    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  }

  Future<List<FlSpot>> getValueAssetHistory(Asset asset) async {
    await asset.transactions.load();
    final valueUpdates = asset.transactions
        .where((txn) => txn.type == TransactionType.updateValue)
        .toList();

    if (valueUpdates.isEmpty) return [];

    final Map<DateTime, Transaction> latestDailyUpdates = {};
    for (final txn in valueUpdates) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      if (!latestDailyUpdates.containsKey(day) || txn.date.isAfter(latestDailyUpdates[day]!.date)) {
        latestDailyUpdates[day] = txn;
      }
    }

    if (latestDailyUpdates.length < 2) return [];

    final sortedTxs = latestDailyUpdates.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    return sortedTxs.map((txn) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      return FlSpot(day.millisecondsSinceEpoch.toDouble(), txn.amount);
    }).toList();
  }  

  Future<Map<String, dynamic>> calculateValueAssetPerformance(Asset asset) async {
    await asset.transactions.load();
    final transactions = asset.transactions.toList(); 

    // 完全复用相同的混合逻辑处理器
    final historyPoints = _processValueTransactions(transactions);

    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    double totalInvested = 0;
    double netInvestment = 0;
    final cashflows = <double>[];
    final dates = <DateTime>[];

    for (final point in historyPoints) {
      if (point.cashFlow < 0) {
        totalInvested += -point.cashFlow;
      }
      netInvestment += -point.cashFlow;
      
      if(point.cashFlow != 0) {
        cashflows.add(point.cashFlow);
        dates.add(point.date);
      }
    }
    
    final currentValue = historyPoints.last.value;
    final totalProfit = currentValue - netInvestment;
    final profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;

    double annualizedReturn = 0.0;
    if (cashflows.isNotEmpty) {
      cashflows.add(currentValue);
      dates.add(DateTime.now());
      
      if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
        try {
          annualizedReturn = xirr(dates, cashflows);
        } catch (e) { /* 计算失败 */ }
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
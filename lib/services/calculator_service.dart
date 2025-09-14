import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/utils/xirr.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart'; // 引入汇率服务

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

    // 5. 将Map转为排序后的列表
    return dailyPoints.values.toList();
  }

  // --- 顶层账户的性能计算 (已更新为混合逻辑和多币种) ---
  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    await account.transactions.load();
    await account.trackedAssets.load();
    final transactions = account.transactions.toList();
    final assets = account.trackedAssets.toList();
    final fx = ExchangeRateService();

    // 1. 计算账户自身的价值法业绩（以账户自身币种计算）
    final historyPoints = _processValueTransactions(transactions);
    
    double selfValue = historyPoints.isEmpty ? 0.0 : historyPoints.last.value;
    double netInvestment = 0;
    double totalInvested = 0;
    final cashflows = <double>[];
    final dates = <DateTime>[];

    for (final point in historyPoints) {
      if (point.cashFlow < 0) totalInvested += -point.cashFlow;
      netInvestment += -point.cashFlow;
      if (point.cashFlow != 0) {
        cashflows.add(point.cashFlow);
        dates.add(point.date);
      }
    }

    // 2. 加总所有子资产的价值（全部换算成账户的币种）
    double totalChildAssetsValue = 0.0;
    for (final asset in assets) {
      Map<String, dynamic> assetPerf;
      double assetLocalValue = 0.0;

      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        assetPerf = await calculateShareAssetPerformance(asset);
        assetLocalValue = (assetPerf['marketValue'] ?? 0.0) as double;
      } else {
        assetPerf = await calculateValueAssetPerformance(asset);
        assetLocalValue = (assetPerf['currentValue'] ?? 0.0) as double;
      }

      // 换算汇率：将资产币种 换算成 账户币种
      double rate = await fx.getRate(asset.currency, account.currency);
      totalChildAssetsValue += assetLocalValue * rate;
    }
    
    // 3. 账户最终总值 = 自身价值 + 子资产价值
    final double currentValue = selfValue + totalChildAssetsValue;
    final double totalProfit = currentValue - netInvestment;
    final double profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;

    // 4. 计算年化（XIRR只计算账户自身的现金流和价值）
    double annualizedReturn = 0.0;
    if (cashflows.isNotEmpty) {
      cashflows.add(currentValue); // 注意：这里用的是包含子资产的最终总值
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
  
  // --- 份额法资产的性能计算 (基于您的版本，保持不变) ---
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

  // --- 账户图表数据生成 (使用新逻辑) ---
  Future<List<FlSpot>> getAccountValueHistory(Account account) async {
    await account.transactions.load();
    final historyPoints = _processValueTransactions(account.transactions.toList());
    
    if (historyPoints.length < 2) return [];
    
    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  }

  // --- 全局图表数据生成 (使用新逻辑) ---
  Future<List<FlSpot>> getGlobalValueHistory() async {
    final isar = DatabaseService().isar;
    final allTransactions = await isar.collection<AccountTransaction>().where().anyId().findAll();
    
    final historyPoints = _processValueTransactions(allTransactions);

    if (historyPoints.length < 2) return [];
    
    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  }

  // --- 价值法资产图表数据生成 (使用新逻辑) ---
  Future<List<FlSpot>> getValueAssetHistory(Asset asset) async {
    await asset.transactions.load();
    final historyPoints = _processValueTransactions(asset.transactions.toList());

    if (historyPoints.length < 2) return [];

    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  } 

  // --- 价值法资产性能计算 (使用新逻辑) ---
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

  // --- 资产配置计算 (加入汇率换算) ---
  Future<Map<AssetSubType, double>> calculateAssetAllocation() async {
    final isar = DatabaseService().isar;
    final allAssets = await isar.assets.where().anyId().findAll();
    final fx = ExchangeRateService();

    final Map<AssetSubType, double> allocationCNY = {};

    for (final asset in allAssets) {
      Map<String, dynamic> performance;
      double assetLocalValue = 0.0;

      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        performance = await calculateShareAssetPerformance(asset);
        assetLocalValue = (performance['marketValue'] ?? 0.0) as double;
      } else { 
        performance = await calculateValueAssetPerformance(asset);
        assetLocalValue = (performance['currentValue'] ?? 0.0) as double;
      }
      
      // 全部换算成CNY再汇总
      final double rate = await fx.getRate(asset.currency, 'CNY');
      final double assetValueCNY = assetLocalValue * rate;

      allocationCNY.update(asset.subType, (existing) => existing + assetValueCNY, ifAbsent: () => assetValueCNY);
    }
    allocationCNY.removeWhere((key, value) => value <= 0);
    return allocationCNY;
  }

  // --- 全局业绩计算 (加入汇率换算) ---
  Future<Map<String, dynamic>> calculateGlobalPerformance() async {
    final isar = DatabaseService().isar;
    final allAccounts = await isar.accounts.where().anyId().findAll();
    final fx = ExchangeRateService();

    double totalValueCNY = 0;
    double totalNetInvestmentCNY = 0;
    double totalInvestedCNY = 0;
    
    final globalCashflows = <double>[];
    final globalDates = <DateTime>[];

    for (final account in allAccounts) {
      // 复用我们全新的、正确的账户计算逻辑
      final performance = await calculateAccountPerformance(account);
      // 获取到CNY的汇率
      final double rate = await fx.getRate(account.currency, 'CNY');

      final accValue = (performance['currentValue'] ?? 0.0) as double;
      final accNetInv = (performance['netInvestment'] ?? 0.0) as double;

      // 累加CNY总值
      totalValueCNY += accValue * rate;
      totalNetInvestmentCNY += accNetInv * rate;

      // 累加全局现金流（换算为CNY）
      await account.transactions.load();
      for (final txn in account.transactions) {
          if (txn.type == TransactionType.invest) {
            double amountCNY = txn.amount * rate;
            globalCashflows.add(-amountCNY);
            globalDates.add(txn.date);
            totalInvestedCNY += amountCNY;
          } else if (txn.type == TransactionType.withdraw) {
            double amountCNY = txn.amount * rate;
            globalCashflows.add(amountCNY);
            globalDates.add(txn.date);
          }
      }
    }
    
    final double totalProfit = totalValueCNY - totalNetInvestmentCNY;
    final double totalProfitRate = totalInvestedCNY == 0 ? 0 : totalProfit / totalInvestedCNY;

    double globalAnnualizedReturn = 0.0;
    if (globalCashflows.isNotEmpty && totalValueCNY != 0) {
      globalCashflows.add(totalValueCNY);
      globalDates.add(DateTime.now());
      
      if (globalCashflows.any((cf) => cf > 0) && globalCashflows.any((cf) => cf < 0)) {
        try {
          globalAnnualizedReturn = xirr(globalDates, globalCashflows);
        } catch (e) {
          //
        }
      }
    }

    return {
      'totalValue': totalValueCNY,
      'totalProfit': totalProfit,
      'totalProfitRate': totalProfitRate,
      'globalAnnualizedReturn': globalAnnualizedReturn,
    };
  }
}
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
import 'package:one_five_one_ten/services/exchangerate_service.dart';

class _ValueHistoryPoint {
  final DateTime date;
  double value;
  double cashFlow;

  _ValueHistoryPoint({required this.date, this.value = 0, this.cashFlow = 0});
}

class CalculatorService {

  // --- 修正：还原为纯粹的价值法计算（有知有行模式），不关心子资产 ---
  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    await account.transactions.load();
    
    // 使用与 "价值法资产" 相同的运行总值计算逻辑 (此辅助函数已存在于文件中)
    // 它可以正确处理 AccountTransaction 列表
    final historyPoints = _processValueTransactions(account.transactions.toList());

    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    double totalInvested = 0;
    double netInvestment = 0;
    final cashflows = <double>[]; // 用于XIRR计算的聚合现金流
    final dates = <DateTime>[];

    // 遍历按天聚合后的历史点
    for (final point in historyPoints) {
      // 在辅助函数中，投入(invest)的 cashFlow 被记为负数
      if (point.cashFlow < 0) {
         totalInvested += -point.cashFlow;
      }
      netInvestment += -point.cashFlow; // 净投入是所有现金流（反转符号后）的总和
      
      if (point.cashFlow != 0) {
        cashflows.add(point.cashFlow);
        dates.add(point.date);
      }
    }

    // 正确的当前值是 historyPoints 的最后一个值
    final double currentValue = historyPoints.last.value;
    final double totalProfit = currentValue - netInvestment;
    final double profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;
    
    double annualizedReturn = 0.0;
    
    // XIRR 计算 (使用聚合后的每日现金流)
    // 注意：为了更精确的 XIRR，我们应该使用原始交易列表，而不是聚合后的 historyPoints。
    // 我们将保留原始方法中对 XIRR 的计算方式，因为它遍历的是原始 transactions 列表，是正确的。
    
    final xirrCashflows = <double>[];
    final xirrDates = <DateTime>[];
    
    // 重新加载原始交易列表（注意：historyPoints 仅用于获取正确的 currentValue 和 totalInvested）
    final originalTransactions = account.transactions.toList()..sort((a, b) => a.date.compareTo(b.date));

    for (var txn in originalTransactions) {
      if (txn.type == TransactionType.invest) {
        xirrCashflows.add(-txn.amount);
        xirrDates.add(txn.date);
      } else if (txn.type == TransactionType.withdraw) {
        xirrCashflows.add(txn.amount);
        xirrDates.add(txn.date);
      }
    }

    if (xirrCashflows.isNotEmpty && currentValue != 0) {
      xirrCashflows.add(currentValue);
      // XIRR的最后一点必须是 currentValue 对应的日期。
      // 我们使用 historyPoints 的最后日期，因为它代表最后一次活动（投入/转出 或 更新价值）的日期。
      xirrDates.add(historyPoints.last.date); 
      
      if (xirrCashflows.any((cf) => cf > 0) && xirrCashflows.any((cf) => cf < 0)) {
        try {
          annualizedReturn = xirr(xirrDates, xirrCashflows);
        } catch (e) {
          annualizedReturn = 0.0;
        }
      }
    }
    
    return {
      'currentValue': currentValue,       // 已修正
      'netInvestment': netInvestment,     // 已修正
      'totalProfit': totalProfit,         // 已修正
      'profitRate': profitRate,           // 已修正
      'annualizedReturn': annualizedReturn, // 使用原始XIRR逻辑保持不变
    };
  }

  // --- 份额法资产计算 (保持不变) ---
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
      dates.add(DateTime.now().isAfter(lastDate) ? DateTime.now() : lastDate.add(const Duration(days: 1)));
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

  // --- 价值法资产计算 (保持不变，因为您的版本已经是正确的混合逻辑) ---
  List<_ValueHistoryPoint> _processValueTransactions(List<dynamic> transactions) {
    if (transactions.isEmpty) return [];
    transactions.sort((a, b) => a.date.compareTo(b.date));
    final Map<DateTime, _ValueHistoryPoint> dailyPoints = {};
    double runningValue = 0.0;
    _ValueHistoryPoint? lastPoint;
    for (final txn in transactions) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      if (!dailyPoints.containsKey(day)) {
        runningValue = lastPoint?.value ?? 0.0;
        dailyPoints[day] = _ValueHistoryPoint(date: day, value: runningValue, cashFlow: 0);
      }
      if (txn.type == TransactionType.invest) {
        runningValue += txn.amount;
        dailyPoints[day]!.cashFlow -= txn.amount;
      } else if (txn.type == TransactionType.withdraw) {
        runningValue -= txn.amount;
        dailyPoints[day]!.cashFlow += txn.amount;
      } else if (txn.type == TransactionType.updateValue) {
        runningValue = txn.amount;
      }
      dailyPoints[day]!.value = runningValue;
      lastPoint = dailyPoints[day];
    }
    return dailyPoints.values.toList();
  }
  
  Future<Map<String, dynamic>> calculateValueAssetPerformance(Asset asset) async {
    await asset.transactions.load();
    final historyPoints = _processValueTransactions(asset.transactions.toList());
    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }
    double totalInvested = 0;
    double netInvestment = 0;
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

  // --- 账户图表数据生成 (基于纯价值法) ---
  Future<List<FlSpot>> getAccountValueHistory(Account account) async {
    await account.transactions.load();
    final valueUpdates = account.transactions
        .where((txn) => txn.type == TransactionType.updateValue)
        .toList();
    if (valueUpdates.isEmpty) return [];
    final Map<DateTime, AccountTransaction> latestDailyUpdates = {};
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

  // --- 价值法资产图表数据生成 (基于混合逻辑) ---
  Future<List<FlSpot>> getValueAssetHistory(Asset asset) async {
    await asset.transactions.load();
    final historyPoints = _processValueTransactions(asset.transactions.toList());

    if (historyPoints.length < 2) return [];

    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  } 

  // --- 资产配置计算 (基于多币种汇总 - 这是正确的) ---
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
      
      final double rate = await fx.getRate(asset.currency, 'CNY');
      final double assetValueCNY = assetLocalValue * rate;

      allocationCNY.update(asset.subType, (existing) => existing + assetValueCNY, ifAbsent: () => assetValueCNY);
    }
    allocationCNY.removeWhere((key, value) => value <= 0);
    return allocationCNY;
  } 

  // --- 全局业绩计算 (修正：现在只汇总账户价值) ---
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
      // 关键：调用简化的、正确的账户业绩计算
      final performance = await calculateAccountPerformance(account);
      final double rate = await fx.getRate(account.currency, 'CNY');

      final accValue = (performance['currentValue'] ?? 0.0) as double;
      final accNetInv = (performance['netInvestment'] ?? 0.0) as double;

      totalValueCNY += accValue * rate;
      totalNetInvestmentCNY += accNetInv * rate;

      // 全局现金流只应包含顶层账户的现金流
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
  
  // --- 全局图表数据生成 (基于纯账户价值) ---
  Future<List<FlSpot>> getGlobalValueHistory() async {
    final isar = DatabaseService().isar;
    final allTransactions = await isar.collection<AccountTransaction>().where().anyId().findAll();

    if (allTransactions.isEmpty) return [];

    // 1. 确保每个账户在每个公历日只保留时间最晚的一条记录
    final Map<String, AccountTransaction> latestDailyAccountUpdates = {};
    for (final txn in allTransactions) {
      if (txn.type != TransactionType.updateValue) continue; 
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      final accountId = txn.account.value?.id ?? -1;
      if (accountId == -1) continue;
      final key = "${DateFormat('yyyy-MM-dd').format(day)}-$accountId";
      if (!latestDailyAccountUpdates.containsKey(key) || txn.date.isAfter(latestDailyAccountUpdates[key]!.date)) {
        latestDailyAccountUpdates[key] = txn;
      }
    }

    // 2. 按天汇总所有账户的总资产
    final dailyTotalValues = <DateTime, double>{};
    final latestValuesByAccount = <int, double>{};
    
    final allUpdateDays = latestDailyAccountUpdates.values
        .map((txn) => DateTime(txn.date.year, txn.date.month, txn.date.day))
        .toSet().toList()..sort();
    
    if (allUpdateDays.length < 2) return [];
    
    final fx = ExchangeRateService();
    // 预先获取所有相关账户的币种信息
    final allAccountIds = latestDailyAccountUpdates.values.map((txn) => txn.account.value!.id).toSet().toList();
    final accounts = await isar.accounts.getAll(allAccountIds);
    final accountCurrencyMap = {for (var acc in accounts.where((a) => a!= null)) acc!.id: acc.currency};

    for (final day in allUpdateDays) {
      final todaysUpdates = latestDailyAccountUpdates.values.where((txn) {
        final txnDay = DateTime(txn.date.year, txn.date.month, txn.date.day);
        return txnDay.isAtSameMomentAs(day);
      });

      for (final txn in todaysUpdates) {
        latestValuesByAccount[txn.account.value!.id] = txn.amount;
      }
      
      // 汇总时需要换算成CNY
      double totalValueCNYToday = 0;
      for (final entry in latestValuesByAccount.entries) {
        final accountId = entry.key;
        final localValue = entry.value;
        final currency = accountCurrencyMap[accountId] ?? 'CNY';
        final rate = await fx.getRate(currency, 'CNY');
        totalValueCNYToday += localValue * rate;
      }
      dailyTotalValues[day] = totalValueCNYToday;
    }
    
    final sortedEntries = dailyTotalValues.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    return sortedEntries.map((entry) {
      return FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), entry.value);
    }).toList();
  }
}
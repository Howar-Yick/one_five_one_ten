// 文件: lib/services/calculator_service.dart
// (这是已更新价值法图表逻辑的完整文件)

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
import 'dart:math';

// (*** 1. 关键修改：扩展 _ValueHistoryPoint ***)
class _ValueHistoryPoint {
  final DateTime date;
  double value;
  double cashFlow;
  double netInvestment;
  double totalInvested;

  _ValueHistoryPoint({
    required this.date,
    this.value = 0,
    this.cashFlow = 0,
    this.netInvestment = 0,
    this.totalInvested = 0,
  });
}
// (*** 修改结束 ***)

class _AccountHistoryPoint {
  final DateTime date;
  double value;
  double netInvestment;
  double totalInvested; 

  _AccountHistoryPoint({
    required this.date,
    this.value = 0,
    this.netInvestment = 0,
    this.totalInvested = 0,
  });
}


class CalculatorService {
  Isar get _isar => DatabaseService().isar;

  // ( calculateAccountPerformance 保持不变 )
  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    if (account.supabaseId == null) return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    final originalTransactions = await _isar.accountTransactions
        .filter()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .sortByDate()
        .findAll();
    final historyPoints = _buildAccountHistoryPoints(originalTransactions);
    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }
    final double currentValue = historyPoints.last.value;
    final double netInvestment = historyPoints.last.netInvestment;
    final double totalInvested = historyPoints.last.totalInvested;
    final double totalProfit = currentValue - netInvestment;
    final double profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;
    double annualizedReturn = 0.0;
    final xirrCashflows = <double>[];
    final xirrDates = <DateTime>[];
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
      'currentValue': currentValue,      
      'netInvestment': netInvestment,      
      'totalProfit': totalProfit,        
      'profitRate': profitRate,          
      'annualizedReturn': annualizedReturn, 
    };
  }

  // ( _buildAccountHistoryPoints 保持不变 )
  List<_AccountHistoryPoint> _buildAccountHistoryPoints(List<AccountTransaction> transactions) {
    if (transactions.isEmpty) return [];
    transactions.sort((a, b) => a.date.compareTo(b.date));
    final Map<DateTime, _AccountHistoryPoint> dailyPoints = {};
    _AccountHistoryPoint? lastPoint;
    double runningValue = 0.0;
    double runningNetInvestment = 0.0;
    double runningTotalInvested = 0.0; 
    for (final txn in transactions) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      if (!dailyPoints.containsKey(day)) {
        runningValue = lastPoint?.value ?? 0.0;
        runningNetInvestment = lastPoint?.netInvestment ?? 0.0;
        runningTotalInvested = lastPoint?.totalInvested ?? 0.0;
        dailyPoints[day] = _AccountHistoryPoint(
            date: day, 
            value: runningValue, 
            netInvestment: runningNetInvestment,
            totalInvested: runningTotalInvested
        );
      }
      final currentPoint = dailyPoints[day];
      if (currentPoint == null) continue; 
      if (txn.type == TransactionType.invest) {
        runningValue += txn.amount;
        runningNetInvestment += txn.amount;
        runningTotalInvested += txn.amount; 
      } else if (txn.type == TransactionType.withdraw) {
        runningValue -= txn.amount;
        runningNetInvestment -= txn.amount; 
      } else if (txn.type == TransactionType.updateValue) {
        runningValue = txn.amount;
      }
      currentPoint.value = runningValue;
      currentPoint.netInvestment = runningNetInvestment;
      currentPoint.totalInvested = runningTotalInvested;
      lastPoint = currentPoint;
    }
    return dailyPoints.values.toList();
  }

  // ( calculateShareAssetPerformance 保持不变 )
  Future<Map<String, dynamic>> calculateShareAssetPerformance(Asset asset) async {
    if (asset.supabaseId == null) return {'marketValue': 0.0, 'totalCost': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0, 'totalShares': 0.0, 'averageCost': 0.0, 'latestPrice': 0.0};
    final snapshots = await _isar.positionSnapshots
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .sortByDate() 
        .findAll();
    if (snapshots.isEmpty) {
      return {
        'marketValue': 0.0, 'totalCost': 0.0, 'totalProfit': 0.0,
        'profitRate': 0.0, 'annualizedReturn': 0.0,
        'totalShares': 0.0, 'averageCost': 0.0, 'latestPrice': 0.0,
      };
    }
    final latestSnapshot = snapshots.last;

    double totalShares = latestSnapshot.totalShares;
    double averageCost = latestSnapshot.averageCost;
    if (!totalShares.isFinite) {
      totalShares = 0.0;
    }
    if (!averageCost.isFinite) {
      averageCost = 0.0;
    }

    final bool hasPosition = totalShares > 0;

    double totalCost = hasPosition ? totalShares * averageCost : 0.0;
    if (!totalCost.isFinite) {
      totalCost = 0.0;
    }

    double latestPrice = asset.latestPrice;
    if (!latestPrice.isFinite || latestPrice == 0) {
      latestPrice = hasPosition ? averageCost : 0.0;
    }

    double marketValue = totalShares * latestPrice;
    if (!marketValue.isFinite) {
      marketValue = 0.0;
    }

    double totalProfit = marketValue - totalCost;
    if (!totalProfit.isFinite) {
      totalProfit = 0.0;
    }

    double profitRate;
    if (totalCost == 0 || !totalCost.isFinite) {
      profitRate = 0.0;
    } else {
      profitRate = totalProfit / totalCost;
      if (!profitRate.isFinite) {
        profitRate = 0.0;
      }
    }
    double annualizedReturn = 0.0;
    if (snapshots.length >= 1) {
      final dates = <DateTime>[];
      final cashflows = <double>[];
      dates.add(snapshots.first.date);
      final firstCost = snapshots.first.totalShares * snapshots.first.averageCost;
      cashflows.add(firstCost.isFinite ? -firstCost : 0.0);
      for (int i = 1; i < snapshots.length; i++) {
        final prevCost = snapshots[i - 1].totalShares * snapshots[i - 1].averageCost;
        final currentCost = snapshots[i].totalShares * snapshots[i].averageCost;
        if (!prevCost.isFinite || !currentCost.isFinite) {
          continue;
        }
        final costChange = currentCost - prevCost;
        if (costChange.isFinite && costChange.abs() > 0.01) {
          dates.add(snapshots[i].date);
          cashflows.add(-costChange);
        }
      }
      final lastDate = snapshots.last.date;
      dates.add(DateTime.now().isAfter(lastDate) ? DateTime.now() : lastDate.add(const Duration(days: 1)));
      cashflows.add(marketValue.isFinite ? marketValue : 0.0);
      try {
        if (cashflows.any((cf) => cf > 0) && cashflows.any((cf) => cf < 0)) {
          annualizedReturn = xirr(dates, cashflows);
        }
      } catch (e) {
        //
      }
    }
    if (!annualizedReturn.isFinite) {
      annualizedReturn = 0.0;
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

  // ( _processValueTransactions 保持不变 )
  List<_ValueHistoryPoint> _processValueTransactions(List<Transaction> transactions) {
    if (transactions.isEmpty) return [];
    transactions.sort((a, b) => a.date.compareTo(b.date));
    
    final Map<DateTime, _ValueHistoryPoint> dailyPoints = {};
    double runningValue = 0.0;
    double runningNetInvestment = 0.0;
    double runningTotalInvested = 0.0;
    _ValueHistoryPoint? lastPoint;

    for (final txn in transactions) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      if (!dailyPoints.containsKey(day)) {
        runningValue = lastPoint?.value ?? 0.0;
        runningNetInvestment = lastPoint?.netInvestment ?? 0.0;
        runningTotalInvested = lastPoint?.totalInvested ?? 0.0;
        dailyPoints[day] = _ValueHistoryPoint(
          date: day, 
          value: runningValue, 
          cashFlow: 0,
          netInvestment: runningNetInvestment,
          totalInvested: runningTotalInvested
        );
      }
      
      final currentPoint = dailyPoints[day];
      if (currentPoint == null) continue; 

      // (符号逻辑: invest/buy amount 为负, withdraw/sell/dividend amount 为正)
      if (txn.type == TransactionType.invest || txn.type == TransactionType.buy) {
        runningValue += txn.amount.abs();
        runningNetInvestment += txn.amount.abs();
        runningTotalInvested += txn.amount.abs();
        currentPoint.cashFlow += txn.amount; // (cashFlow 记为负数)
      } else if (txn.type == TransactionType.withdraw || txn.type == TransactionType.sell || txn.type == TransactionType.dividend) {
        runningValue -= txn.amount.abs();
        runningNetInvestment -= txn.amount.abs();
        // (总投入不变)
        currentPoint.cashFlow += txn.amount; // (cashFlow 记为正数)
      } else if (txn.type == TransactionType.updateValue) {
        runningValue = txn.amount;
      }
      
      currentPoint.value = runningValue;
      currentPoint.netInvestment = runningNetInvestment;
      currentPoint.totalInvested = runningTotalInvested;
      lastPoint = currentPoint;
    }
    return dailyPoints.values.toList();
  }
  
  // ( calculateValueAssetPerformance 保持不变 )
  Future<Map<String, dynamic>> calculateValueAssetPerformance(Asset asset) async {
    if (asset.supabaseId == null) return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};

    final transactions = await _isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .sortByDate()
        .findAll(); 

    final historyPoints = _processValueTransactions(transactions);
    
    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    // (*** 修改：现在从 historyPoints 直接获取 ***)
    final double currentValue = historyPoints.last.value;
    final double netInvestment = historyPoints.last.netInvestment;
    final double totalInvested = historyPoints.last.totalInvested;
    // (*** 修改结束 ***)

    final double totalProfit = currentValue - netInvestment;
    final double profitRate = totalInvested == 0 ? 0 : totalProfit / totalInvested;
    
    double annualizedReturn = 0.0;
    final cashflows = <double>[];
    final dates = <DateTime>[];

    for (final point in historyPoints) {
      if (point.cashFlow != 0) {
        cashflows.add(point.cashFlow);
        dates.add(point.date);
      }
    }

    if (cashflows.isNotEmpty) {
      cashflows.add(currentValue);
      dates.add(DateTime.now()); // (使用 DateTime.now() 作为终点)
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

  // ( getValueAssetHistoryCharts 保持不变 )
  Future<Map<String, List<FlSpot>>> getValueAssetHistoryCharts(Asset asset) async {
    if (asset.supabaseId == null) {
      return {'totalValue': [], 'totalProfit': [], 'profitRate': []};
    }
    
    // 1. 获取所有相关交易
    final transactions = await _isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .sortByDate()
        .findAll();
        
    // 2. 处理交易，生成历史数据点
    final points = _processValueTransactions(transactions);
    
    // 3. (可选) 添加“今天”的数据点
    final perf = await calculateValueAssetPerformance(asset); // (复用计算)
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    
    final double currentTotalValue = (perf['currentValue'] ?? 0.0) as double;
    final double currentNetInvestment = (perf['netInvestment'] ?? 0.0) as double;
    // (*** 修复：totalInvested 应该从最后一点获取，如果为空则从 perf 获取 ***)
    final double currentTotalInvested = points.isEmpty 
        ? ((perf['netInvestment'] ?? 0.0) as double > 0 ? (perf['netInvestment'] ?? 0.0) as double : 0.0) // (初始总投入等于净投入，但不能为负)
        : points.last.totalInvested;

    if (points.isEmpty || !points.last.date.isAtSameMomentAs(todayDateOnly)) {
      points.add(_ValueHistoryPoint(
        date: todayDateOnly,
        value: currentTotalValue,
        netInvestment: currentNetInvestment,
        totalInvested: currentTotalInvested, 
      ));
    } else {
      // 如果最后一点是今天，用最新数据更新它
      points.last.value = currentTotalValue;
      points.last.netInvestment = currentNetInvestment;
      points.last.totalInvested = currentTotalInvested; // (确保总投入也更新)
    }

    // 4. 将历史数据点映射为三种不同的 FlSpot 列表
    final List<FlSpot> valueSpots = [];
    final List<FlSpot> profitSpots = [];
    final List<FlSpot> profitRateSpots = [];
    
    for (var p in points) {
      final dateEpoch = p.date.millisecondsSinceEpoch.toDouble();
      
      valueSpots.add(FlSpot(dateEpoch, p.value));
      
      final double totalProfit = p.value - p.netInvestment;
      profitSpots.add(FlSpot(dateEpoch, totalProfit));
      
      final double profitRate = (p.totalInvested == 0 || p.totalInvested.isNaN) 
          ? 0.0 
          : totalProfit / p.totalInvested;
      profitRateSpots.add(FlSpot(dateEpoch, profitRate));
    }
    
    // 5. 确保图表至少有两个点
    if (valueSpots.length == 1) {
      final firstDate = DateTime.fromMillisecondsSinceEpoch(valueSpots.first.x.toInt());
      final dayBefore = firstDate.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
      // (*** 修复：第一个点的值应该是 0 ***)
      valueSpots.insert(0, FlSpot(dayBefore, 0.0)); 
      profitSpots.insert(0, FlSpot(dayBefore, 0.0));
      profitRateSpots.insert(0, FlSpot(dayBefore, 0.0));
    }

    return {
      'totalValue': valueSpots,
      'totalProfit': profitSpots,
      'profitRate': profitRateSpots,
    };
  }
  
  // ( getAccountHistoryCharts 保持不变 )
  Future<Map<String, List<FlSpot>>> getAccountHistoryCharts(Account account) async {
    if (account.supabaseId == null) {
        return {'totalValue': [], 'totalProfit': [], 'profitRate': []};
    }
    final transactions = await _isar.accountTransactions
        .filter()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .sortByDate()
        .findAll();
    final points = _buildAccountHistoryPoints(transactions);
    final perf = await calculateAccountPerformance(account);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final double currentTotalValue = (perf['currentValue'] ?? 0.0) as double;
    final double currentNetInvestment = (perf['netInvestment'] ?? 0.0) as double;
    final double currentTotalInvested = (points.isEmpty ? 0.0 : points.last.totalInvested); 
    if (points.isEmpty || !points.last.date.isAtSameMomentAs(todayDateOnly)) {
      points.add(_AccountHistoryPoint(
        date: todayDateOnly,
        value: currentTotalValue,
        netInvestment: currentNetInvestment,
        totalInvested: currentTotalInvested, 
      ));
    } else {
      points.last.value = currentTotalValue;
      points.last.netInvestment = currentNetInvestment;
    }
    final List<FlSpot> valueSpots = [];
    final List<FlSpot> profitSpots = [];
    final List<FlSpot> profitRateSpots = [];
    for (var p in points) {
      final dateEpoch = p.date.millisecondsSinceEpoch.toDouble();
      valueSpots.add(FlSpot(dateEpoch, p.value));
      final double totalProfit = p.value - p.netInvestment;
      profitSpots.add(FlSpot(dateEpoch, totalProfit));
      final double profitRate = (p.totalInvested == 0 || p.totalInvested.isNaN) 
          ? 0.0 
          : totalProfit / p.totalInvested;
      profitRateSpots.add(FlSpot(dateEpoch, profitRate));
    }
    if (valueSpots.length == 1) {
      final firstDate = DateTime.fromMillisecondsSinceEpoch(valueSpots.first.x.toInt());
      final dayBefore = firstDate.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
      valueSpots.insert(0, FlSpot(dayBefore, 0.0));
      profitSpots.insert(0, FlSpot(dayBefore, 0.0));
      profitRateSpots.insert(0, FlSpot(dayBefore, 0.0));
    }
    return {
      'totalValue': valueSpots,
      'totalProfit': profitSpots,
      'profitRate': profitRateSpots,
    };
  }

  // ( calculateAssetAllocation 保持不变, 这是按 SubType 的 )
  Future<Map<AssetSubType, double>> calculateAssetAllocation() async {
    final isar = _isar; 
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

  // --- (*** 1. 新增：calculateAssetClassAllocation 函数 ***) ---
  // (这是 calculateAssetAllocation 的一个副本，但按 AssetClass 分组)
  Future<Map<AssetClass, double>> calculateAssetClassAllocation() async {
    final isar = _isar; 
    final allAssets = await isar.assets.where().anyId().findAll();
    final fx = ExchangeRateService();
    final Map<AssetClass, double> allocationCNY = {}; // <-- 1.1 修改类型
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
      // 1.2 修改分组键
      allocationCNY.update(asset.assetClass, (existing) => existing + assetValueCNY, ifAbsent: () => assetValueCNY); 
    }
    allocationCNY.removeWhere((key, value) => value <= 0);
    return allocationCNY; // <-- 1.3 修改返回
  } 
  // --- (*** 新增结束 ***) ---

  // ( calculateGlobalPerformance 保持不变 )
  Future<Map<String, dynamic>> calculateGlobalPerformance() async {
    final isar = _isar; 
    final allAccounts = await isar.accounts.where().anyId().findAll();
    final fx = ExchangeRateService();
    double totalValueCNY = 0;
    double totalNetInvestmentCNY = 0;
    double totalInvestedCNY = 0;
    final globalCashflows = <double>[];
    final globalDates = <DateTime>[];
    for (final account in allAccounts) {
      final performance = await calculateAccountPerformance(account);
      final double rate = await fx.getRate(account.currency, 'CNY');
      final accValue = (performance['currentValue'] ?? 0.0) as double;
      final accNetInv = (performance['netInvestment'] ?? 0.0) as double;
      totalValueCNY += accValue * rate;
      totalNetInvestmentCNY += accNetInv * rate;
      if (account.supabaseId == null) continue;
      final accTransactions = await isar.accountTransactions
          .filter()
          .accountSupabaseIdEqualTo(account.supabaseId)
          .findAll();
      for (final txn in accTransactions) { 
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
      'netInvestment': totalNetInvestmentCNY,      
      'profitRate': totalProfitRate,          
      'annualizedReturn': globalAnnualizedReturn, 
    };
  }
  
  // ( getGlobalValueHistory 保持不变 )
  Future<List<FlSpot>> getGlobalValueHistory() async {
    final isar = _isar; 
    final allTransactions = await isar.collection<AccountTransaction>().where().filter()
        .typeEqualTo(TransactionType.updateValue) 
        .findAll();
    if (allTransactions.isEmpty) return [];
    final allAccounts = await isar.accounts.where().findAll();
    final Map<String, int> supabaseIdToLocalIdMap = {};
    final Map<int, String> localIdToCurrencyMap = {};
    for (final acc in allAccounts) {
      if (acc.supabaseId != null) {
        supabaseIdToLocalIdMap[acc.supabaseId!] = acc.id;
      }
      localIdToCurrencyMap[acc.id] = acc.currency;
    }
    final Map<String, AccountTransaction> latestDailyAccountUpdates = {};
    for (final txn in allTransactions) {
      if (txn.type != TransactionType.updateValue) continue; 
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      final int? accountId = supabaseIdToLocalIdMap[txn.accountSupabaseId];
      if (accountId == null) continue; 
      final key = "${DateFormat('yyyy-MM-dd').format(day)}-$accountId";
      if (!latestDailyAccountUpdates.containsKey(key) || txn.date.isAfter(latestDailyAccountUpdates[key]!.date)) {
        latestDailyAccountUpdates[key] = txn;
      }
    }
    final dailyTotalValues = <DateTime, double>{};
    final latestValuesByAccount = <int, double>{}; 
    final allUpdateDays = latestDailyAccountUpdates.values
        .map((txn) => DateTime(txn.date.year, txn.date.month, txn.date.day))
        .toSet().toList()..sort();
    if (allUpdateDays.isEmpty) {
        return [];
    }
    final fx = ExchangeRateService();
    for (final day in allUpdateDays) {
      final todaysUpdates = latestDailyAccountUpdates.values.where((txn) {
        final txnDay = DateTime(txn.date.year, txn.date.month, txn.date.day);
        return txnDay.isAtSameMomentAs(day);
      });
      for (final txn in todaysUpdates) {
          final int? accountId = supabaseIdToLocalIdMap[txn.accountSupabaseId];
          if (accountId != null) {
            latestValuesByAccount[accountId] = txn.amount;
          }
      }
      double totalValueCNYToday = 0;
      for (final entry in latestValuesByAccount.entries) {
        final accountId = entry.key; 
        final localValue = entry.value;
        final currency = localIdToCurrencyMap[accountId] ?? 'CNY'; 
        final rate = await fx.getRate(currency, 'CNY');
        totalValueCNYToday += localValue * rate;
      }
      dailyTotalValues[day] = totalValueCNYToday;
    }
    final sortedEntries = dailyTotalValues.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    if (sortedEntries.length < 2) {
      final currentPerf = await calculateGlobalPerformance(); 
      final double currentTotalValue = currentPerf['totalValue'] ?? 0.0;
      if (sortedEntries.isEmpty && currentTotalValue > 0) {
          final today = DateTime.now();
          final todayDateOnly = DateTime(today.year, today.month, today.day);
          sortedEntries.add(MapEntry(todayDateOnly.subtract(const Duration(days: 1)), 0.0));
          sortedEntries.add(MapEntry(todayDateOnly, currentTotalValue));
      } else if (sortedEntries.length == 1 && currentTotalValue > 0) {
          final today = DateTime.now();
          final todayDateOnly = DateTime(today.year, today.month, today.day);
          if (!sortedEntries.first.key.isAtSameMomentAs(todayDateOnly)) {
            sortedEntries.add(MapEntry(todayDateOnly, currentTotalValue));
          } else {
            sortedEntries.insert(0, MapEntry(todayDateOnly.subtract(const Duration(days: 1)), 0.0));
          }
      } else if (sortedEntries.isEmpty && currentTotalValue == 0.0) {
        return [];
      } else if (sortedEntries.length == 1) {
          final dayBefore = sortedEntries.first.key.subtract(const Duration(days: 1));
          sortedEntries.insert(0, MapEntry(dayBefore, 0.0));
      }
    }
    return sortedEntries.map((entry) {
      return FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), entry.value);
    }).toList();
  }

  // ( recalculatePositionSnapshot 保持不变 )
  Future<PositionSnapshot?> recalculatePositionSnapshot(Asset asset, Transaction newTx) async {
    if (newTx.type == TransactionType.dividend) {
      return null;
    }
    final isar = DatabaseService().isar;
    final allSnapshots = await isar.positionSnapshots
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .sortByDate() 
        .findAll();
    PositionSnapshot? lastSnapshot;
    final snapshotsBeforeTx = allSnapshots.where((s) => !s.date.isAfter(newTx.date)).toList();
    if (snapshotsBeforeTx.isNotEmpty) {
      lastSnapshot = snapshotsBeforeTx.last;
    }
    double runningShares = lastSnapshot?.totalShares ?? 0.0;
    double runningCost = lastSnapshot?.averageCost ?? 0.0;
    double runningTotalCost = runningShares * runningCost;
    final otherTransactions = await isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .group((q) => q 
          .typeEqualTo(TransactionType.buy)
          .or()
          .typeEqualTo(TransactionType.sell))
        .and()
        .dateGreaterThan(lastSnapshot?.date ?? DateTime(2000)) 
        .and()
        .dateLessThan(newTx.date) 
        .sortByDate()
        .findAll();
    for (final tx in otherTransactions) {
      if (tx.type == TransactionType.buy && tx.shares != null && tx.amount != 0) {
        runningTotalCost += tx.amount.abs(); 
        runningShares += tx.shares!;      
      } else if (tx.type == TransactionType.sell && tx.shares != null && tx.amount != 0) {
        if (runningShares > 0) {
          runningTotalCost -= tx.shares!.abs() * (runningTotalCost / runningShares); 
        }
        runningShares -= tx.shares!.abs(); 
      }
    }
    if (newTx.type == TransactionType.buy && newTx.shares != null && newTx.amount != 0) {
      runningTotalCost += newTx.amount.abs();
      runningShares += newTx.shares!;
    } else if (newTx.type == TransactionType.sell && newTx.shares != null && newTx.amount != 0) {
      if (runningShares > 0) {
        runningTotalCost -= newTx.shares!.abs() * (runningTotalCost / runningShares);
      }
      runningShares += newTx.shares!; 
    }
    if (runningShares.abs() < 0.0001) {
      runningShares = 0;
      runningCost = 0;
    } else {
      runningCost = runningTotalCost / runningShares;
    }
    final newSnapshot = PositionSnapshot()
      ..date = newTx.date 
      ..totalShares = runningShares
      ..averageCost = runningCost
      ..assetSupabaseId = asset.supabaseId
      ..createdAt = DateTime.now(); 

    return newSnapshot;
  }
}
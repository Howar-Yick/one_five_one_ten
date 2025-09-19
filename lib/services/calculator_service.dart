// 文件: lib/services/calculator_service.dart
// (这是添加了缺失的 recalculatePositionSnapshot 函数并修复了所有查询和格式的完整代码)

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
  
  Isar get _isar => DatabaseService().isar;


  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    
    if (account.supabaseId == null) return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};

    final originalTransactions = await _isar.accountTransactions
        .filter()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .sortByDate() 
        .findAll();

    final historyPoints = _processValueTransactions(originalTransactions);

    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    double totalInvested = 0;
    double netInvestment = 0;
    
    for (final point in historyPoints) {
      if (point.cashFlow < 0) {
           totalInvested += -point.cashFlow;
      }
      netInvestment += -point.cashFlow; 
    }

    final double currentValue = historyPoints.last.value;
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
    
    if (asset.supabaseId == null) return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};

    final transactions = await _isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .findAll(); 

    final historyPoints = _processValueTransactions(transactions);
    
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

  Future<List<FlSpot>> getAccountValueHistory(Account account) async {
    
    if (account.supabaseId == null) return [];
    
    final valueUpdates = await _isar.accountTransactions
        .filter()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .and()
        .typeEqualTo(TransactionType.updateValue) 
        .findAll();

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

  Future<List<FlSpot>> getValueAssetHistory(Asset asset) async {
    
    if (asset.supabaseId == null) return [];
    final transactions = await _isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .findAll();
    
    final historyPoints = _processValueTransactions(transactions);

    if (historyPoints.length < 2) return [];

    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  } 

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

  // --- (*** 1. 新增：这是缺失的函数 ***) ---
  Future<PositionSnapshot?> recalculatePositionSnapshot(Asset asset, Transaction newTx) async {
    
    // 分红是一种现金流，但它不改变持仓快照（份额或成本）
    if (newTx.type == TransactionType.dividend) {
      return null;
    }

    final isar = DatabaseService().isar;

    // 1. 查找此资产所有已存在的快照
    final allSnapshots = await isar.positionSnapshots
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .sortByDate() // 按日期升序
        .findAll();

    // 2. 查找早于或等于此交易日期的【最新】快照
    PositionSnapshot? lastSnapshot;
    // (修复：确保 where 条件正确比较日期)
    final snapshotsBeforeTx = allSnapshots.where((s) => !s.date.isAfter(newTx.date)).toList();
    if (snapshotsBeforeTx.isNotEmpty) {
      lastSnapshot = snapshotsBeforeTx.last;
    }

    // 3. 将其克隆为我们的“运行基准”
    double runningShares = lastSnapshot?.totalShares ?? 0.0;
    double runningCost = lastSnapshot?.averageCost ?? 0.0;
    double runningTotalCost = runningShares * runningCost;

    // 4. (*** 关键修复：修正查询语法 ***)
    // 获取在此“基准快照”之后、但在“新交易”之前发生的所有其他交易
    final otherTransactions = await isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        // (旧的错误查询: .typeNotEqualTo(TransactionType.dividend) )
        .group((q) => q // (新的正确查询: 只关心买和卖)
          .typeEqualTo(TransactionType.buy)
          .or()
          .typeEqualTo(TransactionType.sell))
        .and()
        .dateGreaterThan(lastSnapshot?.date ?? DateTime(2000)) 
        .and()
        .dateLessThan(newTx.date) // 严格在新交易之前
        .sortByDate()
        .findAll();
        
    // 5. 将所有这些“中间”交易应用到我们的运行基准上
    for (final tx in otherTransactions) {
      if (tx.type == TransactionType.buy && tx.shares != null && tx.amount != 0) {
        runningTotalCost += tx.amount.abs(); // 买入，总成本增加 (买入 amount 存的是负现金流)
        runningShares += tx.shares!;       // 份额增加
      } else if (tx.type == TransactionType.sell && tx.shares != null && tx.amount != 0) {
        if (runningShares > 0) {
          // 卖出时，我们按平均成本法减少总成本
          runningTotalCost -= tx.shares!.abs() * (runningTotalCost / runningShares); 
        }
        runningShares -= tx.shares!.abs(); // 份额减少 (卖出 shares 存的是负数)
      }
    }
    
    // 6. 现在，应用我们的【新交易】
    // (注意: newTx.amount 买入为负，卖出为正。 tx.shares 买入为正，卖出为负)
    if (newTx.type == TransactionType.buy && newTx.shares != null && newTx.amount != 0) {
      runningTotalCost += newTx.amount.abs(); // 增加成本
      runningShares += newTx.shares!; // 增加份额
    } else if (newTx.type == TransactionType.sell && newTx.shares != null && newTx.amount != 0) {
      if (runningShares > 0) {
         // 按比例减少成本
        runningTotalCost -= newTx.shares!.abs() * (runningTotalCost / runningShares);
      }
      runningShares += newTx.shares!; // 加上一个负数，即减少份额
    }

    // 7. 计算最终的新平均成本
    if (runningShares.abs() < 0.0001) {
      runningShares = 0;
      runningCost = 0;
    } else {
      runningCost = runningTotalCost / runningShares;
    }
    
    // 8. 创建并返回一个新的快照对象
    final newSnapshot = PositionSnapshot()
      ..date = newTx.date // 关键：使用交易日期作为快照日期
      ..totalShares = runningShares
      ..averageCost = runningCost
      ..assetSupabaseId = asset.supabaseId
      ..createdAt = DateTime.now(); 

    return newSnapshot;
  }
  // --- (*** 新增函数结束 ***) ---
}
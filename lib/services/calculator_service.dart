// 文件: lib/services/calculator_service.dart
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
  
  // (*** 新增：获取 Isar 实例的辅助函数 ***)
  Isar get _isar => DatabaseService().isar;


  // --- 修正：还原为纯粹的价值法计算（有知有行模式），不关心子资产 ---
  Future<Map<String, dynamic>> calculateAccountPerformance(Account account) async {
    
    // 1. (*** 关键修复：替换 IsarLink 查询 ***)
    // 旧代码: await account.transactions.load();
    //         final originalTransactions = account.transactions.toList()...
    
    // 新代码：我们必须手动查询所有链接到此账户 SupabaseId 的 AccountTransactions
    if (account.supabaseId == null) return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};

    final originalTransactions = await _isar.accountTransactions
        .filter()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .sortByDate() // 按日期升序排序
        .findAll();

    // (*** 修复结束 ***)

    // 使用与 "价值法资产" 相同的运行总值计算逻辑
    final historyPoints = _processValueTransactions(originalTransactions);

    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    double totalInvested = 0;
    double netInvestment = 0;
    
    // (*** 注意：您的其余计算逻辑（遍历 historyPoints 和 originalTransactions）是正确的，保持不变 ***)

    // 遍历按天聚合后的历史点
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
    
    for (var txn in originalTransactions) { // (此列表已在上面通过新查询正确获取)
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

  // --- 份额法资产计算 ---
  Future<Map<String, dynamic>> calculateShareAssetPerformance(Asset asset) async {
    
    // 2. (*** 关键修复：替换 IsarLink 查询 ***)
    // 旧代码: await asset.snapshots.load();
    //         final snapshots = asset.snapshots.toList()...

    // 新代码：我们必须手动查询所有链接到此资产 SupabaseId 的 Snapshots
    if (asset.supabaseId == null) return {'marketValue': 0.0, 'totalCost': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0, 'totalShares': 0.0, 'averageCost': 0.0, 'latestPrice': 0.0};
    
    final snapshots = await _isar.positionSnapshots
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .sortByDate() // 按日期升序排序
        .findAll();
    
    // (*** 修复结束 ***)


    if (snapshots.isEmpty) {
      return {
        'marketValue': 0.0, 'totalCost': 0.0, 'totalProfit': 0.0,
        'profitRate': 0.0, 'annualizedReturn': 0.0,
        'totalShares': 0.0, 'averageCost': 0.0, 'latestPrice': 0.0,
      };
    }
    
    // (*** 您的其余计算逻辑是正确的，保持不变 ***)

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

  // --- 价值法资产计算 (辅助函数) ---
  // (*** 修正：将 (List<dynamic> transactions) 改为强类型 (List<Transaction> transactions) ***)
  // (注意：这个函数也接收 AccountTransaction 列表，所以我们需要保持 dynamic，或者使用一个通用接口，但 dynamic 已在您代码中，保持不变)
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
  
  // --- 价值法资产计算 (主函数) ---
  Future<Map<String, dynamic>> calculateValueAssetPerformance(Asset asset) async {
    
    // 3. (*** 关键修复：替换 IsarLink 查询 ***)
    // 旧代码: await asset.transactions.load();
    //         final historyPoints = _processValueTransactions(asset.transactions.toList());

    // 新代码：我们必须手动查询所有链接到此资产 SupabaseId 的 Transactions
    if (asset.supabaseId == null) return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};

    final transactions = await _isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .findAll(); // _processValueTransactions 会自动排序

    final historyPoints = _processValueTransactions(transactions);
    
    // (*** 修复结束 ***)

    if (historyPoints.isEmpty) {
      return {'currentValue': 0.0, 'netInvestment': 0.0, 'totalProfit': 0.0, 'profitRate': 0.0, 'annualizedReturn': 0.0};
    }

    // (*** 您的其余计算逻辑是正确的，保持不变 ***)
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
    
    // 4. (*** 关键修复：替换 IsarLink 查询 ***)
    // 旧代码: await account.transactions.load();
    //         final valueUpdates = account.transactions.where(...)
    
    // 新代码：
    if (account.supabaseId == null) return [];
    
    final valueUpdates = await _isar.accountTransactions
        .filter()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .and()
        .typeEqualTo(TransactionType.updateValue) // 确保只获取 updateValue 类型
        .findAll();

    // (*** 修复结束 ***)

    if (valueUpdates.isEmpty) return [];
    
    // (*** 您的其余计算逻辑是正确的，保持不变 ***)
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
    
    // 5. (*** 关键修复：替换 IsarLink 查询 ***)
    // 旧代码: await asset.transactions.load();
    
    // 新代码：
    if (asset.supabaseId == null) return [];
    final transactions = await _isar.transactions
        .filter()
        .assetSupabaseIdEqualTo(asset.supabaseId)
        .findAll();

    // (*** 修复结束 ***)
    
    final historyPoints = _processValueTransactions(transactions);

    if (historyPoints.length < 2) return [];

    return historyPoints.map((point) {
      return FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value);
    }).toList();
  } 

  // --- 资产配置计算 (保持不变) ---
  // (这个函数已经依赖于 calculateShareAssetPerformance 和 calculateValueAssetPerformance，
  // 既然我们已经修复了那两个函数，这个函数现在就可以正确工作了)
  Future<Map<AssetSubType, double>> calculateAssetAllocation() async {
    final isar = _isar; // (使用辅助 getter)
    final allAssets = await isar.assets.where().anyId().findAll();
    final fx = ExchangeRateService();

    final Map<AssetSubType, double> allocationCNY = {};

    for (final asset in allAssets) {
      Map<String, dynamic> performance;
      double assetLocalValue = 0.0;

      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        performance = await calculateShareAssetPerformance(asset); // (现在调用的是已修复的版本)
        assetLocalValue = (performance['marketValue'] ?? 0.0) as double;
      } else { 
        performance = await calculateValueAssetPerformance(asset); // (现在调用的是已修复的版本)
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
    final isar = _isar; // (使用辅助 getter)
    final allAccounts = await isar.accounts.where().anyId().findAll();
    final fx = ExchangeRateService();

    double totalValueCNY = 0;
    double totalNetInvestmentCNY = 0;
    double totalInvestedCNY = 0;
    
    final globalCashflows = <double>[];
    final globalDates = <DateTime>[];

    for (final account in allAccounts) {
      // (这个函数现在调用的是已修复的版本)
      final performance = await calculateAccountPerformance(account);
      final double rate = await fx.getRate(account.currency, 'CNY');

      final accValue = (performance['currentValue'] ?? 0.0) as double;
      final accNetInv = (performance['netInvestment'] ?? 0.0) as double;

      totalValueCNY += accValue * rate;
      totalNetInvestmentCNY += accNetInv * rate;

      // 6. (*** 关键修复：替换 IsarLink 查询 ***)
      // 旧代码: await account.transactions.load(); 
      //         for (final txn in account.transactions) { ... }
      
      // 新代码：
      if (account.supabaseId == null) continue;
      final accTransactions = await isar.accountTransactions
          .filter()
          .accountSupabaseIdEqualTo(account.supabaseId)
          .findAll();

      for (final txn in accTransactions) { // (现在遍历的是我们手动查询的列表)
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
    final isar = _isar; // (使用辅助 getter)
    final allTransactions = await isar.collection<AccountTransaction>().where().filter()
        .typeEqualTo(TransactionType.updateValue) // 7. (优化) 只拉取我们需要的数据
        .findAll();

    if (allTransactions.isEmpty) return [];
    
    // 8. (*** 关键修复：替换所有 IsarLink 逻辑 ***)
    
    // 8.1 (新) 获取所有账户并创建两个查找表：
    //     一个用于 (SupabaseId -> 本地 Isar ID)
    //     一个用于 (本地 Isar ID -> Currency)
    final allAccounts = await isar.accounts.where().findAll();
    final Map<String, int> supabaseIdToLocalIdMap = {};
    final Map<int, String> localIdToCurrencyMap = {};
    for (final acc in allAccounts) {
      if (acc.supabaseId != null) {
        supabaseIdToLocalIdMap[acc.supabaseId!] = acc.id;
      }
      localIdToCurrencyMap[acc.id] = acc.currency;
    }


    // 8.2 确保每个账户在每个公历日只保留时间最晚的一条记录
    final Map<String, AccountTransaction> latestDailyAccountUpdates = {};
    for (final txn in allTransactions) {
      // (我们已经在上面的查询中过滤了 type，但双重检查无害)
      if (txn.type != TransactionType.updateValue) continue; 
      
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      
      // 8.3 (新逻辑) 使用 Map 查找本地 ID
      final int? accountId = supabaseIdToLocalIdMap[txn.accountSupabaseId];
      
      if (accountId == null) continue; // 交易属于一个未知的/已删除的账户
      
      final key = "${DateFormat('yyyy-MM-dd').format(day)}-$accountId";
      if (!latestDailyAccountUpdates.containsKey(key) || txn.date.isAfter(latestDailyAccountUpdates[key]!.date)) {
        latestDailyAccountUpdates[key] = txn;
      }
    }

    // 8.4 按天汇总所有账户的总资产
    final dailyTotalValues = <DateTime, double>{};
    final latestValuesByAccount = <int, double>{}; // (这个 Map 的 key 是本地 Isar ID (int)，这是正确的)
    
    final allUpdateDays = latestDailyAccountUpdates.values
        .map((txn) => DateTime(txn.date.year, txn.date.month, txn.date.day))
        .toSet().toList()..sort();
    
    if (allUpdateDays.length < 2) return [];
    
    final fx = ExchangeRateService();
    // (不再需要下面的代码，因为我们已经有了 localIdToCurrencyMap)
    // final allAccountIds = ...
    // final accounts = ...
    // final accountCurrencyMap = ...

    for (final day in allUpdateDays) {
      final todaysUpdates = latestDailyAccountUpdates.values.where((txn) {
        final txnDay = DateTime(txn.date.year, txn.date.month, txn.date.day);
        return txnDay.isAtSameMomentAs(day);
      });

      for (final txn in todaysUpdates) {
        // 8.5 (新逻辑) 再次查找本地 ID
         final int? accountId = supabaseIdToLocalIdMap[txn.accountSupabaseId];
         if (accountId != null) {
            latestValuesByAccount[accountId] = txn.amount;
         }
      }
      
      // 汇总时需要换算成CNY
      double totalValueCNYToday = 0;
      for (final entry in latestValuesByAccount.entries) {
        final accountId = entry.key; // 这是本地 Isar ID (int)
        final localValue = entry.value;
        final currency = localIdToCurrencyMap[accountId] ?? 'CNY'; // 使用我们的新 Map
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
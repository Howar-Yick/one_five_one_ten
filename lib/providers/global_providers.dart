// 文件: lib/providers/global_providers.dart
// (这是已修复“份额法图表起始日期”逻辑的完整文件)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';
import 'dart:math'; // (导入 Math)

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/price_sync_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart'; 
import 'package:one_five_one_ten/models/account_transaction.dart';
// import 'package:one_five_one_ten/models/transaction.dart'; // (不需要了)


/// 说明：
/// 集中放置需要被多个页面跨页使用的顶层 Provider，避免页面之间互相 import 导致的循环依赖。


// ------------------------ 核心服务 Providers ------------------------
// ( ... 此区域代码保持不变 ...)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final syncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService();
});

// ------------------------ 账户列表 ------------------------
// ( ... 此区域代码保持不变 ...)
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.accounts.where().sortByName().watch(fireImmediately: true);
});

// ------------------------ 首页总览 ------------------------
// ( ... 此区域代码保持不变 ...)
final dashboardDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final calc = CalculatorService();
  final globalPerf = await calc.calculateGlobalPerformance();
  final List<FlSpot> historySpots = await calc.getGlobalValueHistory();
  final Map<AssetSubType, double> allocation =
      await calc.calculateAssetAllocation();
  return {
    ...globalPerf, 
    'historySpots': historySpots,
    'allocation': allocation,
  };
});

// ------------------------ 价格同步 ------------------------
// ( ... 此区域代码保持不变 ...)
final priceSyncServiceProvider = Provider<PriceSyncService>((ref) {
  return PriceSyncService();
});
enum PriceSyncState { idle, loading, success, error }
class PriceSyncController extends StateNotifier<PriceSyncState> {
  final Ref _ref;
  PriceSyncController(this._ref) : super(PriceSyncState.idle);
  Future<void> syncAllPrices() async {
    if (state == PriceSyncState.loading) return;
    state = PriceSyncState.loading;
    try {
      final isar = _ref.read(databaseServiceProvider).isar;
      final priceService = _ref.read(priceSyncServiceProvider);
      final syncService = _ref.read(syncServiceProvider);
      final allAssets = await isar.assets.where().findAll();
      final assetsToSync = allAssets
          .where((a) =>
              (a.subType == AssetSubType.stock ||
                  a.subType == AssetSubType.etf ||
                  a.subType == AssetSubType.mutualFund) &&
              a.code.isNotEmpty)
          .toList();
      if (assetsToSync.isEmpty) {
        print('[PriceSyncController] 没有需要同步价格的资产。');
        state = PriceSyncState.success;
        return;
      }
      print(
          '[PriceSyncController] 开始为 ${assetsToSync.length} 个资产同步价格...');
      int successCount = 0;
      int failCount = 0;
      final futures = assetsToSync.map((asset) async {
        try {
          final newPrice = await priceService.syncPrice(asset);
          if (newPrice != null && newPrice != asset.latestPrice) {
            asset.latestPrice = newPrice;
            asset.priceUpdateDate = DateTime.now();
            await syncService.saveAsset(asset);
            print('[PriceSyncController] 同步成功 ${asset.name}: $newPrice');
            return true; 
          } else if (newPrice == null) {
            print('[PriceSyncController] 未能获取价格 ${asset.name}');
            return false; 
          }
          return null; 
        } catch (e) {
          print('[PriceSyncController] 同步 ${asset.name} 时出错: $e');
          return false; 
        }
      }).toList();
      final results = await Future.wait(futures);
      successCount = results.where((r) => r == true).length;
      failCount = results.where((r) => r == false).length;
      print(
          '[PriceSyncController] 同步完成。 成功: $successCount, 失败: $failCount');
      _ref.invalidate(dashboardDataProvider);
      state = PriceSyncState.success;
    } catch (e) {
      print('[PriceSyncController] syncAllPrices 遭遇致命错误: $e');
      state = PriceSyncState.error;
    }
  }
}
final priceSyncControllerProvider =
    StateNotifierProvider<PriceSyncController, PriceSyncState>((ref) {
  return PriceSyncController(ref);
});

// ------------------------ 账户详情页 Providers ------------------------
// ( ... 此区域代码保持不变 ...)
final accountDetailProvider =
    FutureProvider.autoDispose.family<Account?, int>((ref, accountId) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.accounts.get(accountId);
});
final accountPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, accountId) async {
  final account = await ref.watch(accountDetailProvider(accountId).future);
  if (account == null) {
    throw '未找到账户';
  }
  return CalculatorService().calculateAccountPerformance(account);
});
final trackedAssetsWithPerformanceProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, accountId) async* { 
  final isar = ref.watch(databaseServiceProvider).isar;
  final calculator = CalculatorService();
  final account = await ref.watch(accountDetailProvider(accountId).future);
  if (account == null || account.supabaseId == null) {
    yield []; 
    return;
  }
  final accountSupabaseId = account.supabaseId!;
  final assetStream = isar.assets
      .where()
      .filter()
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .watch(fireImmediately: true);
  await for (var assets in assetStream) {
    final List<Map<String, dynamic>> results = [];
    for (final asset in assets) {
      Map<String, dynamic> performanceData;
      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        performanceData = await calculator.calculateShareAssetPerformance(asset);
      } else {
        performanceData = await calculator.calculateValueAssetPerformance(asset);
      }
      results.add({
        'asset': asset,
        'performance': performanceData,
      });
    }
    yield results; 
  }
});
final accountHistoryProvider = 
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, Account>(
        (ref, account) {
  ref.watch(accountPerformanceProvider(account.id));
  return CalculatorService().getAccountHistoryCharts(account);
});

// ------------------------ 交易历史页 Providers ------------------------
// ( ... 此区域代码保持不变 ...)
final transactionHistoryProvider =
    StreamProvider.autoDispose.family<List<AccountTransaction>, int>((ref, accountId) async* { 
  final isar = ref.watch(databaseServiceProvider).isar;
  final account = await isar.accounts.get(accountId);
  if (account == null || account.supabaseId == null) {
    yield [];
    return;
  }
  final accountSupabaseId = account.supabaseId!;
  final transactionStream = isar.accountTransactions
      .filter()
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .sortByDateDesc() 
      .watch(fireImmediately: true);
  yield* transactionStream; 
});

// ------------------------ 份额法资产详情页 Providers ------------------------

// (枚举定义保持不变)
enum ShareAssetChartType {
  price,
  totalProfit,
  profitRate,
}

// (shareAssetDetailProvider, shareAssetPerformanceProvider, assetHistoryChartProvider, snapshotHistoryProvider 保持不变)
final shareAssetDetailProvider =
    StreamProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.assets.watchObject(assetId, fireImmediately: true);
});

final shareAssetPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, assetId) async {
  final asset = await ref.watch(shareAssetDetailProvider(assetId).future);
  if (asset == null) {
    throw Exception('未找到资产');
  }
  return CalculatorService().calculateShareAssetPerformance(asset);
});

final assetHistoryChartProvider =
    FutureProvider.autoDispose.family<List<FlSpot>, int>((ref, assetId) async {
  final asset = await ref.watch(shareAssetDetailProvider(assetId).future);
  if (asset == null || asset.code.isEmpty) return [];

  final priceService = ref.read(priceSyncServiceProvider); 
  if (asset.subType == AssetSubType.mutualFund) {
    return priceService.syncNavHistory(asset.code);
  } else if (asset.subType == AssetSubType.stock || asset.subType == AssetSubType.etf) {
    return priceService.syncKLineHistory(asset.code);
  }
  return [];
});

final snapshotHistoryProvider = StreamProvider.autoDispose.family<List<PositionSnapshot>, int>((ref, assetId) async* { 
  final isar = ref.watch(databaseServiceProvider).isar;
  
  final asset = await ref.watch(shareAssetDetailProvider(assetId).future);
  if (asset == null || asset.supabaseId == null) {
    yield [];
    return;
  }
  
  final assetSupabaseId = asset.supabaseId!;

  final snapshotStream = isar.positionSnapshots
      .filter()
      .assetSupabaseIdEqualTo(assetSupabaseId)
      .sortByDateDesc() 
      .watch(fireImmediately: true);

  yield* snapshotStream; 
});


// (*** 关键修改：shareAssetCombinedChartProvider ***)
final shareAssetCombinedChartProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
        (ref, assetId) async {
  
  // 1. 并发获取两个数据源
  final priceHistoryFuture = ref.watch(assetHistoryChartProvider(assetId).future);
  final snapshotHistoryFuture = ref.watch(snapshotHistoryProvider(assetId).future);

  final priceHistory = await priceHistoryFuture;
  final snapshots = await snapshotHistoryFuture;
  
  // (*** 2. 关键修复：处理空快照的情况 ***)
  if (snapshots.isEmpty || priceHistory.isEmpty) {
    // 如果没有快照，我们无法计算收益，但仍然可以显示价格历史
    return {'price': priceHistory, 'totalProfit': [], 'profitRate': []};
  }

  // 3. 将快照列表（当前是降序）反转为升序
  final sortedSnapshots = snapshots.reversed.toList();
  
  // (*** 4. 关键修复：获取第一个快照的日期，并以此过滤价格历史 ***)
  final firstSnapshotDate = sortedSnapshots.first.date;
  final firstSnapshotEpoch = DateTime(firstSnapshotDate.year, firstSnapshotDate.month, firstSnapshotDate.day)
      .millisecondsSinceEpoch.toDouble();

  // (*** 只处理第一个快照日期之后的价格 ***)
  final relevantPriceHistory = priceHistory.where((spot) => spot.x >= firstSnapshotEpoch).toList();

  if (relevantPriceHistory.isEmpty) {
    // 如果价格历史都在快照之前（不太可能，但作为保险）
    return {'price': [], 'totalProfit': [], 'profitRate': []};
  }
  // (*** 修复结束 ***)


  final List<FlSpot> profitSpots = [];
  final List<FlSpot> profitRateSpots = [];

  PositionSnapshot? activeSnapshot;
  int snapshotIndex = 0;

  // 5. 遍历【相关】的价格历史
  for (final priceSpot in relevantPriceHistory) { // (*** 修改：使用 relevantPriceHistory ***)
    final currentDate = DateTime.fromMillisecondsSinceEpoch(priceSpot.x.toInt());
    
    while (snapshotIndex < sortedSnapshots.length && 
           !sortedSnapshots[snapshotIndex].date.isAfter(currentDate)) {
      activeSnapshot = sortedSnapshots[snapshotIndex];
      snapshotIndex++;
    }

    // (*** 6. 关键修复：既然我们已经过滤了价格，activeSnapshot 理论上不应为 null ***)
    if (activeSnapshot == null) {
      // (如果真的发生了，跳过这个点)
      continue;
    } 
    
    final double price = priceSpot.y;
    final double totalShares = activeSnapshot.totalShares;
    final double averageCost = activeSnapshot.averageCost;
    
    if (totalShares == 0) {
       profitSpots.add(FlSpot(priceSpot.x, 0.0));
       profitRateSpots.add(FlSpot(priceSpot.x, 0.0));
       continue;
    }

    final double totalCost = totalShares * averageCost;
    final double marketValue = totalShares * price;
    
    final double totalProfit = marketValue - totalCost;
    final double profitRate = (totalCost == 0 || totalCost.isNaN) ? 0.0 : totalProfit / totalCost;
    
    profitSpots.add(FlSpot(priceSpot.x, totalProfit));
    profitRateSpots.add(FlSpot(priceSpot.x, profitRate));
  }
  
  // 8. 确保图表至少有两个点（如果它们只有一个点）
  if (profitSpots.length == 1) {
     final firstDate = DateTime.fromMillisecondsSinceEpoch(profitSpots.first.x.toInt());
     final dayBefore = firstDate.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
     profitSpots.insert(0, FlSpot(dayBefore, 0.0));
     profitRateSpots.insert(0, FlSpot(dayBefore, 0.0));
  }
  // (*** 同样处理价格图表 ***)
  if (relevantPriceHistory.length == 1) {
     final firstDate = DateTime.fromMillisecondsSinceEpoch(relevantPriceHistory.first.x.toInt());
     final dayBefore = firstDate.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
     relevantPriceHistory.insert(0, FlSpot(dayBefore, relevantPriceHistory.first.y)); // (使用第一个点的价格作为前一天的价格)
  }

  return {
    'price': relevantPriceHistory, // (*** 修改：返回过滤后的价格列表 ***)
    'totalProfit': profitSpots,
    'profitRate': profitRateSpots,
  };
});
// (*** 修改结束 ***)
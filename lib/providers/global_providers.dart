// 文件: lib/providers/global_providers.dart
// (这是已添加价值法 Providers 并修复了所有依赖的完整文件)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/price_sync_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart'; 
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/transaction.dart'; // (*** 1. 新增导入 ***)


/// 说明：
/// 集中放置需要被多个页面跨页使用的顶层 Provider，避免页面之间互相 import 导致的循环依赖。

// (*** 2. 新增：全局枚举 ***)
// (从 account_detail_page 移入)
enum AssetSortCriteria {
  marketValue,
  totalProfit,
  profitRate,
  annualizedReturn,
}

// (从 account_detail_page 移入，现在对所有页面可用)
enum AccountChartType {
  totalValue,
  totalProfit,
  profitRate,
}

// (从 share_asset_detail_page 移入)
enum ShareAssetChartType {
  price,
  totalProfit,
  profitRate,
}
// (*** 新增结束 ***)


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
    // ... (此函数保持不变)
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
// ( ... 此区域代码保持不变 ...)
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
final shareAssetCombinedChartProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
        (ref, assetId) async {
  final priceHistoryFuture = ref.watch(assetHistoryChartProvider(assetId).future);
  final snapshotHistoryFuture = ref.watch(snapshotHistoryProvider(assetId).future);
  final priceHistory = await priceHistoryFuture;
  final snapshots = await snapshotHistoryFuture;
  if (snapshots.isEmpty || priceHistory.isEmpty) {
    return {'price': priceHistory, 'totalProfit': [], 'profitRate': []};
  }
  final sortedSnapshots = snapshots.reversed.toList();
  final firstSnapshotDate = sortedSnapshots.first.date;
  final firstSnapshotEpoch = DateTime(firstSnapshotDate.year, firstSnapshotDate.month, firstSnapshotDate.day)
      .millisecondsSinceEpoch.toDouble();
  final relevantPriceHistory = priceHistory.where((spot) => spot.x >= firstSnapshotEpoch).toList();
  if (relevantPriceHistory.isEmpty) {
    return {'price': [], 'totalProfit': [], 'profitRate': []};
  }
  final List<FlSpot> profitSpots = [];
  final List<FlSpot> profitRateSpots = [];
  PositionSnapshot? activeSnapshot;
  int snapshotIndex = 0;
  for (final priceSpot in relevantPriceHistory) { 
    final currentDateEpoch = priceSpot.x;
    final currentDate = DateTime.fromMillisecondsSinceEpoch(currentDateEpoch.toInt()); 
    while (snapshotIndex < sortedSnapshots.length) {
      final snapshotDate = sortedSnapshots[snapshotIndex].date;
      final snapshotDateOnly = DateTime(snapshotDate.year, snapshotDate.month, snapshotDate.day);
      if (!snapshotDateOnly.isAfter(currentDate)) { 
        activeSnapshot = sortedSnapshots[snapshotIndex];
        snapshotIndex++;
      } else {
        break;
      }
    }
    if (activeSnapshot == null) {
      profitSpots.add(FlSpot(priceSpot.x, 0.0));
      profitRateSpots.add(FlSpot(priceSpot.x, 0.0));
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
  void ensureTwoSpots(List<FlSpot> spots, [double defaultY = 0.0]) {
    if (spots.length == 1) {
       final firstDate = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
       final dayBefore = firstDate.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
       spots.insert(0, FlSpot(dayBefore, defaultY));
    }
  }
  ensureTwoSpots(profitSpots);
  ensureTwoSpots(profitRateSpots);
  ensureTwoSpots(relevantPriceHistory, relevantPriceHistory.isNotEmpty ? relevantPriceHistory.first.y : 0.0);
  return {
    'price': relevantPriceHistory, 
    'totalProfit': profitSpots,
    'profitRate': profitRateSpots,
  };
});

// --- (*** 4. 新增：价值法资产的 Provider ***) ---

// (从 value_asset_detail_page 移入)
final valueAssetDetailProvider =
    StreamProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.assets.watchObject(assetId, fireImmediately: true);
});

// (从 value_asset_detail_page 移入)
final valueAssetPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, assetId) async {
  // (*** 关键：依赖 DetailProvider 来自动刷新 ***)
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) {
    throw Exception('未找到资产');
  }
  return CalculatorService().calculateValueAssetPerformance(asset);
});

// (*** 新增：价值法的三种图表 Provider ***)
final valueAssetHistoryChartsProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
        (ref, assetId) async {
  // (*** 关键：依赖 PerformanceProvider 来触发刷新 ***)
  ref.watch(valueAssetPerformanceProvider(assetId)); 
  
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) {
    return {'totalValue': [], 'totalProfit': [], 'profitRate': []};
  }
  // (调用我们刚在 CalculatorService 中创建的新函数)
  return CalculatorService().getValueAssetHistoryCharts(asset);
});
// --- (*** 新增结束 ***) ---
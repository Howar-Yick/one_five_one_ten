// 文件: lib/providers/global_providers.dart
// (这是完整的、基于你原有代码的修复版本)

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
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// 说明：
/// 集中放置需要被多个页面跨页使用的顶层 Provider，避免页面之间互相 import 导致的循环依赖。

// ... (你文件中所有其他的 Provider 和 enum 定义保持不变) ...
enum AssetSortCriteria {
  marketValue,
  totalProfit,
  profitRate,
  annualizedReturn,
}

enum AccountChartType {
  totalValue,
  totalProfit,
  profitRate,
}

enum ShareAssetChartType {
  price,
  totalProfit,
  profitRate,
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
final syncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService();
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.accounts.where().sortByName().watch(fireImmediately: true);
});

final dashboardDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final calc = CalculatorService();
  final globalPerf = await calc.calculateGlobalPerformance();
  final List<FlSpot> historySpots = await calc.getGlobalValueHistory();
  
  final Map<AssetSubType, double> subTypeAllocation =
      await calc.calculateAssetAllocation();
  final Map<AssetClass, double> classAllocation =
      await calc.calculateAssetClassAllocation();
      
  return {
    ...globalPerf, 
    'historySpots': historySpots,
    'allocationSubType': subTypeAllocation,
    'allocationClass': classAllocation,
  };
});

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
    double totalShares = activeSnapshot.totalShares;
    double averageCost = activeSnapshot.averageCost;
    if (!totalShares.isFinite || totalShares <= 0) {
      profitSpots.add(FlSpot(priceSpot.x, 0.0));
      profitRateSpots.add(FlSpot(priceSpot.x, 0.0));
      continue;
    }
    if (!averageCost.isFinite) {
      averageCost = 0.0;
    }
    double totalCost = totalShares * averageCost;
    if (!totalCost.isFinite) {
      totalCost = 0.0;
    }
    double marketValue = totalShares * price;
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

final valueAssetDetailProvider =
    StreamProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.assets.watchObject(assetId, fireImmediately: true);
});

final valueAssetPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, assetId) async {
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) {
    throw Exception('未找到资产');
  }
  return CalculatorService().calculateValueAssetPerformance(asset);
});

final valueAssetHistoryChartsProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
        (ref, assetId) async {
  ref.watch(valueAssetPerformanceProvider(assetId)); 
  
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) {
    return {'totalValue': [], 'totalProfit': [], 'profitRate': []};
  }
  return CalculatorService().getValueAssetHistoryCharts(asset);
});


// (*** 5. 关键修改：重命名 init 方法并调整构造函数，使其能被外部调用 ***)
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  // 我们在 main.dart 中预加载主题，所以这里不再需要调用 init
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  // 默认设置为“跟随系统”，将在 init 方法中被覆盖
  ThemeNotifier() : super(ThemeMode.system);

  // 从本地存储加载主题设置，现在是公共方法
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    state = ThemeMode.values[themeIndex];
  }

  // 设置新主题并保存到本地
  Future<void> setTheme(ThemeMode themeMode) async {
    if (state != themeMode) {
      state = themeMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', themeMode.index);
    }
  }
}

// ------------------------ 已清仓（归档）资产 Providers ------------------------

final archivedAssetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final isar = ref.watch(databaseServiceProvider).isar;
  final calculator = CalculatorService();
  
  // 1. 查询所有已归档的资产
  final archivedAssets = await isar.assets
      .where()
      .filter()
      .isArchivedEqualTo(true)
      .findAll();

  // 2. 为了显示账户名，我们一次性获取所有账户信息
  final allAccounts = await isar.accounts.where().findAll();
  final accountMap = { for (var acc in allAccounts) acc.supabaseId : acc.name };

  // 3. 为每个归档资产计算其最终性能
  final List<Map<String, dynamic>> results = [];
  for (final asset in archivedAssets) {
    Map<String, dynamic> performanceData;
    if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
      performanceData = await calculator.calculateShareAssetPerformance(asset);
    } else {
      performanceData = await calculator.calculateValueAssetPerformance(asset);
    }
    results.add({
      'asset': asset,
      'performance': performanceData,
      'accountName': accountMap[asset.accountSupabaseId] ?? '未知账户',
    });
  }
  
  // 按更新时间倒序排列，最近清仓的在最前面
  results.sort((a, b) {
    final dateA = (a['asset'] as Asset).updatedAt ?? DateTime(2000);
    final dateB = (b['asset'] as Asset).updatedAt ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });

  return results;
});
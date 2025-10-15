// File: lib/providers/global_providers.dart
// Version: CHATGPT-1.04-20251014-TZ-FIX

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
import 'package:one_five_one_ten/utils/timezone.dart'; // ☆ 新增：引入工具

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
      print('[PriceSyncController] 开始为 ${assetsToSync.length} 个资产同步价格...');
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
      print('[PriceSyncController] 同步完成。 成功: $successCount, 失败: $failCount');
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

// ------------------------ 🔧 核心热修复位置开始 ------------------------
// 原实现：查询时就 isArchived==false 直接过滤，价值法若被误标归档会被隐藏
// 修复：查询不加 isArchived 过滤；在代码里：
//  - shareBased：若 isArchived==true 则跳过
//  - valueBased：无论 isArchived 值为何，统一保留（交给 Calculator 渲染表现）
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

  // ✅ 去掉 isArchivedEqualTo(false) 的一刀切过滤
  final assetStream = isar.assets
      .where()
      .filter()
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .watch(fireImmediately: true);

  await for (var assets in assetStream) {
    final List<Map<String, dynamic>> results = [];
    for (final asset in assets) {
      // 份额法：仍然遵守归档不显示
      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        if (asset.isArchived) {
          continue;
        }
        final perf = await calculator.calculateShareAssetPerformance(asset);
        results.add({'asset': asset, 'performance': perf});
        continue;
      }

      // 价值法：⚠️ 忽略 isArchived 标记（避免被“份额为0=清仓=归档”的旧逻辑误伤）
      if (asset.trackingMethod == AssetTrackingMethod.valueBased) {
        final perf = await calculator.calculateValueAssetPerformance(asset);
        results.add({'asset': asset, 'performance': perf});
        continue;
      }

      // 其它兜底（若将来扩展）
      final perf = await calculator.calculateValueAssetPerformance(asset);
      results.add({'asset': asset, 'performance': perf});
    }
    yield results;
  }
});
// ------------------------ 🔧 核心热修复位置结束 ------------------------

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
  if (asset.isArchived) {
    return CalculatorService().calculateArchivedShareAssetPerformance(asset);
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
  } else if (asset.subType == AssetSubType.stock ||
      asset.subType == AssetSubType.etf) {
    return priceService.syncKLineHistory(asset.code);
  }
  return [];
});

final snapshotHistoryProvider =
    StreamProvider.autoDispose.family<List<PositionSnapshot>, int>((ref, assetId) async* {
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
  // 价格(按日) + 快照(按日) → 统一到 UTC 日维度
  final priceHistoryFuture = ref.watch(assetHistoryChartProvider(assetId).future);
  final snapshotHistoryFuture = ref.watch(snapshotHistoryProvider(assetId).future);

  final priceHistory = await priceHistoryFuture;   // List<FlSpot>，其 x 可能是本地/UTC 毫秒
  final snapshots = await snapshotHistoryFuture;   // List<PositionSnapshot>，其 date 可能是本地/UTC

  if (snapshots.isEmpty || priceHistory.isEmpty) {
    return {'price': priceHistory, 'totalProfit': [], 'profitRate': []};
  }

  // —— 1) 以第一条快照的“UTC 当天”作为起点 —— //
  final firstSnapDateUtc = utcDateOnly(snapshots.first.date);
  final firstSnapshotEpoch = firstSnapDateUtc.millisecondsSinceEpoch.toDouble();

  // —— 2) 价格序列的 X 统一到 UTC 当天 —— //
  final List<FlSpot> normalizedPrice = priceHistory
      .map((s) {
        final d = DateTime.fromMillisecondsSinceEpoch(s.x.toInt(), isUtc: false);
        // 如果原始 x 是 UTC 毫秒，这里 toUtc(). 如果是本地毫秒，这里先当本地再转 UTC 零点
        final x = utcDateEpoch(d);
        return FlSpot(x, s.y);
      })
      .toList()
    ..sort((a, b) => a.x.compareTo(b.x));

  // —— 3) 快照按日期升序，后续做“随日推进的活动快照” —— //
  final sortedSnapshots = List<PositionSnapshot>.from(snapshots)
    ..sort((a, b) => a.date.compareTo(b.date));

  // —— 4) 仅保留 >= 起点 的价格 —— //
  final relevantPriceHistory = normalizedPrice.where((s) => s.x >= firstSnapshotEpoch).toList();
  if (relevantPriceHistory.isEmpty) {
    return {'price': [], 'totalProfit': [], 'profitRate': []};
  }

  // —— 5) 逐日推进，选择“当天（UTC）不晚于该日”的最新快照 —— //
  final List<FlSpot> profitSpots = [];
  final List<FlSpot> profitRateSpots = [];

  PositionSnapshot? activeSnapshot;
  int snapIdx = 0;

  for (final priceSpot in relevantPriceHistory) {
    final currentUtc = DateTime.fromMillisecondsSinceEpoch(priceSpot.x.toInt(), isUtc: true);

    // 推进快照游标：选择 date(转UTC日) <= currentUtc 的最新一条
    while (snapIdx < sortedSnapshots.length) {
      final sdtUtc = utcDateOnly(sortedSnapshots[snapIdx].date);
      if (!sdtUtc.isAfter(currentUtc)) {
        activeSnapshot = sortedSnapshots[snapIdx];
        snapIdx++;
      } else {
        break;
      }
    }

    if (activeSnapshot == null) {
      profitSpots.add(FlSpot(priceSpot.x, 0.0));
      profitRateSpots.add(FlSpot(priceSpot.x, 0.0));
      continue;
    }

    // —— 6) 用你现有 share 快照字段：totalShares / averageCost —— //
    double totalShares = activeSnapshot.totalShares;
    double averageCost = activeSnapshot.averageCost;
    final price = priceSpot.y;

    if (!totalShares.isFinite || totalShares <= 0) {
      profitSpots.add(FlSpot(priceSpot.x, 0.0));
      profitRateSpots.add(FlSpot(priceSpot.x, 0.0));
      continue;
    }
    if (!averageCost.isFinite) averageCost = 0.0;

    double totalCost = totalShares * averageCost;
    double marketValue = totalShares * price;
    double totalProfit = marketValue - totalCost;
    double profitRate = (totalCost == 0 || !totalCost.isFinite) ? 0.0 : totalProfit / totalCost;

    if (!totalCost.isFinite) totalCost = 0.0;
    if (!marketValue.isFinite) marketValue = 0.0;
    if (!totalProfit.isFinite) totalProfit = 0.0;
    if (!profitRate.isFinite) profitRate = 0.0;

    profitSpots.add(FlSpot(priceSpot.x, totalProfit));
    profitRateSpots.add(FlSpot(priceSpot.x, profitRate));
  }

  // —— 7) 保证至少两点，避免线条不显示 —— //
  void ensureTwoSpots(List<FlSpot> spots, [double defaultY = 0.0]) {
    if (spots.length == 1) {
      final firstUtc = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt(), isUtc: true);
      final dayBeforeUtc = firstUtc.subtract(const Duration(days: 1));
      spots.insert(0, FlSpot(dayBeforeUtc.millisecondsSinceEpoch.toDouble(), defaultY));
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

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    state = ThemeMode.values[themeIndex];
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    if (state != themeMode) {
      state = themeMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', themeMode.index);
    }
  }
}

// ------------------------ 已清仓（归档）资产 Providers ------------------------

final archivedAssetsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final isar = ref.watch(databaseServiceProvider).isar;
  final calculator = CalculatorService();

  final archivedAssets =
      await isar.assets.where().filter().isArchivedEqualTo(true).findAll();

  final allAccounts = await isar.accounts.where().findAll();
  final accountMap = {for (var acc in allAccounts) acc.supabaseId: acc.name};

  final List<Future<Map<String, dynamic>>> futures =
      archivedAssets.map((asset) async {
    Map<String, dynamic> performanceData;

    if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
      performanceData =
          await calculator.calculateArchivedShareAssetPerformance(asset);
    } else {
      performanceData = await calculator.calculateValueAssetPerformance(asset);
    }

    return {
      'asset': asset,
      'performance': performanceData,
      'accountName': accountMap[asset.accountSupabaseId] ?? '未知账户',
    };
  }).toList();

  final results = await Future.wait(futures);

  results.sort((a, b) {
    final dateA = (a['asset'] as Asset).updatedAt ?? DateTime(2000);
    final dateB = (b['asset'] as Asset).updatedAt ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });

  return results;
});

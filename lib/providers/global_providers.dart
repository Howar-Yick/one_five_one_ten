// File: lib/providers/global_providers.dart
// Version: CHATGPT-1.15-20251130-SNAPSHOT-POSITION-SNAPSHOT-FIX

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/transaction.dart';

import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/price_sync_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

import 'package:one_five_one_ten/utils/timezone.dart'; // ☆

const int kNavTabDashboard = 0;
const int kNavTabAccounts = 1;
const int kNavTabConfig = 2;
const int kNavTabSettings = 3;

final mainNavIndexProvider = StateProvider<int>((ref) => kNavTabDashboard);

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

      final futures = assetsToSync.map((asset) async {
        try {
          final newPrice = await priceService.syncPrice(asset);
          if (newPrice != null && newPrice != asset.latestPrice) {
            asset.latestPrice = newPrice;
            asset.priceUpdateDate = DateTime.now();
            await syncService.saveAsset(asset);
            print(
                '[PriceSyncController] 同步成功 ${asset.name}: $newPrice');
            return true;
          } else if (newPrice == null) {
            print('[PriceSyncController] 未能获取价格 ${asset.name}');
            return false;
          }
          return null;
        } catch (e) {
          print(
              '[PriceSyncController] 同步 ${asset.name} 时出错: $e');
          return false;
        }
      }).toList();

      final results = await Future.wait(futures);
      final successCount = results.where((r) => r == true).length;
      final failCount = results.where((r) => r == false).length;

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

// ------------------------ 资产列表 ------------------------

final trackedAssetsWithPerformanceProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
        (ref, accountId) async* {
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
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .watch(fireImmediately: true);

  await for (var assets in assetStream) {
    final List<Map<String, dynamic>> results = [];
    for (final asset in assets) {
      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        if (asset.isArchived) continue;
        final perf = await calculator.calculateShareAssetPerformance(asset);
        results.add({'asset': asset, 'performance': perf});
        continue;
      }
      if (asset.trackingMethod == AssetTrackingMethod.valueBased) {
        final perf = await calculator.calculateValueAssetPerformance(asset);
        results.add({'asset': asset, 'performance': perf});
        continue;
      }
      final perf = await calculator.calculateValueAssetPerformance(asset);
      results.add({'asset': asset, 'performance': perf});
    }
    yield results;
  }
});

// ------------------------ 账户曲线 ------------------------

final accountHistoryProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Account>(
        (ref, account) async {
  ref.watch(accountPerformanceProvider(account.id));

  final raw = await CalculatorService().getAccountHistoryCharts(account);
  final List<FlSpot> rawValue =
      (raw['totalValue'] ?? const <FlSpot>[]) as List<FlSpot>;
  final List<FlSpot> rawProfit =
      (raw['totalProfit'] ?? const <FlSpot>[]) as List<FlSpot>;
  final List<FlSpot> rawRate =
      (raw['profitRate'] ?? const <FlSpot>[]) as List<FlSpot>;

  void _ensureTwo(List<FlSpot> spots, double defaultY) {
    if (spots.isEmpty) return;
    if (spots.length == 1) {
      final d0 = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
      final dayBefore =
          d0.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
      spots.insert(0, FlSpot(dayBefore, defaultY));
    }
  }

  List<FlSpot> _trimLeadingZerosAndPrependPrev(List<FlSpot> spots,
      {double epsilon = 1e-8}) {
    if (spots.isEmpty) return spots;
    final list = List<FlSpot>.from(spots)..sort((a, b) => a.x.compareTo(b.x));
    int k = 0;
    while (k < list.length &&
        (list[k].y.isNaN || list[k].y.abs() < epsilon)) {
      k++;
    }
    if (k > 0 && k < list.length) {
      final trimmed = list.sublist(k);
      final d0 = DateTime.fromMillisecondsSinceEpoch(trimmed.first.x.toInt());
      final dayBefore =
          d0.subtract(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
      trimmed.insert(0, FlSpot(dayBefore, trimmed.first.y));
      return trimmed;
    }
    return list;
  }

  List<FlSpot> value = _trimLeadingZerosAndPrependPrev(rawValue, epsilon: 1e-9);
  if (value.isNotEmpty) {
    _ensureTwo(value, value.first.y);
  }

  double? valueMinY;
  double? valueMaxY;
  if (value.isNotEmpty) {
    double minY = value.first.y;
    double maxY = value.first.y;
    for (final s in value) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if (minY == maxY) {
      final pad = (maxY.abs() * 0.03).clamp(1e-6, double.infinity);
      valueMinY = maxY - pad;
      valueMaxY = maxY + pad;
    } else {
      final pad = (maxY - minY) * 0.03;
      valueMinY = minY - pad;
      valueMaxY = maxY + pad;
    }
  }

  final List<FlSpot> profit =
      _trimLeadingZerosAndPrependPrev(rawProfit, epsilon: 1e-8);
  final List<FlSpot> rate =
      _trimLeadingZerosAndPrependPrev(rawRate, epsilon: 1e-8);

  _ensureTwo(profit, 0.0);
  _ensureTwo(rate, 0.0);

  return {
    'totalValue': value,
    'totalProfit': profit,
    'profitRate': rate,
    'valueMinY': valueMinY,
    'valueMaxY': valueMaxY,
  };
});

// ------------------------ 账户流水 ------------------------

final transactionHistoryProvider =
    StreamProvider.autoDispose.family<List<AccountTransaction>, int>(
        (ref, accountId) async* {
  final isar = ref.watch(databaseServiceProvider).isar;
  final account = await isar.accounts.get(accountId);
  if (account == null || account.supabaseId == null) {
    yield [];
    return;
  }
  final accountSupabaseId = account.supabaseId!;
  final transactionStream = isar.accountTransactions
      .where()
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .sortByDateDesc()
      .watch(fireImmediately: true);
  yield* transactionStream;
});

// ------------------------ 份额法资产详情 & 业绩 ------------------------

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

// ------------------------ 份额法资产价格历史（远程行情） ------------------------

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

// ------------------------ ✅ 持仓快照历史（关键修复版） ------------------------
/// 逻辑：
/// 1. 监听指定 assetId 对应的 Asset（本地 Isar）；
/// 2. 只要 asset 或其 supabaseId 发生变化，就重新订阅 PositionSnapshot 列表；
/// 3. 用 asset.supabaseId == snapshot.assetSupabaseId 做关联。
final snapshotHistoryProvider =
    StreamProvider.autoDispose.family<List<PositionSnapshot>, int>(
        (ref, assetId) async* {
  final isar = ref.watch(databaseServiceProvider).isar;

  // 直接监听 Asset 对象，避免只取“第一次”的问题
  final assetStream =
      isar.assets.watchObject(assetId, fireImmediately: true);

  await for (final asset in assetStream) {
    if (asset == null || asset.supabaseId == null) {
      yield [];
      continue;
    }

    final assetSupabaseId = asset.supabaseId!;
    // 为当前 assetSupabaseId 建立一个快照流
    final snapshotsStream = isar.positionSnapshots
        .where()
        .assetSupabaseIdEqualTo(assetSupabaseId)
        .sortByDateDesc()
        .watch(fireImmediately: true);

    await for (final snaps in snapshotsStream) {
      // 这里再读一次资产，防止在内部循环时 asset 已经变更导致 supabaseId 不一致
      final currentAsset = await isar.assets.get(assetId);
      if (currentAsset == null ||
          currentAsset.supabaseId != assetSupabaseId) {
        // 资产已经换了 supabaseId，跳出内层循环，回到外层等待新 asset 事件
        break;
      }
      yield snaps;
    }
  }
});

// ------------------------ 份额法资产：价格 + 业绩三线合成图 ------------------------

final shareAssetCombinedChartProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
  (ref, assetId) async {
    final priceHistory =
        await ref.watch(assetHistoryChartProvider(assetId).future);
    final snapshots =
        await ref.watch(snapshotHistoryProvider(assetId).future);

    DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    void _ensureTwoSpots(List<FlSpot> spots, double defaultY) {
      if (spots.isEmpty) return;
      if (spots.length == 1) {
        final d0 = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
        final dayBefore =
            d0.subtract(const Duration(days: 1)).millisecondsSinceEpoch
                .toDouble();
        spots.insert(0, FlSpot(dayBefore, defaultY));
      }
    }

    if (priceHistory.isEmpty && snapshots.isEmpty) {
      return {
        'price': const [],
        'totalProfit': const [],
        'profitRate': const [],
      };
    }

    final sortedSnapshots = snapshots.toList()
      ..sort((a, b) => _dateOnly(a.date).compareTo(_dateOnly(b.date)));

    if (sortedSnapshots.isEmpty) {
      final price = priceHistory.toList();
      _ensureTwoSpots(price, price.isNotEmpty ? price.first.y : 0.0);
      return {
        'price': price,
        'totalProfit': const [],
        'profitRate': const [],
      };
    }

    final firstSnapDay = _dateOnly(sortedSnapshots.first.date);
    final firstSnapEpoch = firstSnapDay.millisecondsSinceEpoch.toDouble();

    final List<FlSpot> priceByDay = priceHistory.where((spot) {
      final d = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      final dayEpoch =
          _dateOnly(d).millisecondsSinceEpoch.toDouble();
      return dayEpoch >= firstSnapEpoch;
    }).toList();

    final List<FlSpot> effectivePrice =
        priceByDay.isNotEmpty ? priceByDay : priceHistory.toList();

    if (effectivePrice.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch
          .toDouble();
      return {
        'price': const [],
        'totalProfit': [FlSpot(yesterday, 0.0), FlSpot(now, 0.0)],
        'profitRate': [FlSpot(yesterday, 0.0), FlSpot(now, 0.0)],
      };
    }

    final List<FlSpot> profitSpots = [];
    final List<FlSpot> profitRateSpots = [];

    int snapIdx = 0;
    PositionSnapshot? active;

    for (final p in effectivePrice) {
      final pDate =
          _dateOnly(DateTime.fromMillisecondsSinceEpoch(p.x.toInt()));

      while (snapIdx < sortedSnapshots.length) {
        final sDate = _dateOnly(sortedSnapshots[snapIdx].date);
        if (sDate.isAfter(pDate)) break;
        active = sortedSnapshots[snapIdx];
        snapIdx++;
      }

      if (active == null) {
        profitSpots.add(FlSpot(p.x, 0.0));
        profitRateSpots.add(FlSpot(p.x, 0.0));
        continue;
      }

      final double shares = active!.totalShares;
      final double avgCost = active!.averageCost;
      final double price = p.y;

      if (!shares.isFinite || shares <= 0) {
        profitSpots.add(FlSpot(p.x, 0.0));
        profitRateSpots.add(FlSpot(p.x, 0.0));
        continue;
      }

      final double cost =
          (shares * avgCost).isFinite ? shares * avgCost : 0.0;
      final double mv =
          (shares * price).isFinite ? shares * price : 0.0;
      final double profit =
          (mv - cost).isFinite ? (mv - cost) : 0.0;
      final double rate = (cost == 0) ? 0.0 : (profit / cost);

      profitSpots.add(FlSpot(p.x, profit));
      profitRateSpots
          .add(FlSpot(p.x, rate.isFinite ? rate : 0.0));
    }

    _ensureTwoSpots(effectivePrice, effectivePrice.first.y);
    _ensureTwoSpots(profitSpots, 0.0);
    _ensureTwoSpots(profitRateSpots, 0.0);

    return {
      'price': effectivePrice,
      'totalProfit': profitSpots,
      'profitRate': profitRateSpots,
    };
  },
);

// ------------------------ 价值法资产 ------------------------

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
    throw Exception('未找到账户');
  }
  return CalculatorService().calculateValueAssetPerformance(asset);
});

/// 价值法资产 —— 统一按“日期”对齐；同日多次仅保留“最后一条”；确保至少两点
final valueAssetCombinedChartProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
        (ref, assetId) async {
  ref.watch(valueAssetPerformanceProvider(assetId));
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) {
    return {
      'totalValue': const [],
      'totalProfit': const [],
      'profitRate': const []
    };
  }
  final raw =
      await CalculatorService().getValueAssetHistoryCharts(asset);

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<FlSpot> _normalizeByDay(List<FlSpot> spots) {
    if (spots.isEmpty) return spots;
    final Map<int, FlSpot> lastOfDay = {};
    for (final s in spots) {
      final d = DateTime.fromMillisecondsSinceEpoch(s.x.toInt());
      final dayEpoch = _dateOnly(d).millisecondsSinceEpoch;
      lastOfDay[dayEpoch] = s;
    }
    final result = lastOfDay.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.y))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    return result;
  }

  void _ensureTwoSpots(List<FlSpot> spots, double defaultY) {
    if (spots.isEmpty) return;
    if (spots.length == 1) {
      final d0 = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
      final dayBefore =
          d0.subtract(const Duration(days: 1)).millisecondsSinceEpoch
              .toDouble();
      spots.insert(0, FlSpot(dayBefore, defaultY));
    }
  }

  final List<FlSpot> valueLine =
      _normalizeByDay((raw['totalValue'] ?? const <FlSpot>[]) as List<FlSpot>);
  final List<FlSpot> profitLine =
      _normalizeByDay((raw['totalProfit'] ?? const <FlSpot>[]) as List<FlSpot>);
  final List<FlSpot> rateLine =
      _normalizeByDay((raw['profitRate'] ?? const <FlSpot>[]) as List<FlSpot>);

  if (valueLine.isNotEmpty) _ensureTwoSpots(valueLine, valueLine.first.y);
  if (profitLine.isNotEmpty) _ensureTwoSpots(profitLine, 0.0);
  if (rateLine.isNotEmpty) _ensureTwoSpots(rateLine, 0.0);

  return {
    'totalValue': valueLine,
    'totalProfit': profitLine,
    'profitRate': rateLine,
  };
});

final valueAssetHistoryChartsProvider =
    FutureProvider.autoDispose.family<Map<String, List<FlSpot>>, int>(
        (ref, assetId) async {
  return ref.watch(valueAssetCombinedChartProvider(assetId).future);
});

// ------------------------ 主题切换 ------------------------

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex =
        prefs.getInt('themeMode') ?? ThemeMode.system.index;
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

// ------------------------ 已清仓（归档）资产 ------------------------

final archivedAssetsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final isar = ref.watch(databaseServiceProvider).isar;
  final calculator = CalculatorService();

  final archivedAssets =
      await isar.assets.where().isArchivedEqualTo(true).findAll();

  final allAccounts = await isar.accounts.where().findAll();
  final accountMap = {
    for (var acc in allAccounts) acc.supabaseId: acc.name
  };

  final List<Future<Map<String, dynamic>>> futures =
      archivedAssets.map((asset) async {
    Map<String, dynamic> performanceData;

    if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
      performanceData = await calculator
          .calculateArchivedShareAssetPerformance(asset);
    } else {
      performanceData =
          await calculator.calculateValueAssetPerformance(asset);
    }

    return {
      'asset': asset,
      'performance': performanceData,
      'accountName': accountMap[asset.accountSupabaseId] ?? '未知账户',
    };
  }).toList();

  final results = await Future.wait(futures);

  results.sort((a, b) {
    final dateA =
        (a['asset'] as Asset).updatedAt ?? DateTime(2000);
    final dateB =
        (b['asset'] as Asset).updatedAt ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });

  return results;
});

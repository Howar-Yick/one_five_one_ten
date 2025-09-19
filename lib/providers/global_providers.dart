// lib/providers/global_providers.dart
// (这是合并了 PriceSyncController 后的完整文件)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/price_sync_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

/// 说明：
/// 集中放置需要被多个页面跨页使用的顶层 Provider，避免页面之间互相 import 导致的循环依赖。


// ------------------------ 核心服务 Providers ------------------------

/// 数据库服务 Provider
/// (新增，用于统一管理 DatabaseService 实例)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// 全局 Supabase 同步服务 Provider
final syncServiceProvider = Provider<SupabaseSyncService>((ref) {
  // 创建 SupabaseSyncService 的单个实例，以便在整个应用中重复使用
  return SupabaseSyncService();
});

// ------------------------ 账户列表 ------------------------

/// 账户列表（供 AccountsPage 使用）
/// (*** 已修改：从 FutureProvider 更改为 StreamProvider 以实现实时更新 ***)
final accountsProvider = StreamProvider<List<Account>>((ref) {
  // 优化：使用 ref.watch 监听 databaseServiceProvider
  final isar = ref.watch(databaseServiceProvider).isar;
  // 2. 从 .findAll() 更改为 .watch()，以便在 Isar 数据变化时自动发送新列表
  return isar.accounts.where().sortByName().watch(fireImmediately: true);
});

// ------------------------ 首页总览（总资产/历史曲线/资产配置） ------------------------

/// 仪表盘数据（总资产 CNY + 历史曲线 CNY + 资产配置 CNY）
/// (*** 保持不变。注意：此 Provider 不会自动实时更新。***)
/// (要使其“实时”，我们需要对 CalculatorService 进行更深入的重构，让其所有计算都基于 Stream)
final dashboardDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final calc = CalculatorService();

  // 总资产（CNY）
  // globalPerf 这个 Map 已经包含了 totalValue, totalProfit, profitRate 等所有我们需要的数据
  final globalPerf = await calc.calculateGlobalPerformance();

  // 历史曲线（CNY）
  final List<FlSpot> historySpots = await calc.getGlobalValueHistory();

  // 资产配置（CNY）
  final Map<AssetSubType, double> allocation =
      await calc.calculateAssetAllocation();

  // 关键修改：使用 ...globalPerf 将所有性能指标注入返回的 Map
  return {
    ...globalPerf, // <-- 这会添加 totalValue, totalProfit, profitRate, annualizedReturn 等
    'historySpots': historySpots,
    'allocation': allocation,
  };
});

// ------------------------ 新增：价格同步 ------------------------

// 1. 创建一个 Provider 来提供 PriceSyncService 的实例
final priceSyncServiceProvider = Provider<PriceSyncService>((ref) {
  return PriceSyncService();
});

// 2. 创建一个枚举 (Enum) 来表示同步状态
enum PriceSyncState { idle, loading, success, error }

// 3. 创建一个 StateNotifier 来控制价格同步流程
class PriceSyncController extends StateNotifier<PriceSyncState> {
  final Ref _ref;
  PriceSyncController(this._ref) : super(PriceSyncState.idle);

  Future<void> syncAllPrices() async {
    // 防止重复点击
    if (state == PriceSyncState.loading) return;
    state = PriceSyncState.loading;

    try {
      // 依赖注入所需的服务
      final isar = _ref.read(databaseServiceProvider).isar;
      final priceService = _ref.read(priceSyncServiceProvider);
      final syncService = _ref.read(syncServiceProvider);

      // 1. 从本地数据库获取所有资产
      final allAssets = await isar.assets.where().findAll();

      // 2. 筛选出需要同步价格的资产
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

      // 3. 遍历并执行同步 (并行处理)
      final futures = assetsToSync.map((asset) async {
        try {
          // 4. 调用 PriceSyncService 获取价格
          final newPrice = await priceService.syncPrice(asset);

          if (newPrice != null && newPrice != asset.latestPrice) {
            // 5. 如果价格获取成功且与旧价格不同
            asset.latestPrice = newPrice;
            asset.priceUpdateDate = DateTime.now();

            // 6. 关键！调用 SupabaseSyncService 保存更新
            // 这会同时更新本地 Isar 和远程 Supabase
            await syncService.saveAsset(asset);

            print('[PriceSyncController] 同步成功 ${asset.name}: $newPrice');
            return true; // 标记成功
          } else if (newPrice == null) {
            print('[PriceSyncController] 未能获取价格 ${asset.name}');
            return false; // 标记失败
          }
          return null; // 价格无变化
        } catch (e) {
          print('[PriceSyncController] 同步 ${asset.name} 时出错: $e');
          return false; // 标记失败
        }
      }).toList();

      // 等待所有同步任务完成
      final results = await Future.wait(futures);

      successCount = results.where((r) => r == true).length;
      failCount = results.where((r) => r == false).length;

      print(
          '[PriceSyncController] 同步完成。 成功: $successCount, 失败: $failCount');

      // 7. 刷新依赖价格数据的 Provider (例如主页)
      _ref.invalidate(dashboardDataProvider);
      // 你可能还需要 invalidate 账户详情页的 provider
      // 例如: ref.invalidate(trackedAssetsWithPerformanceProvider);

      state = PriceSyncState.success;
    } catch (e) {
      print('[PriceSyncController] syncAllPrices 遭遇致命错误: $e');
      state = PriceSyncState.error; // 修正了上一条建议中的拼写错误
    }
  }
}

// 4. 创建一个 StateNotifierProvider 来提供上述 Controller
final priceSyncControllerProvider =
    StateNotifierProvider<PriceSyncController, PriceSyncState>((ref) {
  return PriceSyncController(ref);
});

// --- 价格同步服务结束 ---
// lib/providers/global_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';

// --- 新增：导入新服务 ---
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
// --- 新增结束 ---

/// 说明：
/// 集中放置需要被多个页面跨页使用的顶层 Provider，避免页面之间互相 import 导致的循环依赖。


// --- 新增：全局 Supabase 同步服务 Provider ---
final syncServiceProvider = Provider<SupabaseSyncService>((ref) {
  // 创建 SupabaseSyncService 的单个实例，以便在整个应用中重复使用
  return SupabaseSyncService();
});
// --- 新增结束 ---


// ------------------------ 账户列表 ------------------------

/// 账户列表（供 AccountsPage 使用）
/// (*** 已修改：从 FutureProvider 更改为 StreamProvider 以实现实时更新 ***)
final accountsProvider = StreamProvider<List<Account>>((ref) { // <-- 1. 更改为 StreamProvider
  final isar = DatabaseService().isar;
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
  final globalPerf = await calc.calculateGlobalPerformance();
  final double totalValue = (globalPerf['totalValue'] ?? 0.0) as double;

  // 历史曲线（CNY）
  final List<FlSpot> historySpots = await calc.getGlobalValueHistory();

  // 资产配置（CNY）
  final Map<AssetSubType, double> allocation = await calc.calculateAssetAllocation();

  return {
    'totalValue': totalValue,
    'historySpots': historySpots,
    'allocation': allocation,
  };
});
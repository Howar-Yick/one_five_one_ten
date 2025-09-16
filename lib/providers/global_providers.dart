// lib/providers/global_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';

/// 说明：
/// 集中放置需要被多个页面跨页使用的顶层 Provider，避免页面之间互相 import 导致的循环依赖。

// ------------------------ 账户列表 ------------------------

/// 账户列表（供 AccountsPage 使用）
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final isar = DatabaseService().isar;
  return isar.accounts.where().anyId().findAll();
});

// ------------------------ 首页总览（总资产/历史曲线/资产配置） ------------------------

/// 仪表盘数据（总资产 CNY + 历史曲线 CNY + 资产配置 CNY）
/// 依赖 CalculatorService：
///   - totalValue 使用 calculateGlobalPerformance()['totalValue']（已换算到 CNY）
///   - historySpots 使用 getGlobalValueHistory()（已按账户 updateValue 聚合并换算为 CNY）
///   - allocation 使用 calculateAssetAllocation()（已换算为 CNY）
///
/// 注意：返回的 Map 结构：
/// {
///   'totalValue': double,                 // CNY
///   'historySpots': List<FlSpot>,         // CNY
///   'allocation': Map<AssetSubType,double>// CNY
/// }
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

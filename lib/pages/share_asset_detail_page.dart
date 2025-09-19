// 文件: lib/pages/share_asset_detail_page.dart
// (这是已修复“编辑按钮”和“代码显示”的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart'; // <-- 1. 新增导入 (编辑按钮需要)
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
// import 'package:one_five_one_ten/models/transaction.dart'; // (已移除)
import 'package:one_five_one_ten/pages/snapshot_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; 
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
// import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart'; // (已移除)
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart'; // <-- 2. 新增导入 (编辑按钮需要)

// (Providers 已全部在 global_providers.dart 中定义)


class ShareAssetDetailPage extends ConsumerWidget {
  final int assetId;
  const ShareAssetDetailPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAsset = ref.watch(shareAssetDetailProvider(assetId));
    final asyncPerformance = ref.watch(shareAssetPerformanceProvider(assetId));
    final asyncChartData = ref.watch(assetHistoryChartProvider(assetId));

    return asyncAsset.when(
      data: (asset) {
        if (asset == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('资产不存在')),
            body: const Center(child: Text('此资产可能已被删除。')),
          );
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text(asset.name),
            // --- (*** 3. 这是关键修复：恢复“编辑”按钮 ***) ---
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑资产',
                onPressed: () async { 
                  // 编辑按钮需要父账户的本地 ID 才能导航
                  final isar = DatabaseService().isar;
                  final parentAccount = await isar.accounts.where()
                      .filter()
                      .supabaseIdEqualTo(asset.accountSupabaseId)
                      .findFirst();
                  
                  if (parentAccount != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // 传入正确的 accountId 和 assetId
                        builder: (_) => AddEditAssetPage(accountId: parentAccount.id, assetId: asset.id),
                      ),
                    );
                  } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('错误：找不到父账户')));
                  }
                },
              ),
            ],
            // --- (*** 修复结束 ***) ---
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
              ref.invalidate(shareAssetPerformanceProvider(assetId));
              ref.invalidate(assetHistoryChartProvider(assetId));
            },
            child: _ShareAssetDetailView(
              asset: asset,
              performanceAsync: asyncPerformance,
              chartAsync: asyncChartData,
            ),
          ),
          // --- (*** 4. 添加 FAB 按钮 ***) ---
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.sync_alt), 
            tooltip: '更新持仓快照',
            onPressed: () {
              _ShareAssetDetailView.showUpdateSnapshotDialog(context, ref, asset);
            },
          ),
          // --- (*** 添加结束 ***) ---
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('加载资产失败: $e')),
      ),
    );
  }
}


class _ShareAssetDetailView extends ConsumerWidget {
  final Asset asset;
  final AsyncValue<Map<String, dynamic>> performanceAsync;
  final AsyncValue<List<FlSpot>> chartAsync;

  const _ShareAssetDetailView({
    required this.asset,
    required this.performanceAsync,
    required this.chartAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return performanceAsync.when(
      data: (performance) {
        
        final String latestPriceString = formatPrice(asset.latestPrice, asset.subType);
        final String avgCostString = formatPrice(performance['averageCost'] ?? 0.0, asset.subType);

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatCurrency(performance['marketValue'] ?? 0.0, asset.currency),
                                style: Theme.of(context).textTheme.headlineMedium),
                            Text('当前市值', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(latestPriceString, style: Theme.of(context).textTheme.headlineSmall),
                            Text(asset.priceUpdateDate != null 
                                ? DateFormat('MM-dd HH:mm').format(asset.priceUpdateDate!) 
                                : '未更新', 
                                style: Theme.of(context).textTheme.bodySmall
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 24),
                    _buildMetricRow(
                      context,
                      '最新价格:',
                      latestPriceString,
                    ),
                    _buildMetricRow(
                      context, 
                      '单位成本:',
                      avgCostString,
                    ),
                    _buildMetricRow(context, '当前份额:', (performance['totalShares'] ?? 0.0).toString()),
                    _buildMetricRow(context, '持仓成本:', formatCurrency(performance['totalCost'] ?? 0.0, asset.currency)),
                  ],
                ),
              ),
            ),
            
            _buildPerformanceCard(context, performance, asset.currency),

            // (按钮区已按要求移除)

            chartAsync.when(
              data: (spots) => (spots.length < 2) 
                  ? const SizedBox.shrink() 
                  : _buildChartCard(context, spots, asset),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )),
              error: (e, s) => Text('图表加载失败: $e'),
            ),
            
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                TextButton(
                  child: const Text('查看持仓快照历史'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SnapshotHistoryPage(assetId: asset.id), 
                    ));
                  },
                ),
                // (“交易历史”按钮已移除)
              ],
            ),
            const SizedBox(height: 80), // (为 FAB 留出空间)
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('加载性能数据失败: $e')),
    );
  }

  // --- (*** 5. 新增：快照更新弹窗 (静态方法) ***) ---
  static void showUpdateSnapshotDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final performance = ref.read(shareAssetPerformanceProvider(asset.id));
    final sharesController = TextEditingController(
      text: performance.asData?.value['totalShares']?.toString() ?? ''
    );
    final costController = TextEditingController(
       text: performance.asData?.value['averageCost']?.toString() ?? ''
    );
    final priceController = TextEditingController(text: asset.latestPrice > 0 ? asset.latestPrice.toString() : ''); 
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新持仓快照'),
              content: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: sharesController, decoration: const InputDecoration(labelText: '最新总份额'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    TextField(controller: costController, decoration: InputDecoration(labelText: '最新单位成本', prefixText: getCurrencySymbol(asset.currency)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    TextField(controller: priceController, decoration: InputDecoration(labelText: '最新价格 (可选)', prefixText: getCurrencySymbol(asset.currency)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text("快照日期:", style: TextStyle(fontSize: 16)),
                        const Spacer(),
                        TextButton(
                          child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                            if (pickedDate != null) setState(() => selectedDate = pickedDate);
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    final priceText = priceController.text.trim();
                    
                    if (shares == null || cost == null) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('请输入有效的份额和成本'))
                         );
                       }
                       return;
                    }

                    try {
                      final syncService = ref.read(syncServiceProvider); 
                      
                      bool assetUpdated = false;
                      if (priceText.isNotEmpty) {
                        asset.latestPrice = double.tryParse(priceText) ?? asset.latestPrice;
                        asset.priceUpdateDate = DateTime.now();
                        assetUpdated = true;
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..assetSupabaseId = asset.supabaseId; 
                      
                      await syncService.savePositionSnapshot(newSnapshot);
                      
                      if(assetUpdated) {
                        await syncService.saveAsset(asset);
                      }

                      ref.invalidate(shareAssetPerformanceProvider(asset.id));
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(); // 1. 关闭弹窗
                      }
                      
                      // 6. (*** 按要求导航到历史页 ***)
                      if (context.mounted) {
                         Navigator.of(context).push(MaterialPageRoute(
                           builder: (_) => SnapshotHistoryPage(assetId: asset.id),
                         ));
                      }

                    } catch (e) {
                       print('更新快照失败: $e');
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('保存失败: $e'))
                         );
                       }
                    }
                  },
                  child: const Text('保存并查看历史'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- (*** 新增结束 ***) ---

  // (Metric Row 辅助函数保持不变)
  Widget _buildMetricRow(BuildContext context, String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // (Performance Card 函数保持不变)
  Widget _buildPerformanceCard(
      BuildContext context, Map<String, dynamic> performance, String currencyCode) {
    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    Color profitColor =
        totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('业绩概览',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _buildMetricRow(
              context, 
              '总收益:',
              '${formatCurrency(totalProfit, currencyCode)} (${percentFormat.format(profitRate)})',
               color: profitColor,
            ),
            _buildMetricRow(
              context, 
              '年化收益率:',
              percentFormat.format(annualizedReturn),
              color: annualizedReturn > 0 
                  ? Colors.red.shade400
                  : Colors.green.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // (Chart Card 函数保持不变)
  Widget _buildChartCard(
      BuildContext context, List<FlSpot> spots, Asset asset) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final String chartTitle = (asset.subType == AssetSubType.mutualFund) ? '单位净值历史' : '价格历史 (日K收盘)';
    
    final yAxisFormat = (asset.subType == AssetSubType.mutualFund)
      ? NumberFormat("0.0000") 
      : (asset.subType == AssetSubType.etf 
        ? NumberFormat("0.000") 
        : NumberFormat("0.00")); 
    
    final tooltipFormat = yAxisFormat;

    final List<FlSpot> indexedSpots = [];
    for (int i = 0; i < spots.length; i++) {
      indexedSpots.add(FlSpot(i.toDouble(), spots[i].y));
    }

    double bottomInterval;
    const desiredLabelCount = 4.0;
    if (spots.length <= desiredLabelCount) {
      bottomInterval = 1;
    } else {
      bottomInterval = (spots.length - 1) / desiredLabelCount;
      if (bottomInterval < 1) bottomInterval = 1;
    }

    const int densityThreshold = 150; 
    final bool isDense = spots.length > densityThreshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chartTitle, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0, 
                  maxX: (spots.length - 1).toDouble(), 
                  
                  lineBarsData: [
                    LineChartBarData(
                      spots: indexedSpots, 
                      isCurved: false,
                      barWidth: isDense ? 2 : 3, 
                      color: colorScheme.primary, 
                      dotData: FlDotData(show: !isDense), 
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 50, 
                      getTitlesWidget: (value, meta) => Text(
                          yAxisFormat.format(value),
                          style: const TextStyle(fontSize: 10)),
                    )),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, 
                        reservedSize: 30, 
                        interval: bottomInterval, 
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index >= 0 && index < spots.length) {
                            final date = DateTime.fromMillisecondsSinceEpoch(spots[index].x.toInt()); 
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('yy-MM-dd').format(date),
                                style: const TextStyle(fontSize: 10), 
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        }
                      )
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpotsList) {
                        return touchedSpotsList.map((touchedSpot) {
                          final int index = touchedSpot.x.round();
                          if (index < 0 || index >= spots.length) return null;
                          
                          final originalSpot = spots[index]; 
                          final date = DateFormat('yyyy-MM-dd')
                              .format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                          
                          final valueStr = tooltipFormat.format(originalSpot.y); 

                          return LineTooltipItem(
                            '$date\n$valueStr', 
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          );
                        }).whereType<LineTooltipItem>().toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
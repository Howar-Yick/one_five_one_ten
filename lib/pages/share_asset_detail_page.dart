// 文件: lib/pages/share_asset_detail_page.dart
// (这是已修复所有已知 bug 和格式错误的最终完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/snapshot_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; // 导入 Sync Service (现在包含所有 provider)
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart';
import 'package:isar/isar.dart';

// (所有 Provider 定义都已正确移动到 global_providers.dart)


class ShareAssetDetailPage extends ConsumerWidget {
  final int assetId;
  const ShareAssetDetailPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // (我们现在从 global_providers.dart 中 watch 这些 Provider)
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
            // 1. 顶部卡片 (总览)
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
                      context, // (这是之前版本缺失的 context，现在已添加)
                      '最新价格:',
                      latestPriceString,
                    ),
                    _buildMetricRow(
                      context, // (这是之前版本缺失的 context，现在已添加)
                      '单位成本:',
                      avgCostString,
                    ),
                    _buildMetricRow(context, '当前份额:', (performance['totalShares'] ?? 0.0).toString()),
                    _buildMetricRow(context, '持仓成本:', formatCurrency(performance['totalCost'] ?? 0.0, asset.currency)),
                  ],
                ),
              ),
            ),
            
            // 2. 中部卡片 (业绩)
            _buildPerformanceCard(context, performance, asset.currency),
            
            // 3. 按钮
            const SizedBox(height: 8),
            _buildActionButtons(context, ref, asset),
            const SizedBox(height: 8),

            // 4. 图表卡片
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
            
            // 5. 辅助按钮
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                TextButton(
                  child: const Text('查看持仓快照历史'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SnapshotHistoryPage(assetId: asset.id), // (已修复)
                    ));
                  },
                ),
                TextButton(
                  child: const Text('查看交易历史'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AssetTransactionHistoryPage(assetId: asset.id), // (已修复)
                    ));
                  },
                ),
              ],
            )
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('加载性能数据失败: $e')),
    );
  }

  // (ActionButtons 保持不变)
  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Asset asset) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('买入'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => _showAddTransactionDialog(context, ref, asset, TransactionType.buy),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.sell_outlined),
            label: const Text('卖出'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade400),
            onPressed: () => _showAddTransactionDialog(context, ref, asset, TransactionType.sell),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.card_giftcard),
            label: const Text('分红'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade400),
            onPressed: () => _showAddTransactionDialog(context, ref, asset, TransactionType.dividend),
          ),
        ),
      ],
    );
  }

  // (Transaction Dialog 保持不变, 但已包含类型修复)
  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, Asset asset, TransactionType type) {
    final sharesController = TextEditingController();
    final priceController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    String title = '记录交易';
    switch (type) {
      case TransactionType.buy: title = '买入 ${asset.name}'; break;
      case TransactionType.sell: title = '卖出 ${asset.name}'; break;
      case TransactionType.dividend: title = '${asset.name} 分红'; break;
      default: break;
    }

    void autoCalculate() {
      final shares = double.tryParse(sharesController.text);
      final price = double.tryParse(priceController.text);
      if (shares != null && price != null) {
        amountController.text = (shares * price).toStringAsFixed(2);
      }
    }
    sharesController.addListener(autoCalculate);
    priceController.addListener(autoCalculate);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (type != TransactionType.dividend) ...[
                    TextField(
                      controller: sharesController,
                      decoration: const InputDecoration(labelText: '份额'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: '价格'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(labelText: type == TransactionType.dividend ? '分红总额' : '总金额'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    readOnly: type != TransactionType.dividend,
                  ),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() { selectedDate = pickedDate; });
                          }
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
                  
                  // (*** 语法修复：类型错误 ***)
                  final shares = (type != TransactionType.dividend) ? double.tryParse(sharesController.text) : 0.0; // <-- 修复: 0.0 是 double
                  
                  final price = (type != TransactionType.dividend) ? double.tryParse(priceController.text) : null;
                  final amount = double.tryParse(amountController.text);

                  if (amount == null || amount <= 0) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
                    return;
                  }
                  if (type != TransactionType.dividend && (shares == null || shares <= 0 || price == null)) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效份额和价格')));
                    return;
                  }

                  final newTxn = Transaction()
                    ..type = type
                    ..date = selectedDate
                    ..amount = (type == TransactionType.buy) ? -amount : amount // 买入为负现金流，卖出和分红为正
                    ..shares = (type == TransactionType.sell) ? -(shares!) : shares 
                    ..price = price
                    ..createdAt = DateTime.now()
                    ..assetSupabaseId = asset.supabaseId;
                    
                  try {
                    final syncService = ref.read(syncServiceProvider);
                    final isar = DatabaseService().isar;

                    await isar.writeTxn(() async {
                      await isar.transactions.put(newTxn);
                    });
                    
                    await syncService.saveTransaction(newTxn);

                    // (*** 语法修复：调用 CalculatorService 中的函数 ***)
                    final newSnapshot = await CalculatorService().recalculatePositionSnapshot(asset, newTxn);
                    if (newSnapshot != null) {
                      await isar.writeTxn(() async {
                        await isar.positionSnapshots.put(newSnapshot);
                      });
                      await syncService.savePositionSnapshot(newSnapshot);
                    }

                    ref.invalidate(shareAssetPerformanceProvider(asset.id));
                    ref.invalidate(dashboardDataProvider);

                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  
                  } catch (e) {
                    print('保存交易失败: $e');
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        });
      },
    );
  }

  // (*** 这是修复了 context 错误的 _buildMetricRow 定义 ***)
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

  // (*** 这是修复了 context 错误的 _buildPerformanceCard ***)
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
              context, // <-- 修复：传递 context
              '总收益:',
              '${formatCurrency(totalProfit, currencyCode)} (${percentFormat.format(profitRate)})',
               color: profitColor,
            ),
            _buildMetricRow(
              context, // <-- 修复：传递 context
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

  // (*** 这是修复了小数位数的 Chart Card ***)
  Widget _buildChartCard(
      BuildContext context, List<FlSpot> spots, Asset asset) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final String chartTitle = (asset.subType == AssetSubType.mutualFund) ? '单位净值历史' : '价格历史 (日K收盘)';
    
    final yAxisFormat = (asset.subType == AssetSubType.mutualFund)
      ? NumberFormat("0.0000") // 场外基金 4 位小数
      : (asset.subType == AssetSubType.etf 
        ? NumberFormat("0.000") // 场内 3 位
        : NumberFormat("0.00")); // 股票 2 位
    
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
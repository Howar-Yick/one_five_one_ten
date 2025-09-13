import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:fl_chart/fl_chart.dart';

// Provider 用于获取单个价值法资产的历史数据点
final valueAssetHistoryProvider = FutureProvider.autoDispose.family<List<FlSpot>, Asset>((ref, asset) {
  // 当资产的业绩数据变化时（例如用户添加新交易），图表也应该自动刷新
  ref.watch(valueAssetPerformanceProvider(asset.id));
  // 调用我们已在 CalculatorService 中创建的、使用新混合逻辑的函数
  return CalculatorService().getValueAssetHistory(asset);
});

final valueAssetDetailProvider = FutureProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = DatabaseService().isar;
  return isar.assets.get(assetId);
});

final valueAssetPerformanceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, assetId) async {
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) throw '未找到资产';
  return CalculatorService().calculateValueAssetPerformance(asset);
});



class ValueAssetDetailPage extends ConsumerWidget {
  final int assetId;
  const ValueAssetDetailPage({super.key, required this.assetId});

  // 这是我们统一的、使用直线风格的图表构建方法
  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');
    final colorScheme = Theme.of(context).colorScheme;

    double? bottomInterval;
    if (spots.length > 1) {
      final firstMs = spots.first.x;
      final lastMs = spots.last.x;
      final durationMillis = (lastMs - firstMs).abs();
      const desiredLabelCount = 4.0;
      if (durationMillis > 0) {
        bottomInterval = durationMillis / desiredLabelCount;
      }
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: spots.first.x,
          maxX: spots.last.x,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false, // 使用直线
              barWidth: 3,
              color: colorScheme.primary, 
              dotData: const FlDotData(show: true), // 显示数据点
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(currencyFormat.format(value), style: const TextStyle(fontSize: 10)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 30, 
                interval: bottomInterval, 
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('yy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(value.toInt())), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center,),
                  );
                }
              )
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()));
                  final value = NumberFormat.currency(locale: 'zh_CN', symbol: '¥').format(spot.y);
                  return LineTooltipItem(
                    '$date\n$value',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAsset = ref.watch(valueAssetDetailProvider(assetId));
    final asyncPerformance = ref.watch(valueAssetPerformanceProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: Text(asyncAsset.asData?.value?.name ?? '加载中...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑资产',
            onPressed: () {
              final asset = asyncAsset.asData?.value;
              if (asset != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddEditAssetPage(accountId: asset.account.value!.id, assetId: asset.id),
                  ),
                );
              }
            },
          )
        ],
      ),
      body: asyncPerformance.when(
        data: (performance) {
          final asset = asyncAsset.asData!.value!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildPerformanceCard(context, ref, asset, performance),
              const SizedBox(height: 24),

              // --- 新增：调用图表 ---
              ref.watch(valueAssetHistoryProvider(asset)).when(
                data: (spots) {
                  if (spots.length < 2) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('资产净值趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          _buildHistoryChart(context, spots),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e,s) => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, WidgetRef ref, Asset asset, Map<String, dynamic> performance) {
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final profitRate = (performance['profitRate'] ?? 0.0) as double;
    final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    Color profitColor = totalProfit > 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('资产概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '查看更新记录',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssetTransactionHistoryPage(assetId: asset.id),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            _buildMetricRow(context, '当前总值:', currencyFormat.format(performance['currentValue'] ?? 0.0)),
            _buildMetricRow(context, '净投入:', currencyFormat.format(performance['netInvestment'] ?? 0.0)),
            _buildMetricRow(context, '总收益:', '${currencyFormat.format(totalProfit)} (${percentFormat.format(profitRate)})', color: profitColor),
            _buildMetricRow(context, '年化收益率:', percentFormat.format(annualizedReturn), color: annualizedReturn > 0 ? Colors.red.shade400 : Colors.green.shade400),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _showInvestWithdrawDialog(context, ref, asset), child: const Text('资金操作')),
                ElevatedButton(onPressed: () => _showUpdateValueDialog(context, ref, asset), child: const Text('更新总值')),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showInvestWithdrawDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final amountController = TextEditingController();
    final List<bool> isSelected = [true, false];
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('资金操作'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToggleButtons(
                    isSelected: isSelected,
                    onPressed: (index) => setState(() { isSelected[0] = index == 0; isSelected[1] = index == 1; }),
                    borderRadius: BorderRadius.circular(8.0),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('投入')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('转出')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '金额', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
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
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      final isar = DatabaseService().isar;
                      final newTxn = Transaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw
                        ..asset.value = asset;
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                        await newTxn.asset.save();
                      });
                      ref.invalidate(valueAssetPerformanceProvider(asset.id));
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssetTransactionHistoryPage(assetId: asset.id),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUpdateValueDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final valueController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新资产总值'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '当前资产总价值', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
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
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final value = double.tryParse(valueController.text);
                    if (value != null) {
                      final isar = DatabaseService().isar;
                      final newTxn = Transaction()
                        ..amount = value
                        ..date = selectedDate
                        ..type = TransactionType.updateValue
                        ..asset.value = asset;
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                        await newTxn.asset.save();
                      });
                      ref.invalidate(valueAssetPerformanceProvider(asset.id));
                      if (dialogContext.mounted) {
                         Navigator.of(dialogContext).pop();
                         Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssetTransactionHistoryPage(assetId: asset.id),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
}
// 文件: lib/pages/value_asset_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// 1. (新增) 导入 Providers 和新服务
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/models/account.dart'; // 修复导航需要

// --- Provider 1 & 2 (保持不变) ---
final valueAssetDetailProvider = FutureProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = DatabaseService().isar;
  return isar.assets.get(assetId);
});

final valueAssetPerformanceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, assetId) async {
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) throw '未找到资产';
  return CalculatorService().calculateValueAssetPerformance(asset);
});

// --- Provider 3 (保持不变) ---
// 这个 Provider 已经依赖 performance provider，逻辑是正确的
final valueAssetHistoryProvider = FutureProvider.autoDispose.family<List<FlSpot>, Asset>((ref, asset) {
  ref.watch(valueAssetPerformanceProvider(asset.id));
  return CalculatorService().getValueAssetHistory(asset);
});

class ValueAssetDetailPage extends ConsumerWidget {
  final int assetId;
  const ValueAssetDetailPage({super.key, required this.assetId});

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
            onPressed: () async { // 2. (修改) 改为 async
              final asset = asyncAsset.asData?.value;
              if (asset != null) {
                
                // 3. (*** 关键修复：修复导航逻辑 ***)
                // 与 share_asset_detail_page 一样的修复
                final isar = DatabaseService().isar; // (*** 修正：使用 DatabaseService().isar ***)
                final parentAccount = await isar.accounts.where()
                                          .filter() // (*** 修正：添加 filter() ***)
                                          .supabaseIdEqualTo(asset.accountSupabaseId)
                                          .findFirst();
                
                if (parentAccount != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddEditAssetPage(accountId: parentAccount.id, assetId: asset.id),
                    ),
                  );
                } else if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('错误：找不到父账户')));
                }
              }
            },
          )
        ],
      ),
      body: asyncPerformance.when(
        data: (performance) {
          if (asyncAsset.asData?.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final asset = asyncAsset.asData!.value!;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(valueAssetPerformanceProvider(assetId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildPerformanceCard(context, ref, asset, performance),
                const SizedBox(height: 24),
                
                // --- 图表逻辑 (保持不变) ---
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
                            _buildLineChart(context, spots, asset),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, WidgetRef ref, Asset asset, Map<String, dynamic> performance) {
    // (*** 内部逻辑和布局保持不变 ***)
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final profitRate = (performance['profitRate'] ?? 0.0) as double;
    final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    Color profitColor = totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
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
                    // (导航保持不变，HistoryPage 稍后修复)
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
            _buildMetricRow(context, '当前总值:', formatCurrency(performance['currentValue'] ?? 0.0, asset.currency)),
            _buildMetricRow(context, '净投入:', formatCurrency(performance['netInvestment'] ?? 0.0, asset.currency)),
            _buildMetricRow(context, '总收益:', '${formatCurrency(totalProfit, asset.currency)} (${percentFormat.format(profitRate)})', color: profitColor),
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

  // 4. (*** 关键修复：_showInvestWithdrawDialog 写入逻辑 ***)
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
                // (UI 保持不变)
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
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '金额', prefixText: getCurrencySymbol(asset.currency))),
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
                      final syncService = ref.read(syncServiceProvider); // 5. 获取服务
                      final isInvest = isSelected[0];

                      final newTxn = Transaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now() // (设置 createdAt)
                        ..type = isInvest ? TransactionType.invest : TransactionType.withdraw
                        // 6. (关键) 设置 SUPABASE ID 关系
                        ..assetSupabaseId = asset.supabaseId; 
                        
                      // 7. 调用 SyncService 保存
                      await syncService.saveTransaction(newTxn);
                      
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

  // 8. (*** 关键修复：_showUpdateValueDialog 写入逻辑 ***)
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
                // (UI 保持不变)
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '当前资产总价值', prefixText: getCurrencySymbol(asset.currency))),
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
                      final syncService = ref.read(syncServiceProvider); // 9. 获取服务

                      final newTxn = Transaction()
                        ..amount = value
                        ..date = selectedDate
                        ..createdAt = DateTime.now() // (设置 createdAt)
                        ..type = TransactionType.updateValue
                        // 10. (关键) 设置 SUPABASE ID 关系
                        ..assetSupabaseId = asset.supabaseId; 
                      
                      await syncService.saveTransaction(newTxn); // 11. 调用 SyncService

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

  // (*** 您的图表和 metric row 辅助函数保持不变 ***)
  Widget _buildLineChart(BuildContext context, List<FlSpot> spots, Asset asset) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(asset.currency));
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
              isCurved: false,
              barWidth: 3,
              color: colorScheme.primary, 
              dotData: const FlDotData(show: true),
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
                  final value = formatCurrency(spot.y, asset.currency);
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
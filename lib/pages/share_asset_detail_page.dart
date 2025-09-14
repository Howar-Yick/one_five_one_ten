import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'package:one_five_one_ten/pages/snapshot_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/price_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

final shareAssetDetailProvider = FutureProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = DatabaseService().isar;
  return isar.assets.get(assetId);
});

final shareAssetPerformanceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, assetId) async {
  final asset = await ref.watch(shareAssetDetailProvider(assetId).future);
  if (asset == null) {
    throw '未找到资产';
  }
  return CalculatorService().calculateShareAssetPerformance(asset);
});

final snapshotHistoryProvider = StreamProvider.autoDispose.family<List<PositionSnapshot>, int>((ref, assetId) {
  final isar = DatabaseService().isar;
  return isar.assets.watchObject(assetId, fireImmediately: true).asyncMap((asset) async {
    if (asset != null) {
      await asset.snapshots.load();
      final snapshots = asset.snapshots.toList();
      snapshots.sort((a, b) => b.date.compareTo(a.date));
      return snapshots;
    }
    return [];
  });
});

// Provider 用于获取份额法资产的历史价格
final assetNavHistoryProvider = FutureProvider.autoDispose.family<List<FlSpot>, Asset>((ref, asset) {
  // 价格同步成功后，自动刷新图表
  ref.watch(shareAssetPerformanceProvider(asset.id));
  final service = PriceSyncService();
  switch (asset.subType) {
    case AssetSubType.mutualFund:
      return service.syncNavHistory(asset.code); // 场外基金调用净值历史
    case AssetSubType.stock:
    case AssetSubType.etf:
      return service.syncKLineHistory(asset.code); // 股票和ETF调用K线历史
    default:
      return Future.value([]);
  }
});

class ShareAssetDetailPage extends ConsumerWidget {
  final int assetId;
  const ShareAssetDetailPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAsset = ref.watch(shareAssetDetailProvider(assetId));

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
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '同步最新价格',
            onPressed: () async {
              final asset = asyncAsset.asData?.value;
              if (asset != null) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('正在同步价格...'),
                  duration: Duration(seconds: 2),
                ));

                final newPrice = await PriceSyncService().syncPrice(asset);
                
                ScaffoldMessenger.of(context).removeCurrentSnackBar();

                if (newPrice != null) {
                  final isar = DatabaseService().isar;
                  asset.latestPrice = newPrice;
                  asset.priceUpdateDate = DateTime.now();
                  await isar.writeTxn(() async => await isar.assets.put(asset));
                  ref.invalidate(shareAssetPerformanceProvider(assetId));
                  ref.invalidate(assetNavHistoryProvider(asset)); // 刷新图表
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('价格同步成功！')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步失败，请手动更新')));
                  await Future.delayed(const Duration(milliseconds: 100));
                  if(context.mounted) _showUpdatePriceDialog(context, ref, asset);
                }
              }
            },
          )
        ],
      ),
      body: asyncAsset.when(
        data: (asset) {
          if (asset == null) return const Center(child: Text('未找到该资产'));
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildPerformanceCard(context, ref, asset),
              const SizedBox(height: 24),

              // 为所有份额法资产（股票/ETF/场外）显示图表
              ref.watch(assetNavHistoryProvider(asset)).when(
                data: (spots) {
                  if (spots.length < 2) return const SizedBox.shrink(); 
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('历史价格趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          _buildHistoryChart(context, spots, asset), // 传入asset
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e,s) => const SizedBox.shrink(),
              ),
              
              const SizedBox(height: 24),
              _buildSnapshotHistory(context, ref, asset),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, WidgetRef ref, Asset asset) {
    final asyncPerformance = ref.watch(shareAssetPerformanceProvider(assetId));
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    return asyncPerformance.when(
      data: (performance) {
        final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
        final profitRate = (performance['profitRate'] ?? 0.0) as double;
        final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
        final priceUpdateDate = asset.priceUpdateDate;
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
                      tooltip: '查看快照历史',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SnapshotHistoryPage(assetId: asset.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(asset.code, style: TextStyle(color: Colors.grey.shade400)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '最新价: ${formatPrice(performance['latestPrice'] ?? 0.0, asset.currency, asset.subType.name)}', 
                          style: TextStyle(color: Colors.grey.shade400)
                        ),
                        if(priceUpdateDate != null)
                          Text(DateFormat('yyyy-MM-dd HH:mm').format(priceUpdateDate), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricRow(context, '当前市值:', formatCurrency(performance['marketValue'] ?? 0.0, asset.currency)),
                _buildMetricRow(context, '总成本:', formatCurrency(performance['totalCost'] ?? 0.0, asset.currency)),
                _buildMetricRow(context, '持有收益:', '${formatCurrency(totalProfit, asset.currency)} (${percentFormat.format(profitRate)})', color: profitColor),
                _buildMetricRow(context, '年化收益率:', percentFormat.format(annualizedReturn), color: annualizedReturn > 0 ? Colors.red.shade400 : Colors.green.shade400),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('更新持仓快照'),
                    onPressed: () => _showUpdateSnapshotDialog(context, ref, asset),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('计算失败: $err')),
    );
  }

  Widget _buildSnapshotHistory(BuildContext context, WidgetRef ref, Asset asset) {
     final asyncSnapshots = ref.watch(snapshotHistoryProvider(assetId));
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('持仓快照历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.edit_note), // 使用不同的图标
              tooltip: '管理历史快照',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SnapshotHistoryPage(assetId: asset.id),
                  ),
                );
              },
            ),
          ],
        ),
        const Divider(height: 20),
        asyncSnapshots.when(
          data: (snapshots) {
            if (snapshots.isEmpty) return const Card(child: ListTile(title: Text('暂无快照记录')));
            final latest = snapshots.first; 
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_toggle_off_outlined),
              title: Text('最新快照: 份额 ${latest.totalShares.toStringAsFixed(2)}'),
              subtitle: Text('成本: ${formatCurrency(latest.averageCost, asset.currency)}  日期: ${DateFormat('yyyy-MM-dd').format(latest.date)}'),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showUpdateSnapshotDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final sharesController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新持仓快照'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: sharesController, decoration: const InputDecoration(labelText: '最新总份额'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  TextField(controller: costController, decoration: const InputDecoration(labelText: '最新单位成本'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    final priceText = priceController.text.trim();

                    if (shares != null && cost != null) {
                      final isar = DatabaseService().isar;
                      
                      if (priceText.isNotEmpty) {
                        asset.latestPrice = double.tryParse(priceText) ?? asset.latestPrice;
                        asset.priceUpdateDate = DateTime.now();
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..asset.value = asset;
                      
                      await isar.writeTxn(() async {
                        await isar.assets.put(asset);
                        await isar.positionSnapshots.put(newSnapshot);
                        await newSnapshot.asset.save();
                      });

                      ref.invalidate(shareAssetPerformanceProvider(assetId));
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                         Navigator.of(context).pushReplacement( // 使用Replacement确保历史列表刷新
                          MaterialPageRoute(
                            builder: (_) => SnapshotHistoryPage(assetId: asset.id),
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
  
  void _showUpdatePriceDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('手动更新价格'),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '最新价格', prefixText: getCurrencySymbol(asset.currency)),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text);
                if (price != null) {
                  final isar = DatabaseService().isar;
                  asset.latestPrice = price;
                  asset.priceUpdateDate = DateTime.now();
                  await isar.writeTxn(() async => await isar.assets.put(asset));
                  ref.invalidate(shareAssetPerformanceProvider(assetId));

                  if(dialogContext.mounted) Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('保存'),
            )
          ],
        );
      },
    );
  }

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots, Asset asset) {
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
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(formatPrice(value, asset.currency, asset.subType.name), style: const TextStyle(fontSize: 10)))),
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
                  final value = formatPrice(spot.y, asset.currency, asset.subType.name);
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
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
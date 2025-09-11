import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';

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
  // 采用已被验证成功的 watchObject 模式
  return isar.assets.watchObject(assetId, fireImmediately: true).asyncMap((asset) async {
    if (asset != null) {
      // 当 Asset 变化时，重新加载其关联的快照列表
      await asset.snapshots.load();
      final snapshots = asset.snapshots.toList();
      // 手动排序，因为 backlinks 本身是无序的
      snapshots.sort((a, b) => b.date.compareTo(a.date));
      return snapshots;
    }
    return [];
  });
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
            icon: const Icon(Icons.price_change_outlined),
            tooltip: '手动更新价格',
            onPressed: () {
              final asset = asyncAsset.asData?.value;
              if (asset != null) {
                _showUpdatePriceDialog(context, ref, asset);
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
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    return asyncPerformance.when(
      data: (performance) {
        final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
        final profitRate = (performance['profitRate'] ?? 0.0) as double;
        final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
        final priceUpdateDate = asset.priceUpdateDate;
        Color profitColor = totalProfit > 0 ? Colors.red.shade400 : Colors.green.shade400;
        if (totalProfit == 0) profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(asset.code, style: TextStyle(color: Colors.grey.shade400)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('最新价: ${currencyFormat.format(performance['latestPrice'] ?? 0.0)}', style: TextStyle(color: Colors.grey.shade400)),
                        if(priceUpdateDate != null)
                          Text(DateFormat('yyyy-MM-dd').format(priceUpdateDate), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricRow(context, '当前市值:', currencyFormat.format(performance['marketValue'] ?? 0.0)),
                _buildMetricRow(context, '总成本:', currencyFormat.format(performance['totalCost'] ?? 0.0)),
                _buildMetricRow(context, '持有收益:', '${currencyFormat.format(totalProfit)} (${percentFormat.format(profitRate)})', color: profitColor),
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
        const Text('持仓快照历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 20),
        asyncSnapshots.when(
          data: (snapshots) {
            if(snapshots.isEmpty) return const Text('暂无快照历史');
            return Column(
              children: snapshots.map((snapshot) => ListTile(
                leading: const Icon(Icons.history_toggle_off_outlined),
                title: Text('份额: ${snapshot.totalShares.toStringAsFixed(2)}, 成本: ¥${snapshot.averageCost.toStringAsFixed(3)}'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(snapshot.date)),
              )).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('加载历史失败: $err')),
        )
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
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: '最新价格 (可选)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
                    final price = double.tryParse(priceController.text);

                    if (shares != null && cost != null) {
                      final isar = DatabaseService().isar;
                      
                      if (price != null) {
                        asset.latestPrice = price;
                        asset.priceUpdateDate = DateTime.now();
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..asset.value = asset;
                      
                      await isar.writeTxn(() async {
                        await isar.assets.put(asset); // Save asset to update price
                        await isar.positionSnapshots.put(newSnapshot);
                        await newSnapshot.asset.save();
                      });

                      ref.invalidate(shareAssetPerformanceProvider(assetId));
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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
            decoration: const InputDecoration(labelText: '最新价格', prefixText: '¥ '),
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart'; // 引入Transaction
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart';

final valueAssetDetailProvider = FutureProvider.autoDispose.family<Asset?, int>((ref, assetId) {
  final isar = DatabaseService().isar;
  return isar.assets.get(assetId);
});

// 新增：用于计算价值法资产性能的Provider
final valueAssetPerformanceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, assetId) async {
  final asset = await ref.watch(valueAssetDetailProvider(assetId).future);
  if (asset == null) throw '未找到资产';
  return CalculatorService().calculateValueAssetPerformance(asset);
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
      ),
      body: asyncPerformance.when(
        data: (performance) {
          final asset = asyncAsset.asData!.value!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildPerformanceCard(context, ref, asset, performance),
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
    if (totalProfit == 0) {
      profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

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
                // --- 激活这里的按钮 ---
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
    // 这个对话框与顶层账户的几乎完全一样，只是创建的是 Transaction 对象
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
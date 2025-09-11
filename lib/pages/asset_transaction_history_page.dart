import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart'; // 引入Provider
import 'package:one_five_one_ten/services/database_service.dart';

// Provider 用于获取某个资产的所有交易记录
final assetTransactionHistoryProvider =
    FutureProvider.autoDispose.family<List<Transaction>, int>((ref, assetId) async {
  final isar = DatabaseService().isar;
  final asset = await isar.assets.get(assetId);
  if (asset != null) {
    await asset.transactions.load();
    final transactions = asset.transactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }
  return [];
});

class AssetTransactionHistoryPage extends ConsumerWidget {
  final int assetId;
  const AssetTransactionHistoryPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(assetTransactionHistoryProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产更新记录'),
      ),
      body: historyAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('暂无记录'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return _buildTransactionTile(context, ref, txn);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildTransactionTile(
      BuildContext context, WidgetRef ref, Transaction txn) {
    String title;
    IconData icon;
    Color color;
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

    switch (txn.type) {
      case TransactionType.invest:
        title = '投入'; icon = Icons.add; color = Colors.red.shade400; break;
      case TransactionType.withdraw:
        title = '转出'; icon = Icons.remove; color = Colors.green.shade400; break;
      case TransactionType.updateValue:
        title = '当天资产金额'; icon = Icons.assessment; color = Theme.of(context).colorScheme.secondary; break;
      default:
        title = '其他'; icon = Icons.help_outline; color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(txn.date)),
        trailing: Text(currencyFormat.format(txn.amount), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        onLongPress: () => _showDeleteConfirmation(context, ref, txn),
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, Transaction txn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('您确定要删除这条记录吗？此操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final isar = DatabaseService().isar;
              await isar.writeTxn(() async => await isar.transactions.delete(txn.id));
              ref.invalidate(assetTransactionHistoryProvider(assetId));
              ref.invalidate(valueAssetPerformanceProvider(assetId));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
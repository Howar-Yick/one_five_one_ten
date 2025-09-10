import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/services/database_service.dart';
// --- 修正：添加这一行，以引入 accountPerformanceProvider ---
import 'package:one_five_one_ten/pages/account_detail_page.dart';

// Provider 用于获取某个账户的所有交易记录
final transactionHistoryProvider =
    FutureProvider.autoDispose.family<List<AccountTransaction>, int>((ref, accountId) async {
  final isar = DatabaseService().isar;
  final account = await isar.accounts.get(accountId);
  if (account != null) {
    await account.transactions.load();
    // 按日期降序排列
    final transactions = account.transactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }
  return [];
});

class TransactionHistoryPage extends ConsumerWidget {
  final int accountId;
  const TransactionHistoryPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transactionHistoryProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('更新记录'),
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
      BuildContext context, WidgetRef ref, AccountTransaction txn) {
    String title;
    IconData icon;
    Color color;
    final currencyFormat =
        NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

    switch (txn.type) {
      case TransactionType.invest:
        title = '投入';
        icon = Icons.add;
        color = Colors.red.shade400;
        break;
      case TransactionType.withdraw:
        title = '转出';
        icon = Icons.remove;
        color = Colors.green.shade400;
        break;
      case TransactionType.updateTotalValue:
        title = '当天资产金额';
        icon = Icons.assessment;
        color = Theme.of(context).colorScheme.secondary;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(txn.date)),
        trailing: Text(
          currencyFormat.format(txn.amount),
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          // TODO: 实现编辑功能
        },
        onLongPress: () => _showDeleteConfirmation(context, ref, txn),
      ),
    );
  }

  // 删除确认对话框
  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, AccountTransaction txn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('您确定要删除这条记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final isar = DatabaseService().isar;
              await isar.writeTxn(() async {
                await isar.accountTransactions.delete(txn.id);
              });
              // 刷新列表
              ref.invalidate(transactionHistoryProvider(accountId));
              // 刷新详情页的计算结果
              ref.invalidate(accountPerformanceProvider(accountId));
              if (context.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
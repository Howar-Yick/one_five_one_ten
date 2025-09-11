import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';
import 'package:one_five_one_ten/services/database_service.dart';

final transactionHistoryProvider =
    FutureProvider.autoDispose.family<List<AccountTransaction>, int>((ref, accountId) async {
  final isar = DatabaseService().isar;
  final account = await isar.accounts.get(accountId);
  if (account != null) {
    await account.transactions.load();
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
      case TransactionType.updateValue: // <-- 已修正
        title = '当天资产金额';
        icon = Icons.assessment;
        color = Theme.of(context).colorScheme.secondary;
        break;
      default:
        title = '未知';
        icon = Icons.question_mark;
        color = Colors.grey;
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
        onTap: () => _showEditTransactionDialog(context, ref, txn),
        onLongPress: () => _showDeleteConfirmation(context, ref, txn),
      ),
    );
  }
  
  void _showEditTransactionDialog(
      BuildContext context, WidgetRef ref, AccountTransaction txn) {
    final amountController = TextEditingController(text: txn.amount.toString());
    DateTime selectedDate = txn.date;
    final List<bool> isSelected = [
      txn.type == TransactionType.invest,
      txn.type == TransactionType.withdraw
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑记录'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (txn.type != TransactionType.updateValue) // <-- 已修正
                    ToggleButtons(
                      isSelected: isSelected,
                      onPressed: (index) {
                        setState(() {
                          isSelected[0] = index == 0;
                          isSelected[1] = index == 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('投入')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('转出')),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: txn.type == TransactionType.updateValue ? '总资产金额' : '金额', // <-- 已修正
                      prefixText: '¥ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontSize: 16)),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount >= 0) {
                      final isar = DatabaseService().isar;
                      txn.amount = amount;
                      txn.date = selectedDate;
                      if (txn.type != TransactionType.updateValue) { // <-- 已修正
                        txn.type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw;
                      }
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(txn);
                      });
                      ref.invalidate(transactionHistoryProvider(txn.account.value!.id));
                      ref.invalidate(accountPerformanceProvider(txn.account.value!.id));
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('保存修改'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
              ref.invalidate(transactionHistoryProvider(accountId));
              ref.invalidate(accountPerformanceProvider(accountId));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
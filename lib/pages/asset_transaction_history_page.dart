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
    // 同时监听 asset 和 history，因为按钮需要 asset 对象
    final asyncAsset = ref.watch(valueAssetDetailProvider(assetId));
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
      // --- 新增：悬浮操作按钮 ---
      floatingActionButton: asyncAsset.when(
        data: (asset) => asset == null ? const SizedBox.shrink() : PopupMenuButton(
          icon: const CircleAvatar(
            child: Icon(Icons.add),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'invest_withdraw',
              child: const Text('资金操作'),
              onTap: () => _showInvestWithdrawDialog(context, ref, asset),
            ),
            PopupMenuItem(
              value: 'update_value',
              child: const Text('更新总值'),
              onTap: () => _showUpdateValueDialog(context, ref, asset),
            ),
          ],
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
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
        // --- 激活点击事件 ---
        onTap: () => _showEditTransactionDialog(context, ref, txn),
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

  void _showInvestWithdrawDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
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
              content: /* ... 内容不变 ... */ Column(
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
                      
                      // --- 新增逻辑：跳转到历史记录页 ---
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssetTransactionHistoryPage(assetId: asset.id),
                        ),
                      );
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

  void _showUpdateValueDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
    final valueController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新资产总值'),
              content: /* ... 内容不变 ... */ Column(
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

                      // --- 新增逻辑：跳转到历史记录页 ---
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssetTransactionHistoryPage(assetId: asset.id),
                        ),
                      );
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

  void _showEditTransactionDialog(
      BuildContext context, WidgetRef ref, Transaction txn) {
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
                  if (txn.type != TransactionType.updateValue)
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
                      labelText: txn.type == TransactionType.updateValue ? '总资产金额' : '金额',
                      prefixText: '¥ ',
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      if (txn.type != TransactionType.updateValue) {
                        txn.type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw;
                      }
                      await isar.writeTxn(() async {
                        await isar.transactions.put(txn);
                      });
                      ref.invalidate(assetTransactionHistoryProvider(assetId));
                      ref.invalidate(valueAssetPerformanceProvider(assetId));
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
}
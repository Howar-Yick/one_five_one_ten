// 文件: lib/pages/transaction_history_page.dart
// (这是增加了“操作按钮行”的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:isar/isar.dart'; 

// 导入 Providers 和新服务
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

// 导入 Currency Formatter
import 'package:one_five_one_ten/utils/currency_formatter.dart';


// Provider 保持不变
final transactionHistoryProvider =
    StreamProvider.autoDispose.family<List<AccountTransaction>, int>((ref, accountId) async* { 
  
  final isar = DatabaseService().isar;
  final account = await isar.accounts.get(accountId);
  if (account == null || account.supabaseId == null) {
    yield [];
    return;
  }

  final accountSupabaseId = account.supabaseId!;

  final transactionStream = isar.accountTransactions
      .filter() 
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .sortByDateDesc() 
      .watch(fireImmediately: true);

  yield* transactionStream; 
});

class TransactionHistoryPage extends ConsumerWidget {
  final int accountId;
  const TransactionHistoryPage({super.key, required this.accountId});

  // --- (*** 这是替换后的新 build 方法 ***) ---
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. 我们仍然在顶部监听两个 provider
    final historyAsync = ref.watch(transactionHistoryProvider(accountId));
    final asyncAccount = ref.watch(accountDetailProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        // 2. AppBar 标题现在依赖账户名（如果加载成功）
        title: Text(asyncAccount.asData?.value?.name ?? '更新记录'),
      ),
      // 3. 关键修改：整个 body 现在依赖 asyncAccount 的状态
      body: asyncAccount.when(
        data: (account) {
          // 如果账户加载失败或为空
          if (account == null) {
            return const Center(child: Text('未找到账户。'));
          }

          // 账户加载成功，构建新布局
          return Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0), // 调整 Padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // --- 这是你要求新增的按钮区域 ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        // 4. 调用我们即将粘贴的辅助函数
                        onPressed: () => _showInvestWithdrawDialog(context, ref, account),
                        child: const Text('资金操作'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        // 5. 调用我们即将粘贴的辅助函数
                        onPressed: () => _showUpdateValueDialog(context, ref, account),
                        child: const Text('更新总值'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                // --- 按钮区域结束 ---

                Text('历史记录', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                // 6. 将原有的 historyAsync.when 嵌套在 Expanded 中
                Expanded(
                  child: historyAsync.when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return const Center(child: Text('暂无记录'));
                      }
                      return ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final txn = transactions[index];
                          // 7. 我们现在可以安全地使用 account.currency
                          final currencyCode = account.currency;
                          return _buildTransactionTile(context, ref, txn, currencyCode);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('加载失败: $err')),
                  ),
                ),
              ],
            ),
          );
        },
        // 账户本身加载时的状态
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载账户失败: $err')),
      ),
    );
  }
  // --- (*** build 方法替换结束 ***) ---


  // --- (以下是原有的辅助函数，保持不变) ---
  Widget _buildTransactionTile(
      BuildContext context, WidgetRef ref, AccountTransaction txn, String currencyCode) { 
    String title;
    IconData icon;
    Color color;
    final formattedAmount = formatCurrency(txn.amount, currencyCode);

    switch (txn.type) {
      case TransactionType.invest:
        title = '投入'; icon = Icons.add; color = Colors.red.shade400; break;
      case TransactionType.withdraw:
        title = '转出'; icon = Icons.remove; color = Colors.green.shade400; break;
      case TransactionType.updateValue:
        title = '当天资产金额'; icon = Icons.assessment; color = Theme.of(context).colorScheme.secondary; break;
      default:
        title = txn.type.name; icon = Icons.help_outline; color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6), // 调整 margin 适应新 padding
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(txn.date)),
        trailing: Text(formattedAmount, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)), // 使用 formattedAmount
        onTap: () => _showEditTransactionDialog(context, ref, txn, currencyCode), 
        onLongPress: () => _showDeleteConfirmation(context, ref, txn),
      ),
    );
  }
  
  void _showEditTransactionDialog(
      BuildContext context, WidgetRef ref, AccountTransaction txn, String currencyCode) { 
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
                      prefixText: getCurrencySymbol(currencyCode), 
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

                      txn.amount = amount;
                      txn.date = selectedDate;
                      if (txn.type != TransactionType.updateValue) { 
                        txn.type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw;
                      }

                      await ref.read(syncServiceProvider).saveAccountTransaction(txn);

                      ref.invalidate(accountPerformanceProvider(accountId));
                      
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
              await ref.read(syncServiceProvider).deleteAccountTransaction(txn);

              ref.invalidate(accountPerformanceProvider(accountId));
              
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- (*** 新增：从 account_detail_page 复制而来的辅助函数 ***) ---

  void _showInvestWithdrawDialog(
      BuildContext context, WidgetRef ref, Account account) {
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
                    onPressed: (index) {
                      setState(() {
                        isSelected[0] = index == 0;
                        isSelected[1] = index == 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('投入')),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('转出')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: '金额', prefixText: getCurrencySymbol(account.currency))),
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
                            setState(() {
                              selectedDate = pickedDate;
                            });
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
                    child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    try {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入有效的金额')),
                        );
                        return;
                      }

                      final syncService = ref.read(syncServiceProvider);
                      
                      final newTxn = AccountTransaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now() 
                        ..type = isSelected[0]
                            ? TransactionType.invest
                            : TransactionType.withdraw
                        ..accountSupabaseId = account.supabaseId; 

                      final isar = DatabaseService().isar; 
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                      });

                      await syncService.saveAccountTransaction(newTxn);

                      ref.invalidate(accountPerformanceProvider(account.id)); 
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        // (留在当前页，因为Stream会自动刷新，无需跳转)
                      }
                    } catch (e) {
                      print('资金操作失败: $e');
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('操作失败: $e')),
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

  void _showUpdateValueDialog(
      BuildContext context, WidgetRef ref, Account account) {
    final valueController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新账户总值'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: valueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: '当前总资产价值', prefixText: getCurrencySymbol(account.currency))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
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
                    child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                       try {
                        final value = double.tryParse(valueController.text);
                        if (value == null) { // 允许 0
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入有效的价值')),
                          );
                          return;
                        }

                        final syncService = ref.read(syncServiceProvider);

                        final newTxn = AccountTransaction()
                          ..amount = value
                          ..date = selectedDate
                          ..createdAt = DateTime.now() 
                          ..type = TransactionType.updateValue
                          ..accountSupabaseId = account.supabaseId; 
                        
                        final isar = DatabaseService().isar;
                         await isar.writeTxn(() async {
                          await isar.accountTransactions.put(newTxn);
                        });

                        await syncService.saveAccountTransaction(newTxn);
                        
                        ref.invalidate(accountPerformanceProvider(account.id));
                        ref.invalidate(dashboardDataProvider);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                           // (留在当前页，因为Stream会自动刷新，无需跳转)
                        }
                      } catch (e) {
                        print('更新总值失败: $e');
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('操作失败: $e')),
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
  // --- (*** 新增函数结束 ***) ---

}
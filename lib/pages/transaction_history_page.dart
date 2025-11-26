// 文件: lib/pages/transaction_history_page.dart
// (这是已移除 Provider 并修复了所有错误的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/transaction.dart';
// import 'package:one_five_one_ten/pages/account_detail_page.dart'; // (不再需要)
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:isar/isar.dart'; 

import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';

// (*** 关键修复：Provider 已被【移除】并转移到 global_providers.dart ***)


class TransactionHistoryPage extends ConsumerWidget {
  final int accountId;
  const TransactionHistoryPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // (*** 修复：现在 watch 全局的 Provider ***)
    final historyAsync = ref.watch(transactionHistoryProvider(accountId));
    final asyncAccount = ref.watch(accountDetailProvider(accountId));

    return Scaffold(
      // (*** 修复：AppBar 依赖 asyncAccount ***)
      appBar: AppBar(
        title: Text(asyncAccount.asData?.value?.name ?? '更新记录'),
        actions: [
          asyncAccount.maybeWhen(
            data: (account) => account != null && account.currency != 'CNY'
                ? IconButton(
                    icon: const Icon(Icons.currency_exchange_outlined),
                    tooltip: '补录缺失汇率',
                    onPressed: () =>
                        _backfillMissingFxRates(context, ref, account),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      // (*** 修复：body 依赖 asyncAccount ***)
      body: asyncAccount.when(
        data: (account) {
          if (account == null) {
            return const Center(child: Text('未找到账户。'));
          }
          
          // (*** 原始 body 内容现在嵌套在 asyncAccount.when 中 ***)
          return Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showInvestWithdrawDialog(context, ref, account),
                        child: const Text('资金操作'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showUpdateValueDialog(context, ref, account),
                        child: const Text('更新总值'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                Text('历史记录', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
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
          // (*** 嵌套结束 ***)

        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载账户失败: $err')),
      ),
    );
  }

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
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6), // (调整 margin)
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(txn.date)),
        trailing: Text(formattedAmount, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        onTap: () => _showEditTransactionDialog(context, ref, txn, currencyCode, accountId), // (*** 修复：传入 accountId ***)
        onLongPress: () => _showDeleteConfirmation(context, ref, txn, accountId), // (*** 修复：传入 accountId ***)
      ),
    );
  }
  
  // (*** 关键修复：编辑和删除函数现在需要 accountId 来刷新 provider ***)
  void _showEditTransactionDialog(
      BuildContext context, WidgetRef ref, AccountTransaction txn, String currencyCode, int accountId) {
    final amountController = TextEditingController(text: txn.amount.toString());
    final fxRateController =
        TextEditingController(text: txn.fxRateToCny?.toStringAsFixed(4) ?? '');
    final cnyAmountController =
        TextEditingController(text: txn.baseAmountCny?.toStringAsFixed(2) ?? '');
    DateTime selectedDate = txn.date;
    final List<bool> isSelected = [
      txn.type == TransactionType.invest,
      txn.type == TransactionType.withdraw
    ];
    bool rateRequested = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (currencyCode != 'CNY' && !rateRequested) {
              rateRequested = true;
              if (fxRateController.text.isEmpty) {
                ExchangeRateService()
                    .getRate(currencyCode, 'CNY')
                    .then((rate) {
                  if (dialogContext.mounted && fxRateController.text.isEmpty) {
                    setState(() {
                      fxRateController.text = rate.toStringAsFixed(4);
                    });
                  }
                });
              }
            }
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
                  if (txn.type != TransactionType.updateValue && currencyCode != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '汇率（本币→CNY，可选）',
                        helperText: '空白则自动按金额推算',
                      ),
                      onChanged: (_) {
                        final amount = double.tryParse(amountController.text);
                        final rate = double.tryParse(fxRateController.text);
                        if (amount != null && rate != null) {
                          cnyAmountController.text = (amount * rate).toStringAsFixed(2);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnyAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '折算人民币金额（可选）',
                      ),
                    ),
                  ],
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

                      if (txn.type != TransactionType.updateValue && currencyCode != 'CNY') {
                        double? fxRate = double.tryParse(fxRateController.text);
                        double? baseCnyAmount = double.tryParse(cnyAmountController.text);
                        if (fxRate == null && baseCnyAmount != null && amount > 0) {
                          fxRate = baseCnyAmount / amount;
                        }
                        if (baseCnyAmount == null && fxRate != null) {
                          baseCnyAmount = amount * fxRate;
                        }
                        txn.fxRateToCny = fxRate;
                        txn.baseAmountCny = baseCnyAmount;
                      }

                      await ref.read(syncServiceProvider).saveAccountTransaction(txn);

                      // (*** 修复：使用传入的 accountId 刷新 ***)
                      ref.invalidate(accountPerformanceProvider(accountId));
                      ref.invalidate(dashboardDataProvider); // (刷新首页)
                      
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
      BuildContext context, WidgetRef ref, AccountTransaction txn, int accountId) { // (*** 修复：传入 accountId ***)
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
              
              // (*** 修复：使用传入的 accountId 刷新 ***)
              ref.invalidate(accountPerformanceProvider(accountId));
              ref.invalidate(dashboardDataProvider); // (刷新首页)
              
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- (*** 新增：从 account_detail_page 复制而来的辅助函数 ***) ---
  // (*** 它们现在由这个页面（历史页）直接使用 ***)

  void _showInvestWithdrawDialog(
      BuildContext context, WidgetRef ref, Account account) {
    final amountController = TextEditingController();
    final fxRateController = TextEditingController();
    final cnyAmountController = TextEditingController();
    final List<bool> isSelected = [true, false];
    DateTime selectedDate = DateTime.now();
    bool rateRequested = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (account.currency != 'CNY' && !rateRequested) {
              rateRequested = true;
              ExchangeRateService()
                  .getRate(account.currency, 'CNY')
                  .then((rate) {
                if (fxRateController.text.isEmpty && dialogContext.mounted) {
                  setState(() {
                    fxRateController.text = rate.toStringAsFixed(4);
                  });
                }
              });
            }
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
                  if (account.currency != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '汇率（本币→CNY，可选）',
                        helperText: '默认自动拉取，留空则按金额自动计算',
                      ),
                      onChanged: (_) {
                        final amount = double.tryParse(amountController.text);
                        final rate = double.tryParse(fxRateController.text);
                        if (amount != null && rate != null) {
                          cnyAmountController.text = (amount * rate).toStringAsFixed(2);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnyAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '折算人民币金额（可选）',
                        helperText: '填写后可直接用于汇率盈亏拆分',
                      ),
                    ),
                  ],
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

                      double? fxRate;
                      double? baseCnyAmount;
                      if (account.currency != 'CNY') {
                        fxRate = double.tryParse(fxRateController.text);
                        baseCnyAmount = double.tryParse(cnyAmountController.text);
                        if (fxRate == null && baseCnyAmount != null && amount > 0) {
                          fxRate = baseCnyAmount / amount;
                        }
                        if (baseCnyAmount == null && fxRate != null) {
                          baseCnyAmount = amount * fxRate;
                        }
                      }

                      final syncService = ref.read(syncServiceProvider);

                      final newTxn = AccountTransaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..type = isSelected[0]
                            ? TransactionType.invest
                            : TransactionType.withdraw
                        ..accountSupabaseId = account.supabaseId
                        ..fxRateToCny = fxRate
                        ..baseAmountCny = baseCnyAmount;

                      final isar = DatabaseService().isar; 
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                      });

                      await syncService.saveAccountTransaction(newTxn);

                      // (*** 修复：使用 account.id 刷新 ***)
                      ref.invalidate(accountPerformanceProvider(account.id)); 
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        // (留在当前页，Stream 会自动刷新)
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
                        if (value == null) { 
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
                        
                        // (*** 修复：使用 account.id 刷新 ***)
                        ref.invalidate(accountPerformanceProvider(account.id));
                        ref.invalidate(dashboardDataProvider);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          // (留在当前页，Stream 会自动刷新)
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

  Future<void> _backfillMissingFxRates(
      BuildContext context, WidgetRef ref, Account account) async {
    if (account.currency == 'CNY') return;
    final supabaseId = account.supabaseId;
    if (supabaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户尚未完成同步，无法补录汇率')),
      );
      return;
    }

    final isar = DatabaseService().isar;
    final missingTxns = await isar.accountTransactions
        .where()
        .accountSupabaseIdEqualTo(supabaseId)
        .filter()
        .group((q) => q.typeEqualTo(TransactionType.invest).or().typeEqualTo(TransactionType.withdraw))
        .and()
        .group((q) => q.fxRateToCnyIsNull().or().baseAmountCnyIsNull())
        .findAll();

    if (missingTxns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有需要补录汇率的记录')),
      );
      return;
    }

    final rate = await ExchangeRateService().getRate(account.currency, 'CNY');
    final syncService = ref.read(syncServiceProvider);
    for (final txn in missingTxns) {
      txn.fxRateToCny ??= rate;
      txn.baseAmountCny ??= txn.amount * (txn.fxRateToCny ?? rate);
      await syncService.saveAccountTransaction(txn);
    }

    ref.invalidate(accountPerformanceProvider(account.id));
    ref.invalidate(dashboardDataProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已补录 ${missingTxns.length} 条交易的汇率')),
    );
  }
  // --- (*** 新增函数结束 ***) ---

}
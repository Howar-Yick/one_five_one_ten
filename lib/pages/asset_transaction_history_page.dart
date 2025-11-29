// 文件: lib/pages/asset_transaction_history_page.dart
// (这是完整、已修复的文件代码)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart'; // 引入Provider
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:isar/isar.dart'; 
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';


// (Provider 逻辑已正确)
final assetTransactionHistoryProvider =
    StreamProvider.autoDispose.family<List<Transaction>, int>((ref, assetId) async* { 
  
  final isar = DatabaseService().isar;
  final asset = await isar.assets.get(assetId);
  if (asset == null || asset.supabaseId == null) {
    yield [];
    return;
  }

  final assetSupabaseId = asset.supabaseId!;

  final transactionStream = isar.transactions
      .where()
      .assetSupabaseIdEqualTo(assetSupabaseId)
      .sortByDateDesc() // 按日期降序排序
      .watch(fireImmediately: true);

  yield* transactionStream; 
});

class AssetTransactionHistoryPage extends ConsumerWidget {
  final int assetId;
  const AssetTransactionHistoryPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              final currencyCode = asyncAsset.asData?.value?.currency ?? 'CNY';
              return _buildTransactionTile(context, ref, txn, currencyCode);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      // --- 悬浮操作按钮 ---
      floatingActionButton: asyncAsset.when(
        data: (asset) => asset == null ? const SizedBox.shrink() : PopupMenuButton(
          icon: const CircleAvatar(
            child: Icon(Icons.add),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'invest_withdraw',
              child: const Text('资金操作'),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showInvestWithdrawDialog(context, ref, asset);
                });
              }
            ),
            PopupMenuItem(
              value: 'update_value',
              child: const Text('更新总值'),
              onTap: () {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showUpdateValueDialog(context, ref, asset);
                 });
              }
            ),
          ],
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTransactionTile(
      BuildContext context, WidgetRef ref, Transaction txn, String currencyCode) { 
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

    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall;
    final showFxRate =
        currencyCode != 'CNY' && (txn.fxRateToCny != null && txn.fxRateToCny! > 0);
    final showAmountCny = currencyCode != 'CNY' && txn.amountCny != null;

    final List<Widget> subtitleLines = [
      Text(DateFormat('yyyy-MM-dd').format(txn.date), style: subtitleStyle),
    ];

    if (showFxRate) {
      subtitleLines.add(
        Text(
          '汇率: ${txn.fxRateToCny!.toStringAsFixed(4)} ($currencyCode→CNY)',
          style: subtitleStyle,
        ),
      );
    }
    if (showAmountCny) {
      subtitleLines.add(
        Text(
          '折算人民币金额: ${formatCurrency(txn.amountCny!, 'CNY')}',
          style: subtitleStyle,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitleLines,
        ),
        trailing: Text(formattedAmount, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        onTap: () => _showEditTransactionDialog(context, ref, txn, currencyCode),
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
              try {
                final syncService = ref.read(syncServiceProvider);
                await syncService.deleteTransaction(txn);
                
                ref.invalidate(valueAssetPerformanceProvider(assetId)); 
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                 print("删除失败: $e");
                 if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                       SnackBar(content: Text('删除失败: $e')),
                    );
                 }
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // (*** 这是修复后的 _showInvestWithdrawDialog ***)
  void _showInvestWithdrawDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
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
            if (asset.currency != 'CNY' && !rateRequested) {
              rateRequested = true;
              ExchangeRateService()
                  .getRate(asset.currency, 'CNY')
                  .then((rate) {
                if (dialogContext.mounted && fxRateController.text.isEmpty) {
                  setState(() {
                    fxRateController.text = rate.toStringAsFixed(4);
                    final amount = double.tryParse(amountController.text);
                    if (amount != null) {
                      cnyAmountController.text =
                          (amount * rate).toStringAsFixed(2);
                    }
                  });
                }
              });
            }
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
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '金额', prefixText: getCurrencySymbol(asset.currency))),
                  if (asset.currency != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '汇率（资产币种→CNY，可选）',
                        helperText: '留空将尝试自动拉取或按金额推算',
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
                        helperText: '填写后便于汇率盈亏拆分',
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
                  // (*** 这是修复后的 onPressed ***)
                  onPressed: () async {
                    try {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                           if (dialogContext.mounted) {
                             ScaffoldMessenger.of(dialogContext).showSnackBar(
                               const SnackBar(content: Text('请输入有效金额')),
                             );
                           }
                           return;
                      }

                      final syncService = ref.read(syncServiceProvider);

                      double? fxRate;
                      double? amountCny;
                      if (asset.currency != 'CNY') {
                        fxRate = double.tryParse(fxRateController.text);
                        amountCny = double.tryParse(cnyAmountController.text);
                        if (fxRate == null && amountCny != null && amount > 0) {
                          fxRate = amountCny / amount;
                        }
                        if (amountCny == null && fxRate != null) {
                          amountCny = amount * fxRate;
                        }
                      }

                      // 1. 创建新对象
                      final newTxn = Transaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw
                        ..assetSupabaseId = asset.supabaseId
                        ..fxRateToCny = fxRate
                        ..amountCny = amountCny;
                      
                      // 2. (!!! 关键修复：先在本地写入以获取 Isar ID !!!)
                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                      });
                      // (newTxn.id 现在有效了)

                      // 3. (!!! 然后再同步这个带有 ID 的对象 !!!)
                      await syncService.saveTransaction(newTxn); 
                      
                      // 4. 刷新 (Invalidate 会强制 Provider 重新计算)
                      ref.invalidate(valueAssetPerformanceProvider(asset.id));
                      // (assetTransactionHistoryProvider 是 Stream，会自动更新)

                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();

                    } catch (e) {
                      // (捕获所有错误)
                      print("保存资金操作失败: $e");
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

  // (*** 这是修复后的 _showUpdateValueDialog ***)
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
                  // (*** 这是修复后的 onPressed ***)
                  onPressed: () async {
                    try {
                      final value = double.tryParse(valueController.text);
                      if (value == null) { // 允许 0
                           if (dialogContext.mounted) {
                             ScaffoldMessenger.of(dialogContext).showSnackBar(
                               const SnackBar(content: Text('请输入有效价值')),
                             );
                           }
                           return;
                      }

                      final syncService = ref.read(syncServiceProvider); 
                      
                      // 1. 创建对象
                      final newTxn = Transaction()
                        ..amount = value
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..type = TransactionType.updateValue
                        ..assetSupabaseId = asset.supabaseId;
                      
                      // 2. (!!! 关键修复：先本地写入 !!!)
                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                         await isar.transactions.put(newTxn);
                      });

                      // 3. (!!! 再同步 !!!)
                      await syncService.saveTransaction(newTxn); 
                      
                      // 4. 刷新
                      ref.invalidate(valueAssetPerformanceProvider(asset.id));
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();

                    } catch (e) {
                      // (捕获所有错误)
                       print("更新总值失败: $e");
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

  // (*** 这是修复后的 _showEditTransactionDialog ***)
  void _showEditTransactionDialog(
      BuildContext context, WidgetRef ref, Transaction txn, String currencyCode) {
    final amountController = TextEditingController(text: txn.amount.toString());
    final fxRateController =
        TextEditingController(text: txn.fxRateToCny?.toStringAsFixed(4) ?? '');
    final cnyAmountController =
        TextEditingController(text: txn.amountCny?.toStringAsFixed(2) ?? '');
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
                  if (txn.type != TransactionType.updateValue && currencyCode != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '汇率（资产币种→CNY，可选）',
                        helperText: '留空将尝试自动推算',
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
                    // (*** 这是修复后的更新逻辑 ***)
                    try {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount < 0) { // 允许 0
                         if (dialogContext.mounted) {
                           ScaffoldMessenger.of(dialogContext).showSnackBar(
                             const SnackBar(content: Text('请输入有效金额')),
                           );
                         }
                         return;
                      }
                      
                      // 1. 更新本地对象 (txn 是从 Isar 读出的，它已经有 ID)
                      txn.amount = amount;
                      txn.date = selectedDate;
                      if (txn.type != TransactionType.updateValue) {
                        txn.type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw;
                        if (currencyCode != 'CNY') {
                          double? fxRate = double.tryParse(fxRateController.text);
                          double? amountCny = double.tryParse(cnyAmountController.text);
                          if (fxRate == null && amountCny != null && amount > 0) {
                            fxRate = amountCny / amount;
                          }
                          if (amountCny == null && fxRate != null) {
                            amountCny = amount * fxRate;
                          }
                          txn.fxRateToCny = fxRate;
                          txn.amountCny = amountCny;
                        } else {
                          txn.fxRateToCny = null;
                          txn.amountCny = null;
                        }
                      }
                      
                      // 2. 使用 SyncService 保存 (它已经有 Isar ID, 所以不需要本地保存)
                      await ref.read(syncServiceProvider).saveTransaction(txn);

                      // 3. 刷新计算
                      ref.invalidate(valueAssetPerformanceProvider(assetId));
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    
                    } catch (e) {
                      // (捕获所有错误)
                       print("编辑保存失败: $e");
                       if (dialogContext.mounted) {
                         ScaffoldMessenger.of(dialogContext).showSnackBar(
                           SnackBar(content: Text('操作失败: $e')),
                         );
                       }
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
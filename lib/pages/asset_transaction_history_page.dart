import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

/// 某个资产的交易 / 资产更新记录流
final assetTransactionHistoryProvider =
    StreamProvider.autoDispose.family<List<Transaction>, int>(
  (ref, assetId) async* {
    final isar = DatabaseService().isar;
    final asset = await isar.assets.get(assetId);

    if (asset == null || asset.supabaseId == null) {
      yield const <Transaction>[];
      return;
    }

    final assetSupabaseId = asset.supabaseId!;

    final txStream = isar.transactions
        .where()
        .assetSupabaseIdEqualTo(assetSupabaseId)
        .sortByDateDesc()
        .watch(fireImmediately: true);

    yield* txStream;
  },
);

class AssetTransactionHistoryPage extends ConsumerWidget {
  const AssetTransactionHistoryPage({
    super.key,
    required this.assetId,
  });

  final int assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetAsync = ref.watch(valueAssetDetailProvider(assetId));
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

          final currencyCode =
              assetAsync.asData?.value?.currency ?? 'CNY';

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return _buildTransactionTile(
                context,
                ref,
                txn,
                currencyCode,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: assetAsync.when(
        data: (asset) {
          if (asset == null) return const SizedBox.shrink();

          return PopupMenuButton<String>(
            icon: const CircleAvatar(
              child: Icon(Icons.add),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'invest_withdraw',
                child: const Text('资金操作'),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showInvestWithdrawDialog(context, ref, asset);
                  });
                },
              ),
              PopupMenuItem<String>(
                value: 'update_value',
                child: const Text('更新总值'),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showUpdateValueDialog(context, ref, asset);
                  });
                },
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  /// 单条记录的卡片
  Widget _buildTransactionTile(
    BuildContext context,
    WidgetRef ref,
    Transaction txn,
    String currencyCode,
  ) {
    String title;
    IconData icon;
    Color color;

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
      case TransactionType.updateValue:
        title = '当天资产金额';
        icon = Icons.assessment;
        color = Theme.of(context).colorScheme.secondary;
        break;
      default:
        title = txn.type.name;
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    final formattedAmount =
        formatCurrency(txn.amount, currencyCode);

    final subtitleLines = <Widget>[
      Text(DateFormat('yyyy-MM-dd').format(txn.date)),
    ];

    // === 汇率 & 折算人民币金额的展示 ===
    if (currencyCode != 'CNY' && txn.fxRateToCny != null) {
      subtitleLines.add(
        Text(
          '汇率: ${txn.fxRateToCny!.toStringAsFixed(4)} ($currencyCode→CNY)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    if (currencyCode != 'CNY' && txn.amountCny != null) {
      subtitleLines.add(
        Text(
          '折算人民币金额: '
          '${formatCurrency(txn.amountCny!, 'CNY')}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    // ==============================

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitleLines,
        ),
        trailing: Text(
          formattedAmount,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () =>
            _showEditTransactionDialog(context, ref, txn, currencyCode),
        onLongPress: () =>
            _showDeleteConfirmation(context, ref, txn),
      ),
    );
  }

  // ================= 删除 =================

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Transaction txn,
  ) {
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
              try {
                final syncService = ref.read(syncServiceProvider);
                await syncService.deleteTransaction(txn);

                ref.invalidate(
                  valueAssetPerformanceProvider(assetId),
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                debugPrint('删除失败: $e');
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 新增资金操作 =================

  void _showInvestWithdrawDialog(
    BuildContext context,
    WidgetRef ref,
    Asset asset,
  ) {
    final amountController = TextEditingController();
    final fxRateController = TextEditingController();
    final cnyAmountController = TextEditingController();
    final isSelected = <bool>[true, false];
    DateTime selectedDate = DateTime.now();
    bool rateRequested = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 非 CNY 资产，首次尝试自动拉取汇率
            if (asset.currency != 'CNY' && !rateRequested) {
              rateRequested = true;
              ExchangeRateService()
                  .getRate(asset.currency, 'CNY')
                  .then((rate) {
                if (!dialogContext.mounted) return;
                if (fxRateController.text.isNotEmpty) return;

                setState(() {
                  fxRateController.text = rate.toStringAsFixed(4);
                  final amount =
                      double.tryParse(amountController.text);
                  if (amount != null) {
                    cnyAmountController.text =
                        (amount * rate).toStringAsFixed(2);
                  }
                });
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
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('投入'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('转出'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '金额',
                      prefixText: getCurrencySymbol(asset.currency),
                    ),
                  ),
                  if (asset.currency != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '汇率（资产币种→CNY，可选）',
                        helperText: '留空将尝试自动拉取或按金额推算',
                      ),
                      onChanged: (_) {
                        final amount =
                            double.tryParse(amountController.text);
                        final rate =
                            double.tryParse(fxRateController.text);
                        if (amount != null && rate != null) {
                          cnyAmountController.text =
                              (amount * rate).toStringAsFixed(2);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnyAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '折算人民币金额（可选）',
                        helperText: '填写后便于汇率盈亏拆分',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        '日期:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() => selectedDate = pickedDate);
                          }
                        },
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final amount =
                          double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('请输入有效金额')),
                          );
                        }
                        return;
                      }

                      final isInvest = isSelected[0];

                      double? fxRate;
                      double? amountCny;
                      if (asset.currency != 'CNY') {
                        fxRate =
                            double.tryParse(fxRateController.text);
                        amountCny =
                            double.tryParse(cnyAmountController.text);

                        if (fxRate == null &&
                            amountCny != null &&
                            amount > 0) {
                          fxRate = amountCny / amount;
                        }
                        if (amountCny == null && fxRate != null) {
                          amountCny = amount * fxRate;
                        }
                      }

                      final newTxn = Transaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..type = isInvest
                            ? TransactionType.invest
                            : TransactionType.withdraw
                        ..assetSupabaseId = asset.supabaseId
                        ..fxRateToCny = fxRate
                        ..amountCny = amountCny;

                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                      });

                      await ref
                          .read(syncServiceProvider)
                          .saveTransaction(newTxn);

                      ref.invalidate(
                        valueAssetPerformanceProvider(asset.id),
                      );

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      debugPrint('保存资金操作失败: $e');
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

  // ================= 更新总值 =================

  void _showUpdateValueDialog(
    BuildContext context,
    WidgetRef ref,
    Asset asset,
  ) {
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
                  TextField(
                    controller: valueController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '当前资产总价值',
                      prefixText: getCurrencySymbol(asset.currency),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        '日期:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() => selectedDate = pickedDate);
                          }
                        },
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final value =
                          double.tryParse(valueController.text);
                      if (value == null) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('请输入有效价值')),
                          );
                        }
                        return;
                      }

                      final newTxn = Transaction()
                        ..amount = value
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..type = TransactionType.updateValue
                        ..assetSupabaseId = asset.supabaseId;

                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                      });

                      await ref
                          .read(syncServiceProvider)
                          .saveTransaction(newTxn);

                      ref.invalidate(
                        valueAssetPerformanceProvider(asset.id),
                      );

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      debugPrint('更新总值失败: $e');
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

  // ================= 编辑记录 =================

  void _showEditTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    Transaction txn,
    String currencyCode,
  ) {
    final amountController =
        TextEditingController(text: txn.amount.toString());
    final fxRateController = TextEditingController(
      text: txn.fxRateToCny?.toStringAsFixed(4) ?? '',
    );
    final cnyAmountController = TextEditingController(
      text: txn.amountCny?.toStringAsFixed(2) ?? '',
    );

    DateTime selectedDate = txn.date;

    final isSelected = <bool>[
      txn.type == TransactionType.invest,
      txn.type == TransactionType.withdraw,
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
                      borderRadius: BorderRadius.circular(8),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('投入'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('转出'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: txn.type == TransactionType.updateValue
                          ? '总资产金额'
                          : '金额',
                      prefixText: getCurrencySymbol(currencyCode),
                    ),
                  ),
                  if (txn.type != TransactionType.updateValue &&
                      currencyCode != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '汇率（资产币种→CNY，可选）',
                        helperText: '留空将尝试自动推算',
                      ),
                      onChanged: (_) {
                        final amount =
                            double.tryParse(amountController.text);
                        final rate =
                            double.tryParse(fxRateController.text);
                        if (amount != null && rate != null) {
                          cnyAmountController.text =
                              (amount * rate).toStringAsFixed(2);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnyAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '折算人民币金额（可选）',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        '日期:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() => selectedDate = pickedDate);
                          }
                        },
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final amount =
                          double.tryParse(amountController.text);
                      if (amount == null || amount < 0) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('请输入有效金额')),
                          );
                        }
                        return;
                      }

                      txn.amount = amount;
                      txn.date = selectedDate;

                      if (txn.type != TransactionType.updateValue) {
                        txn.type = isSelected[0]
                            ? TransactionType.invest
                            : TransactionType.withdraw;

                        if (currencyCode != 'CNY') {
                          double? fxRate =
                              double.tryParse(fxRateController.text);
                          double? amountCny =
                              double.tryParse(cnyAmountController.text);

                          if (fxRate == null &&
                              amountCny != null &&
                              amount > 0) {
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

                      await ref
                          .read(syncServiceProvider)
                          .saveTransaction(txn);

                      ref.invalidate(
                        valueAssetPerformanceProvider(assetId),
                      );

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      debugPrint('编辑保存失败: $e');
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

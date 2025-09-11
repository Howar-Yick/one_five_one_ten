import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/transaction_history_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';

final accountDetailProvider =
    FutureProvider.autoDispose.family<Account?, int>((ref, accountId) {
  final isar = DatabaseService().isar;
  return isar.accounts.get(accountId);
});

final accountPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, accountId) async {
  final account = await ref.watch(accountDetailProvider(accountId).future);
  if (account == null) {
    throw '未找到账户';
  }
  return CalculatorService().calculateAccountPerformance(account);
});

final trackedAssetsProvider =
    StreamProvider.autoDispose.family<List<Asset>, int>((ref, accountId) {
  final isar = DatabaseService().isar;
  return isar.accounts
      .watchObject(accountId, fireImmediately: true)
      .asyncMap((account) async {
    if (account != null) {
      await account.trackedAssets.load();
      return account.trackedAssets.toList();
    }
    return [];
  });
});

class AccountDetailPage extends ConsumerWidget {
  final int accountId;
  const AccountDetailPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccount = ref.watch(accountDetailProvider(accountId));
    final asyncPerformance = ref.watch(accountPerformanceProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: Text(asyncAccount.asData?.value?.name ?? '加载中...'),
      ),
      body: asyncPerformance.when(
        data: (performance) {
          if (asyncAccount.asData?.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final account = asyncAccount.asData!.value!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildMacroView(context, ref, account, performance),
              const SizedBox(height: 24),
              _buildMicroView(context, ref, accountId),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('发生错误: $err')),
      ),
    );
  }

  Widget _buildMacroView(BuildContext context, WidgetRef ref, Account account,
      Map<String, dynamic> performance) {
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final profitRate = (performance['profitRate'] ?? 0.0) as double;
    final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    Color profitColor =
        totalProfit > 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor =
          Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
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
                const Text('账户概览',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '查看更新记录',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TransactionHistoryPage(accountId: account.id),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            _buildMetricRow(
              context,
              '当前总值:',
              currencyFormat.format(performance['currentValue'] ?? 0.0),
            ),
            _buildMetricRow(
              context,
              '净投入:',
              currencyFormat.format(performance['netInvestment'] ?? 0.0),
            ),
            _buildMetricRow(
              context,
              '总收益:',
              '${currencyFormat.format(totalProfit)} (${percentFormat.format(profitRate)})',
              color: profitColor,
            ),
            _buildMetricRow(
              context,
              '年化收益率:',
              percentFormat.format(annualizedReturn),
              color: annualizedReturn > 0
                  ? Colors.red.shade400
                  : Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                    onPressed: () {
                      _showInvestWithdrawDialog(context, ref, account);
                    },
                    child: const Text('资金操作')),
                ElevatedButton(
                    onPressed: () {
                      _showUpdateValueDialog(context, ref, account);
                    },
                    child: const Text('更新总值')),
              ],
            )
          ],
        ),
      ),
    );
  }

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
                      decoration: const InputDecoration(
                          labelText: '金额', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate),
                            style: const TextStyle(fontSize: 16)),
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
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      final isar = DatabaseService().isar;
                      final newTxn = AccountTransaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..type = isSelected[0]
                            ? TransactionType.invest
                            : TransactionType.withdraw
                        ..account.value = account;
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                        await newTxn.account.save();
                      });
                      ref.invalidate(accountPerformanceProvider(account.id));
                      if (dialogContext.mounted)
                        Navigator.of(dialogContext).pop();
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
                  TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '当前总资产价值', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
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
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final value = double.tryParse(valueController.text);
                    if (value != null) {
                      final isar = DatabaseService().isar;
                      final newTxn = AccountTransaction()
                        ..amount = value
                        ..date = selectedDate
                        ..type = TransactionType.updateValue // <-- 修正：updateTotalValue -> updateValue
                        ..account.value = account;
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                        await newTxn.account.save();
                      });
                      ref.invalidate(accountPerformanceProvider(account.id));
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

  Widget _buildMicroView(BuildContext context, WidgetRef ref, int accountId) {
    final asyncAssets = ref.watch(trackedAssetsProvider(accountId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('持仓资产',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '添加持仓资产',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddEditAssetPage(accountId: accountId),
                  ),
                );
              },
            ),
          ],
        ),
        const Divider(height: 20),
        asyncAssets.when(
          data: (assets) {
            if (assets.isEmpty) {
              return const Card(child: ListTile(title: Text('暂无持仓资产')));
            }
            return Column(
              children: assets.map((asset) => _buildAssetCard(context, ref, asset)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('加载资产失败: $err')),
        )
      ],
    );
  }

  Widget _buildAssetCard(BuildContext context, WidgetRef ref, Asset asset) { // 增加 ref 参数
    return Card(
      child: ListTile(
        leading: Icon(asset.trackingMethod == AssetTrackingMethod.shareBased
            ? Icons.pie_chart_outline
            : Icons.account_balance_wallet_outlined),
        title: Text(asset.name),
        subtitle: Text(
            asset.trackingMethod == AssetTrackingMethod.shareBased ? '份额法' : '价值法'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShareAssetDetailPage(assetId: asset.id),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ValueAssetDetailPage(assetId: asset.id),
              ),
            );
          }
        },
        // --- 新增：长按删除功能 ---
        onLongPress: () {
          _showDeleteAssetConfirmationDialog(context, ref, asset);
        },
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String title, String value,
      {Color? color}) {
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

  void _showDeleteAssetConfirmationDialog(BuildContext context, WidgetRef ref, Asset asset) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('确认删除 "${asset.name}"'),
        content: const Text('删除此资产将同时删除其下所有的交易记录和持仓快照，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final isar = DatabaseService().isar;
              await isar.writeTxn(() async {
                // 安全删除：先删除所有关联的子对象，再删除资产本身
                await asset.snapshots.load();
                await asset.transactions.load();
                await isar.positionSnapshots.deleteAll(asset.snapshots.map((s) => s.id).toList());
                await isar.transactions.deleteAll(asset.transactions.map((t) => t.id).toList());
                await isar.assets.delete(asset.id);
              });
              // 刷新列表
              ref.invalidate(trackedAssetsProvider(accountId));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }  
}
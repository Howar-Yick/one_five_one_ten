import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/transaction_history_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';

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

final trackedAssetsWithPerformanceProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, accountId) {
  final isar = DatabaseService().isar;
  final calculator = CalculatorService();

  return isar.accounts
      .watchObject(accountId, fireImmediately: true)
      .asyncMap((account) async {
    if (account == null) return [];
    
    await account.trackedAssets.load();
    final assets = account.trackedAssets.toList();
    
    final List<Map<String, dynamic>> results = [];
    for (final asset in assets) {
      Map<String, dynamic> performanceData;
      if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        performanceData = await calculator.calculateShareAssetPerformance(asset);
      } else {
        performanceData = await calculator.calculateValueAssetPerformance(asset);
      }
      results.add({
        'asset': asset,
        'performance': performanceData,
      });
    }
    return results;
  });
});

final accountHistoryProvider = FutureProvider.autoDispose.family<List<FlSpot>, Account>((ref, account) {
  ref.watch(accountPerformanceProvider(account.id));
  return CalculatorService().getAccountValueHistory(account);
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
                  TextField(
                      controller: valueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: '当前总资产价值', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate),
                            style: const TextStyle(fontSize: 16)),
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
                    final value = double.tryParse(valueController.text);
                    if (value != null) {
                      final isar = DatabaseService().isar;
                      final newTxn = AccountTransaction()
                        ..amount = value
                        ..date = selectedDate
                        ..type = TransactionType.updateValue
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

  Widget _buildMicroView(BuildContext context, WidgetRef ref, int accountId) {
    final asyncAssets = ref.watch(trackedAssetsWithPerformanceProvider(accountId));
    final account = ref.watch(accountDetailProvider(accountId)).asData?.value;

    return Column(
      children: [
        if(account != null)
          ref.watch(accountHistoryProvider(account)).when(
            data: (spots) {
              if (spots.isEmpty) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('账户净值趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _buildHistoryChart(context, spots),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e,s) => const SizedBox.shrink(),
          ),
        
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('持仓资产', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          data: (assetsData) {
            if (assetsData.isEmpty) {
              return const Card(child: ListTile(title: Text('暂无持仓资产')));
            }
            return Column(
              children: assetsData.map((assetData) => _buildAssetCard(context, ref, assetData)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('加载资产失败: $err')),
        )
      ],
    );
  }
  
  Widget _buildAssetCard(BuildContext context, WidgetRef ref, Map<String, dynamic> assetData) {
    final Asset asset = assetData['asset'];
    final Map<String, dynamic> performance = assetData['performance'];
    
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    final double totalValue = (asset.trackingMethod == AssetTrackingMethod.shareBased
        ? performance['marketValue']
        : performance['currentValue']) ?? 0.0;
    
    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    
    Color profitColor = totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Card(
      child: ListTile(
        leading: Icon(asset.trackingMethod == AssetTrackingMethod.shareBased 
          ? Icons.pie_chart_outline
          : Icons.account_balance_wallet_outlined),
        title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('市值/价值: ${currencyFormat.format(totalValue)}', overflow: TextOverflow.ellipsis)),
                Text('收益: ${currencyFormat.format(totalProfit)} (${percentFormat.format(profitRate)})', 
                  style: TextStyle(color: profitColor)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(''),
                Text('年化: ${percentFormat.format(annualizedReturn)}',
                  style: TextStyle(color: profitColor, fontSize: 12)),
              ],
            )
          ],
        ),
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
        onLongPress: () => _showDeleteAssetConfirmationDialog(context, ref, asset),
      ),
    );
  }

  void _showDeleteAssetConfirmationDialog(BuildContext context, WidgetRef ref, Asset asset) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        bool isButtonEnabled = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('删除资产 "${asset.name}"'),
              content: const Text('此操作不可撤销，将删除此资产下的所有记录。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed:() => Navigator.of(dialogContext).pop(true),
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    ).then((ok) async {
      if (ok != true) return;

      final isar = DatabaseService().isar;
      await isar.writeTxn(() async {
        await asset.snapshots.load();
        await asset.transactions.load();
        if (asset.snapshots.isNotEmpty) {
          await isar.collection<PositionSnapshot>().deleteAll(asset.snapshots.map((s) => s.id).toList());
        }
        if (asset.transactions.isNotEmpty) {
          await isar.collection<Transaction>().deleteAll(asset.transactions.map((t) => t.id).toList());
        }
        await isar.assets.delete(asset.id);
      });

      ref.invalidate(trackedAssetsWithPerformanceProvider(accountId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除资产：${asset.name}')),
        );
      }
    });
  }

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: Theme.of(context).primaryColor,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.3),
                    Theme.of(context).primaryColor.withOpacity(0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(currencyFormat.format(value), style: const TextStyle(fontSize: 10)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: spots.length > 7 ? (spots.first.x - spots.last.x).abs() / 4 : null, getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(DateFormat('yy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(value.toInt())), style: const TextStyle(fontSize: 10)),
            ))),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.2)),
          borderData: FlBorderData(show: false),
        ),
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
}
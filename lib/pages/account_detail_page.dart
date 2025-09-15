import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart'; 
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
import 'package:one_five_one_ten/utils/currency_formatter.dart';

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

  // 监听账户对象的变化，以便在子资产列表变化时刷新
  return isar.accounts
      .watchObject(accountId, fireImmediately: true)
      .asyncMap((account) async {
    if (account == null) return [];
    
    await account.trackedAssets.load();
    final assets = account.trackedAssets.toList();
    
    // 异步计算所有子资产的业绩
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
  // 依赖业绩provider，当业绩刷新时（例如添加了新交易），图表也自动刷新
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
          return RefreshIndicator(
             onRefresh: () async {
                ref.invalidate(accountPerformanceProvider(accountId));
             },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildMacroView(context, ref, account, performance),
                const SizedBox(height: 24),
                _buildMicroView(context, ref, accountId),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('发生错误: $err')),
      ),
    );
  }

  Widget _buildMacroView(BuildContext context, WidgetRef ref, Account account,
      Map<String, dynamic> performance) {
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final profitRate = (performance['profitRate'] ?? 0.0) as double;
    final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    Color profitColor =
        totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
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
              formatCurrency(performance['currentValue'] ?? 0.0, account.currency),
            ),
            _buildMetricRow(
              context,
              '净投入:',
              formatCurrency(performance['netInvestment'] ?? 0.0, account.currency),
            ),
            _buildMetricRow(
              context,
              '总收益:',
              '${formatCurrency(totalProfit, account.currency)} (${percentFormat.format(profitRate)})',
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
                        await isar.collection<AccountTransaction>().put(newTxn);
                        await newTxn.account.save();
                      });
                      
                      ref.invalidate(accountPerformanceProvider(account.id)); 
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                         Navigator.of(context).push( 
                          MaterialPageRoute(
                            builder: (_) => TransactionHistoryPage(accountId: account.id),
                          ),
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
                    final value = double.tryParse(valueController.text);
                    if (value != null) {
                      final isar = DatabaseService().isar;
                      final newTxn = AccountTransaction()
                        ..amount = value
                        ..date = selectedDate
                        ..type = TransactionType.updateValue
                        ..account.value = account;
                      await isar.writeTxn(() async {
                        await isar.collection<AccountTransaction>().put(newTxn);
                        await newTxn.account.save();
                      });
                      ref.invalidate(accountPerformanceProvider(account.id));
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                         Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransactionHistoryPage(accountId: account.id),
                          ),
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

  Widget _buildMicroView(BuildContext context, WidgetRef ref, int accountId) {
    final asyncAssets = ref.watch(trackedAssetsWithPerformanceProvider(accountId));
    final account = ref.watch(accountDetailProvider(accountId)).asData?.value;

    return Column(
      children: [
        if(account != null)
          ref.watch(accountHistoryProvider(account)).when(
            data: (spots) {
              if (spots.length < 2) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('账户净值趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _buildHistoryChart(context, spots, account),
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
        title: Text('${asset.name} (${asset.currency})', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('市值/价值: ${formatCurrency(totalValue, asset.currency)}', overflow: TextOverflow.ellipsis)),
                Text('收益: ${formatCurrency(totalProfit, asset.currency)} (${percentFormat.format(profitRate)})', 
                  style: TextStyle(color: profitColor)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(''), // 占位符
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

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots, Account account) {
    // 货币格式化和颜色方案 (这部分保留不变)
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(account.currency));
    final colorScheme = Theme.of(context).colorScheme;
    
    // -----------------------------------------------------------------
    // 改进点 1：将基于时间戳的 spots 转换为 基于索引的 indexedSpots
    // -----------------------------------------------------------------
    final List<FlSpot> indexedSpots = [];
    for (int i = 0; i < spots.length; i++) {
      // X: 使用索引 i, Y: 保持原始Y值 (金额)
      indexedSpots.add(FlSpot(i.toDouble(), spots[i].y));
    }
    
    // -----------------------------------------------------------------
    // 改进点 2：基于数据点总数（索引）计算底部标签间隔
    // -----------------------------------------------------------------
    double bottomInterval;
    const desiredLabelCount = 4.0;
    if (spots.length <= desiredLabelCount) {
      bottomInterval = 1; // 数据点少，每个都显示
    } else {
      bottomInterval = (spots.length - 1) / desiredLabelCount;
      if (bottomInterval < 1) bottomInterval = 1;
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          // -----------------------------------------------------------------
          // 改进点 3：minX 和 maxX 现在基于索引
          // -----------------------------------------------------------------
          minX: 0, // X轴从索引 0 开始
          maxX: (spots.length - 1).toDouble(), // X轴到最后一个索引结束

          lineBarsData: [
            LineChartBarData(
              // -----------------------------------------------------------------
              // 改进点 4：图表使用基于索引的数据点
              // -----------------------------------------------------------------
              spots: indexedSpots,
              isCurved: false,
              barWidth: 3,
              color: colorScheme.primary, 
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(currencyFormat.format(value), style: const TextStyle(fontSize: 10)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 30, 
                // -----------------------------------------------------------------
                // 改进点 5：间隔现在也基于索引
                // -----------------------------------------------------------------
                interval: bottomInterval, 
                getTitlesWidget: (value, meta) {
                  // value 现在是索引 (例如 0.0, 1.0, 2.0...)
                  final int index = value.toInt();
                  // 确保索引在原始 spots 列表的安全范围内
                  if (index >= 0 && index < spots.length) {
                    // -----------------------------------------------------------------
                    // 改进点 6：使用索引从原始 spots 列表中查找真实日期
                    // -----------------------------------------------------------------
                    final originalSpot = spots[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('yy-MM-dd').format(date), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center,),
                    );
                  }
                  return const Text(''); // 超出范围则不显示
                }
              )
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpotsList) {
                // -----------------------------------------------------------------
                // 改进点 7：转换提示框的逻辑
                // -----------------------------------------------------------------
                return touchedSpotsList.map((touchedSpot) {
                  // 1. 获取被触摸点的索引
                  final int index = touchedSpot.x.round();
                  
                  // 2. 检查索引安全性
                  if (index < 0 || index >= spots.length) {
                     return null;
                  }

                  // 3. 从原始 spots 列表（包含真实时间戳）中获取数据
                  final FlSpot originalSpot = spots[index];
                  final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                  final value = formatCurrency(originalSpot.y, account.currency); // Y值 (金额) 是相同的
                  
                  return LineTooltipItem(
                    '$date\n$value',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).where((item) => item != null).cast<LineTooltipItem>().toList(); // 过滤掉 null
              },
            ),
          ),
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
// 文件: lib/pages/account_detail_page.dart
// (这是完整、已修复的文件代码)

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
import 'package:one_five_one_ten/providers/global_providers.dart'; 
import 'package:one_five_one_ten/services/supabase_sync_service.dart';


// --- Provider 1: 获取账户详情 (保持不变) ---
final accountDetailProvider =
    FutureProvider.autoDispose.family<Account?, int>((ref, accountId) {
  final isar = DatabaseService().isar;
  return isar.accounts.get(accountId);
});

// --- Provider 2: 计算账户性能 (保持不变) ---
final accountPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, accountId) async {
  final account = await ref.watch(accountDetailProvider(accountId).future);
  if (account == null) {
    throw '未找到账户';
  }
  return CalculatorService().calculateAccountPerformance(account);
});

// --- Provider 3: 获取带性能的资产 (保持不变) ---
final trackedAssetsWithPerformanceProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, accountId) async* { 
  
  final isar = DatabaseService().isar;
  final calculator = CalculatorService();

  final account = await ref.watch(accountDetailProvider(accountId).future);
  if (account == null || account.supabaseId == null) {
    yield []; 
    return;
  }
  
  final accountSupabaseId = account.supabaseId!;

  final assetStream = isar.assets
      .where()
      .filter()
      .accountSupabaseIdEqualTo(accountSupabaseId)
      .watch(fireImmediately: true);

  await for (var assets in assetStream) {
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
    yield results; 
  }
});

// --- Provider 4: 账户历史 (保持不变) ---
final accountHistoryProvider = FutureProvider.autoDispose.family<List<FlSpot>, Account>((ref, account) {
  ref.watch(accountPerformanceProvider(account.id));
  return CalculatorService().getAccountValueHistory(account);
});


// (*** 这是修复后的类。所有辅助函数都在类内部，但在 build() 之外 ***)
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
                ref.invalidate(trackedAssetsWithPerformanceProvider(accountId));
              },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildMacroView(context, ref, account, performance),
                const SizedBox(height: 24),
                _buildMicroView(context, ref, accountId, account), 
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

  // (*** 这是修复后的 _showInvestWithdrawDialog ***)
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
                  // --- (*** 这是修复后的 onPressed ***) ---
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
                      
                      // 1. 创建新对象
                      final newTxn = AccountTransaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now() 
                        ..type = isSelected[0]
                            ? TransactionType.invest
                            : TransactionType.withdraw
                        ..accountSupabaseId = account.supabaseId; 

                      // 2. (!!! 关键：先在本地写入，获取一个稳定的 Isar ID !!!)
                      final isar = DatabaseService().isar; 
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                      });
                      // (此时 newTxn.id 已经是一个有效的 Isar ID, 不再是 null)

                      // 3. 调用 syncService (传入带有 Isar ID 的对象)
                      //    (如果这一步失败，它会抛出异常，被下面的 catch 捕获)
                      await syncService.saveAccountTransaction(newTxn);

                      // 4. 刷新UI (只有在 2 和 3 都成功后才会执行)
                      ref.invalidate(accountPerformanceProvider(account.id)); 
                      ref.invalidate(dashboardDataProvider);

                      // 5. 成功后关闭对话框并导航
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).push( 
                          MaterialPageRoute(
                            builder: (_) => TransactionHistoryPage(accountId: account.id),
                          ),
                        );
                      }
                    } catch (e) {
                      // (捕获所有错误并提示，包括本地保存或同步失败)
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

  // (*** 这是修复后的 _showUpdateValueDialog ***)
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
                  // --- (*** 这是修复后的 onPressed ***) ---
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

                      // 1. 创建新对象
                      final newTxn = AccountTransaction()
                        ..amount = value
                        ..date = selectedDate
                        ..createdAt = DateTime.now() 
                        ..type = TransactionType.updateValue
                        ..accountSupabaseId = account.supabaseId; 
                      
                      // 2. (!!! 关键：先在本地写入 !!!)
                      final isar = DatabaseService().isar;
                       await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                      });
                      // (此时 newTxn.id 已经是一个有效的 Isar ID)

                      // 3. 调用 syncService 保存
                      await syncService.saveAccountTransaction(newTxn);
                      
                      // 4. 刷新
                      ref.invalidate(accountPerformanceProvider(account.id));
                      ref.invalidate(dashboardDataProvider);

                      // 5. 成功后关闭并导航
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                          Navigator.of(context).push(
                           MaterialPageRoute(
                              builder: (_) => TransactionHistoryPage(accountId: account.id),
                           ),
                         );
                      }
                    } catch (e) {
                      // (捕获所有错误并提示)
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

  // (*** 这是修复后的 _buildMicroView ***)
  // (它现在可以正确调用 _buildHistoryChart 和 _buildAssetCard，因为它们都是同级的类成员)
  Widget _buildMicroView(BuildContext context, WidgetRef ref, int accountId, Account account) {
    final asyncAssets = ref.watch(trackedAssetsWithPerformanceProvider(accountId));
    
    return Column(
      children: [
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
                    _buildHistoryChart(context, spots, account), // <-- 这是正确的调用
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
                ).then((_) {
                  ref.invalidate(accountDetailProvider(accountId));
                  ref.invalidate(accountPerformanceProvider(accountId));
                  ref.invalidate(trackedAssetsWithPerformanceProvider(accountId)); 
                });
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
              children: assetsData.map((assetData) => _buildAssetCard(context, ref, assetData, accountId)).toList(), // <-- 这是正确的调用
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('加载资产失败: $err')),
        )
      ],
    );
  }
  
  Widget _buildAssetCard(BuildContext context, WidgetRef ref, Map<String, dynamic> assetData, int accountId) {
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
          final pageRoute = MaterialPageRoute(builder: (context) {
            return asset.trackingMethod == AssetTrackingMethod.shareBased
                ? ShareAssetDetailPage(assetId: asset.id)
                : ValueAssetDetailPage(assetId: asset.id);
          });

          Navigator.of(context).push(pageRoute).then((_) {
            ref.invalidate(accountDetailProvider(accountId));
            ref.invalidate(accountPerformanceProvider(accountId));
            ref.invalidate(trackedAssetsWithPerformanceProvider(accountId)); 
          });
        },
        
        onLongPress: () => _showDeleteAssetConfirmationDialog(context, ref, asset, accountId), 
      ),
    );
  }

  void _showDeleteAssetConfirmationDialog(BuildContext context, WidgetRef ref, Asset asset, int accountId) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
    ).then((ok) async {
      if (ok != true) return;
      if (asset.supabaseId == null) {
        final isar = DatabaseService().isar;
        await isar.writeTxn(() => isar.assets.delete(asset.id));
        ref.invalidate(accountPerformanceProvider(accountId));
        ref.invalidate(dashboardDataProvider);
        return;
      }

      final isar = DatabaseService().isar;
      final syncService = ref.read(syncServiceProvider);
      
      final txs = await isar.transactions.where()
                          .filter()
                          .assetSupabaseIdEqualTo(asset.supabaseId)
                          .findAll();
      final snaps = await isar.positionSnapshots.where()
                                .filter()
                                .assetSupabaseIdEqualTo(asset.supabaseId)
                                .findAll();
      
      for (final tx in txs) { await syncService.deleteTransaction(tx); }
      for (final snap in snaps) { await syncService.deletePositionSnapshot(snap); }
      
      await syncService.deleteAsset(asset);

      ref.invalidate(accountPerformanceProvider(accountId));
      ref.invalidate(dashboardDataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除资产：${asset.name}')),
        );
      }
    });
  }

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots, Account account) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(account.currency));
    final colorScheme = Theme.of(context).colorScheme;
    
    final List<FlSpot> indexedSpots = [];
    for (int i = 0; i < spots.length; i++) {
      indexedSpots.add(FlSpot(i.toDouble(), spots[i].y));
    }
    
    double bottomInterval;
    const desiredLabelCount = 4.0;
    if (spots.length <= desiredLabelCount) {
      bottomInterval = 1; 
    } else {
      bottomInterval = (spots.length - 1) / desiredLabelCount;
      if (bottomInterval < 1) bottomInterval = 1;
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0, 
          maxX: (spots.length - 1).toDouble(), 

          lineBarsData: [
            LineChartBarData(
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
                interval: bottomInterval, 
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index >= 0 && index < spots.length) {
                    final originalSpot = spots[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('yy-MM-dd').format(date), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center,),
                    );
                  }
                  return const Text('');
                }
              )
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpotsList) {
                return touchedSpotsList.map((touchedSpot) {
                  final int index = touchedSpot.x.round();
                  
                  if (index < 0 || index >= spots.length) {
                       return null;
                  }

                  final FlSpot originalSpot = spots[index];
                  final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                  final value = formatCurrency(originalSpot.y, account.currency); 
                  
                  return LineTooltipItem(
                    '$date\n$value',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).where((item) => item != null).cast<LineTooltipItem>().toList(); 
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
// 文件: lib/pages/value_asset_detail_page.dart
// (这是已修复 "getter 'account' isn't defined" Bug 的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
// import 'package:one_five_one_ten/services/calculator_service.dart'; // (已在 global_providers 导入)
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart';
import 'package:isar/isar.dart';

// (*** 1. 关键修复：添加以下两个导入 ***)
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';

// (*** 关键修复：顶部的所有 Provider 定义都已被【移除】并转移到 global_providers.dart ***)


// (*** 1. 关键修改：转换为 ConsumerStatefulWidget ***)
class ValueAssetDetailPage extends ConsumerStatefulWidget {
  final int assetId;
  const ValueAssetDetailPage({super.key, required this.assetId});

  @override
  ConsumerState<ValueAssetDetailPage> createState() => _ValueAssetDetailPageState();
}

class _ValueAssetDetailPageState extends ConsumerState<ValueAssetDetailPage> {
  
  // (*** 2. 新增状态变量：用于跟踪图表切换 ***)
  // (我们复用账户页的枚举，因为它是一样的)
  AccountChartType _selectedChartType = AccountChartType.totalValue;

  @override
  Widget build(BuildContext context) {
    // (*** 3. 修改：使用 widget.assetId 和全局 Provider ***)
    final asyncAsset = ref.watch(valueAssetDetailProvider(widget.assetId));
    final asyncPerformance = ref.watch(valueAssetPerformanceProvider(widget.assetId));
    // (*** 4. 修改：Watch 新的图表 Provider ***)
    final asyncChartData = ref.watch(valueAssetHistoryChartsProvider(widget.assetId));

    return asyncAsset.when(
      data: (asset) {
        if (asset == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('资产不存在')),
            body: const Center(child: Text('此资产可能已被删除。')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(asset.name),
            
            // (*** 2. 关键修复：替换为这个 actions 块 ***)
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '编辑资产',
                // (*** 修复 1: 转换为 async ***)
                onPressed: () async {
                  
                  // (*** 修复 2: 获取 Isar 实例 ***)
                  final isar = DatabaseService().isar;

                  // (*** 修复 3: 使用 accountSupabaseId 异步查询父账户 ***)
                  final account = await isar.accounts
                      .filter()
                      .supabaseIdEqualTo(asset.accountSupabaseId)
                      .findFirst();

                  // (*** 修复 4: 检查账户是否存在 ***)
                  if (account == null) {
                    // (*** 修复 5: 在异步函数中安全地显示 SnackBar ***)
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法找到父账户，数据可能未同步。')),
                      );
                    }
                    return;
                  }

                  // (*** 修复 6: 在异步函数中安全地导航 ***)
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditAssetPage(
                          accountId: account.id, // (父账户的 Isar ID)
                          assetId: asset.id,     // (当前资产的 Isar ID)
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
            // (*** 修复结束 ***)

          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(valueAssetPerformanceProvider(widget.assetId));
              // (*** 5. 修改：刷新新的图表 Provider ***)
              ref.invalidate(valueAssetHistoryChartsProvider(widget.assetId));
            },
            // (*** 6. 修改：将所有辅助函数调用移入 _ValueAssetDetailView ***)
            child: _ValueAssetDetailView(
              asset: asset,
              performanceAsync: asyncPerformance,
              chartAsync: asyncChartData,
              selectedChartType: _selectedChartType,
              onChartTypeChanged: (newType) {
                setState(() {
                  _selectedChartType = newType;
                });
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            tooltip: '添加记录',
            onPressed: () {
              // (*** 7. 修改：_showAddTransactionDialog 现在是 State 的一部分 ***)
              _showAddTransactionDialog(context, ref, asset);
            },
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('加载资产失败: $e')),
      ),
    );
  }

  // (*** 8. 修改：所有辅助函数现在都是 State 的一部分 ***)

  Widget _buildMetricRow(BuildContext context, String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
      BuildContext context, Map<String, dynamic> performance, String currencyCode) {
    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    Color profitColor =
        totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('业绩概览',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _buildMetricRow(
              context,
              '总收益:',
              '${formatCurrency(totalProfit, currencyCode)} (${percentFormat.format(profitRate)})',
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
          ],
        ),
      ),
    );
  }

  // (*** 9. 关键修改：_buildHistoryChart ***)
  Widget _buildHistoryChart(
      BuildContext context, 
      Map<String, List<FlSpot>> chartDataMap, // (*** 接收 Map ***)
      Asset asset,
      AccountChartType selectedChartType,    // (*** 接收当前状态 ***)
      Function(AccountChartType) onChartTypeChanged // (*** 接收回调 ***)
  ) {
    
    // (*** 10. 新增：图表切换逻辑 ***)
    List<FlSpot> spots;
    String chartTitle;
    bool isPercentage = false; 

    switch (selectedChartType) { 
      case AccountChartType.totalProfit:
        spots = chartDataMap['totalProfit'] ?? [];
        chartTitle = '累计收益趋势';
        break;
      case AccountChartType.profitRate:
        spots = chartDataMap['profitRate'] ?? [];
        chartTitle = '收益率趋势';
        isPercentage = true;
        break;
      case AccountChartType.totalValue:
      default:
        spots = chartDataMap['totalValue'] ?? [];
        chartTitle = '资产净值趋势';
        break;
    }

    if (spots.length < 2) return const SizedBox.shrink();

    final NumberFormat yAxisFormat;
    if (isPercentage) {
      yAxisFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;
    } else {
      yAxisFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(asset.currency));
    }
    // (*** 切换逻辑结束 ***)


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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chartTitle, // (*** 11. 修改：动态标题 ***)
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // (*** 12. 新增：切换按钮 ***)
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SegmentedButton<AccountChartType>(
                    segments: const [
                      ButtonSegment(value: AccountChartType.totalValue, label: Text('净值'), icon: Icon(Icons.show_chart)),
                      ButtonSegment(value: AccountChartType.totalProfit, label: Text('收益'), icon: Icon(Icons.trending_up)),
                      ButtonSegment(value: AccountChartType.profitRate, label: Text('收益率'), icon: Icon(Icons.percent)),
                    ],
                    selected: {selectedChartType},
                    onSelectionChanged: (newSelection) {
                      onChartTypeChanged(newSelection.first); // (*** 调用回调 ***)
                    },
                    showSelectedIcon: constraints.maxWidth >= 360,
                  );
                }
              ),
            ),
            const SizedBox(height: 24),
            
            // (*** 13. 修改：图表本身 ***)
            SizedBox(
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
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 50, 
                      getTitlesWidget: (value, meta) => Text(yAxisFormat.format(value), style: const TextStyle(fontSize: 10)) // (动态Y轴)
                    )),
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
                          if (index < 0 || index >= spots.length) return null;

                          final FlSpot originalSpot = spots[index];
                          final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                          
                          final String valueStr;
                          if (isPercentage) {
                            valueStr = (NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2).format(originalSpot.y);
                          } else {
                            valueStr = formatCurrency(originalSpot.y, asset.currency);
                          }
                          
                          return LineTooltipItem(
                            '$date\n$valueStr', 
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).whereType<LineTooltipItem>().toList(); 
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, Asset asset) {
    // ( ... 此函数保持不变 ...)
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TransactionType selectedType = TransactionType.invest; 

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('添加 ${asset.name} 记录'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(value: TransactionType.invest, label: Text('投入')),
                        ButtonSegment(value: TransactionType.withdraw, label: Text('取出')),
                        ButtonSegment(value: TransactionType.updateValue, label: Text('更新总值')),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          selectedType = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: selectedType == TransactionType.updateValue ? '资产总值' : '金额',
                        prefixText: getCurrencySymbol(asset.currency)
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
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    try {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || (amount <= 0 && selectedType != TransactionType.updateValue)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入有效的金额')),
                        );
                        return;
                      }

                      final syncService = ref.read(syncServiceProvider);
                      
                      final newTxn = Transaction()
                        ..type = selectedType
                        ..date = selectedDate
                        // (*** 修复：价值法中，投入为负现金流，取出为正现金流 ***)
                        ..amount = (selectedType == TransactionType.invest) ? -amount : amount 
                        ..createdAt = DateTime.now()
                        ..assetSupabaseId = asset.supabaseId; 

                      // (为 updateValue 设置正确的 amount)
                      if (selectedType == TransactionType.updateValue) {
                        newTxn.amount = amount;
                      }
                      
                      final isar = DatabaseService().isar; 
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                      });

                      await syncService.saveTransaction(newTxn);

                      ref.invalidate(valueAssetPerformanceProvider(asset.id)); 
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      print('保存交易失败: $e');
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('保存失败: $e')),
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
} 
// (*** 9. 关键修复：将 _ValueAssetDetailView 辅助 Widget 移到 State 类之外 ***)
// (*** 这是导致 `_ValueAssetDetailView isn't defined` 错误的根源 ***)
class _ValueAssetDetailView extends ConsumerWidget {
  final Asset asset;
  final AsyncValue<Map<String, dynamic>> performanceAsync;
  final AsyncValue<Map<String, List<FlSpot>>> chartAsync; // (*** 接收新的 Map ***)
  final AccountChartType selectedChartType;
  final Function(AccountChartType) onChartTypeChanged;

  // (*** 构造函数也需要更新 ***)
  const _ValueAssetDetailView({
    required this.asset,
    required this.performanceAsync,
    required this.chartAsync,
    required this.selectedChartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    // (*** 辅助函数现在属于这个类 ***)
    
    Widget buildMetricRow(BuildContext context, String title, String value, {Color? color}) {
      // (*** 修复：这个辅助函数需要 BuildContext ***)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
    }

    Widget buildPerformanceCard(Map<String, dynamic> performance, String currencyCode) {
      final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
      final double profitRate = (performance['profitRate'] ?? 0.0) as double;
      final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
      final percentFormat =
          NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
      Color profitColor =
          totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
      if (totalProfit == 0) {
        profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('业绩概览',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              buildMetricRow( // (*** 修复：添加 context ***)
                context,
                '总收益:',
                '${formatCurrency(totalProfit, currencyCode)} (${percentFormat.format(profitRate)})',
                color: profitColor,
              ),
              buildMetricRow( // (*** 修复：添加 context ***)
                context,
                '年化收益率:',
                percentFormat.format(annualizedReturn),
                color: annualizedReturn > 0
                    ? Colors.red.shade400
                    : Colors.green.shade400,
              ),
            ],
          ),
        ),
      );
    }
    
    Widget buildHistoryChart(Map<String, List<FlSpot>> chartDataMap, Asset asset) {
      List<FlSpot> spots;
      String chartTitle;
      bool isPercentage = false; 

      switch (selectedChartType) { 
        case AccountChartType.totalProfit:
          spots = chartDataMap['totalProfit'] ?? [];
          chartTitle = '累计收益趋势';
          break;
        case AccountChartType.profitRate:
          spots = chartDataMap['profitRate'] ?? [];
          chartTitle = '收益率趋势';
          isPercentage = true;
          break;
        case AccountChartType.totalValue:
        default:
          spots = chartDataMap['totalValue'] ?? [];
          chartTitle = '资产净值趋势';
          break;
      }

      if (spots.length < 2) return const SizedBox.shrink();

      final NumberFormat yAxisFormat;
      if (isPercentage) {
        yAxisFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;
      } else {
        yAxisFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(asset.currency));
      }
      
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

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chartTitle, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SegmentedButton<AccountChartType>(
                      segments: const [
                        ButtonSegment(value: AccountChartType.totalValue, label: Text('净值'), icon: Icon(Icons.show_chart)),
                        ButtonSegment(value: AccountChartType.totalProfit, label: Text('收益'), icon: Icon(Icons.trending_up)),
                        ButtonSegment(value: AccountChartType.profitRate, label: Text('收益率'), icon: Icon(Icons.percent)),
                      ],
                      selected: {selectedChartType},
                      onSelectionChanged: (newSelection) {
                        onChartTypeChanged(newSelection.first); 
                      },
                      showSelectedIcon: constraints.maxWidth >= 360,
                    );
                  }
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
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
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(yAxisFormat.format(value), style: const TextStyle(fontSize: 10)))),
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
                            if (index < 0 || index >= spots.length) return null;

                            final FlSpot originalSpot = spots[index];
                            final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                            
                            final String valueStr;
                            if (isPercentage) {
                              valueStr = (NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2).format(originalSpot.y);
                            } else {
                              valueStr = formatCurrency(originalSpot.y, asset.currency);
                            }
                            
                            return LineTooltipItem(
                              '$date\n$valueStr', 
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          }).whereType<LineTooltipItem>().toList(); 
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }


    // --- (*** _ValueAssetDetailView 的 build 方法 ***) ---
    return performanceAsync.when(
      data: (performance) {
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // (*** 1. 顶部性能卡片 ***)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('资产净值', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    buildMetricRow( // (*** 修复：添加 context ***)
                      context,
                      '当前总值:',
                      formatCurrency(performance['currentValue'] ?? 0.0, asset.currency),
                    ),
                    buildMetricRow( // (*** 修复：添加 context ***)
                      context,
                      '净投入:',
                      formatCurrency(performance['netInvestment'] ?? 0.0, asset.currency),
                    ),
                  ],
                ),
              ),
            ),
            
            // (*** 2. 业绩概览卡片 ***)
            buildPerformanceCard(performance, asset.currency),
            
            // (*** 3. 图表卡片 ***)
            chartAsync.when(
              data: (chartDataMap) => buildHistoryChart(chartDataMap, asset), 
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )),
              error: (e, s) => Text('图表加载失败: $e'),
            ),
            
            // (*** 4. 辅助按钮 ***)
            const SizedBox(height: 8),
            TextButton(
              child: const Text('查看交易历史'),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  // (*** 修复：导航错误 ***)
                  builder: (_) => AssetTransactionHistoryPage(assetId: asset.id),
                ));
              },
            ),
            
            const SizedBox(height: 80), // (为 FAB 留出空间)
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('加载性能数据失败: $e')),
    );
  }
}
// 文件: lib/pages/value_asset_detail_page.dart
// (这是已修复“添加记录卡顿”Bug 的纯净完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';
import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';


class ValueAssetDetailPage extends ConsumerStatefulWidget {
  final int assetId;
  const ValueAssetDetailPage({super.key, required this.assetId});

  @override
  ConsumerState<ValueAssetDetailPage> createState() => _ValueAssetDetailPageState();
}

class _ValueAssetDetailPageState extends ConsumerState<ValueAssetDetailPage> {
  
  AccountChartType _selectedChartType = AccountChartType.totalValue;

  @override
  Widget build(BuildContext context) {
    final asyncAsset = ref.watch(valueAssetDetailProvider(widget.assetId));
    final asyncPerformance = ref.watch(valueAssetPerformanceProvider(widget.assetId));
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
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '编辑资产',
                onPressed: () async {
                  
                  final isar = DatabaseService().isar;

                  final account = await isar.accounts
                      .filter()
                      .supabaseIdEqualTo(asset.accountSupabaseId)
                      .findFirst();

                  if (account == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法找到父账户，数据可能未同步。')),
                      );
                    }
                    return;
                  }

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
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(valueAssetPerformanceProvider(widget.assetId));
              ref.invalidate(valueAssetHistoryChartsProvider(widget.assetId));
            },
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


  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final amountController = TextEditingController();
    final fxRateController = TextEditingController();
    final cnyAmountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TransactionType selectedType = TransactionType.invest;
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
                    if (asset.currency != 'CNY' && selectedType != TransactionType.updateValue) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: fxRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '汇率（资产币种→CNY）',
                          helperText: '默认拉取当前汇率，可手动调整',
                        ),
                        onChanged: (_) {
                          final amount = double.tryParse(amountController.text);
                          final rate = double.tryParse(fxRateController.text);
                          if (amount != null && rate != null) {
                            cnyAmountController.text =
                                (amount * rate).toStringAsFixed(2);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cnyAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '折算人民币金额',
                          helperText: '买入为正，卖出为负',
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

                      double? fxRate;
                      double? amountCny;
                      if (asset.currency != 'CNY' && selectedType != TransactionType.updateValue) {
                        fxRate = double.tryParse(fxRateController.text);
                        amountCny = double.tryParse(cnyAmountController.text);
                        if (fxRate == null && amountCny != null && amount > 0) {
                          fxRate = amountCny / amount;
                        }
                        if (amountCny == null && fxRate != null) {
                          amountCny = amount * fxRate;
                        }
                      }

                      final newTxn = Transaction()
                        ..type = selectedType
                        ..date = selectedDate
                        ..amount = (selectedType == TransactionType.invest) ? -amount : amount
                        ..createdAt = DateTime.now()
                        ..assetSupabaseId = asset.supabaseId
                        ..fxRateToCny = fxRate
                        ..amountCny = amountCny;

                      if (selectedType == TransactionType.updateValue) {
                        newTxn.amount = amount;
                      }
                      
                      final isar = DatabaseService().isar; 
                      
                      // 1. (保持 AWAIT) 立即写入本地数据库 (速度很快)
                      await isar.writeTxn(() async {
                        await isar.transactions.put(newTxn);
                      });

                      // 2. (关键修复：移除 await，让同步在后台运行)
                      syncService.saveTransaction(newTxn).catchError((e) {
                        print('[BG Sync] 交易记录同步失败: $e');
                      });

                      // 3. 立即刷新 UI
                      ref.invalidate(valueAssetPerformanceProvider(asset.id)); 
                      ref.invalidate(dashboardDataProvider);

                      // 4. 立即关闭弹窗
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

class _ValueAssetDetailView extends ConsumerWidget {
  final Asset asset;
  final AsyncValue<Map<String, dynamic>> performanceAsync;
  final AsyncValue<Map<String, List<FlSpot>>> chartAsync;
  final AccountChartType selectedChartType;
  final Function(AccountChartType) onChartTypeChanged;

  const _ValueAssetDetailView({
    required this.asset,
    required this.performanceAsync,
    required this.chartAsync,
    required this.selectedChartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    Widget buildMetricRow(BuildContext context, String title, String value, {Color? color}) {
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
      final double? totalProfitCny = performance['totalProfitCny'] as double?;
      final double? fxProfitCny = performance['fxProfitCny'] as double?;
      final double? assetProfitCny = performance['assetProfitCny'] as double?;
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
              buildMetricRow(
                context,
                '总收益:',
                '${formatCurrency(totalProfit, currencyCode)} (${percentFormat.format(profitRate)})',
                color: profitColor,
              ),
              buildMetricRow(
                context,
                '年化收益率:',
                percentFormat.format(annualizedReturn),
                color: annualizedReturn > 0
                    ? Colors.red.shade400
                    : Colors.green.shade400,
              ),
              if (currencyCode != 'CNY' && totalProfitCny != null) ...[
                const SizedBox(height: 8),
                const Divider(),
                buildMetricRow(
                  context,
                  '总收益（CNY）:',
                  formatCurrency(totalProfitCny, 'CNY'),
                  color: totalProfitCny >= 0
                      ? Colors.red.shade400
                      : Colors.green.shade400,
                ),
                if (assetProfitCny != null)
                  buildMetricRow(
                    context,
                    '标的收益（CNY）:',
                    formatCurrency(assetProfitCny, 'CNY'),
                  ),
                if (fxProfitCny != null)
                  buildMetricRow(
                    context,
                    '汇率收益（CNY）:',
                    formatCurrency(fxProfitCny, 'CNY'),
                  ),
              ],
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
                        // ★★★ 修复点: 根据数据点数量动态显示圆点 ★★★
                        dotData: FlDotData(show: spots.length < 40),
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
                    buildMetricRow(
                      context,
                      '当前总值:',
                      formatCurrency(performance['currentValue'] ?? 0.0, asset.currency),
                    ),
                    buildMetricRow(
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
// 文件: lib/pages/share_asset_detail_page.dart
// (这是已添加图表切换功能并移除旧 Provider 的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart'; 
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
// import 'package:one_five_one_ten/models/transaction.dart'; // (已移除)
import 'package:one_five_one_ten/pages/snapshot_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; 
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
// import 'package:one_five_one_ten/pages/asset_transaction_history_page.dart'; // (已移除)
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart'; 

// (*** 关键修复：顶部的所有 Provider 定义都已被【移除】 ***)


// (*** 1. 关键修改：转换为 ConsumerStatefulWidget ***)
class ShareAssetDetailPage extends ConsumerStatefulWidget {
  final int assetId;
  const ShareAssetDetailPage({super.key, required this.assetId});

  @override
  ConsumerState<ShareAssetDetailPage> createState() => _ShareAssetDetailPageState();
}

class _ShareAssetDetailPageState extends ConsumerState<ShareAssetDetailPage> {
  
  // (*** 2. 新增：图表状态变量 ***)
  ShareAssetChartType _selectedChartType = ShareAssetChartType.price;
  // (*** 新增结束 ***)

  @override
  Widget build(BuildContext context) {
    // (*** 3. 修改： ref.watch 和 widget.assetId ***)
    final asyncAsset = ref.watch(shareAssetDetailProvider(widget.assetId));
    final asyncPerformance = ref.watch(shareAssetPerformanceProvider(widget.assetId));
    
    // (*** 4. 修改：我们不再需要在这里 watch 图表，图表卡片自己会 watch ***)
    // final asyncChartData = ref.watch(assetHistoryChartProvider(assetId)); // <-- 移除
    // final asyncChartData = ref.watch(shareAssetCombinedChartProvider(widget.assetId)); // <-- 也不需要

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
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑资产',
                onPressed: () async {
                  final isar = DatabaseService().isar;
                  Account? parentAccount;
                  if (asset.accountSupabaseId != null) {
                    parentAccount = await isar.accounts
                        .where()
                        .filter()
                        .supabaseIdEqualTo(asset.accountSupabaseId)
                        .findFirst();
                  }
                  if (parentAccount == null && asset.accountLocalId != null) {
                    parentAccount = await isar.accounts.get(asset.accountLocalId!);
                  }

                  if (!context.mounted) {
                    return;
                  }

                  if (parentAccount != null) {
                    final accountId = parentAccount.id;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEditAssetPage(accountId: accountId, assetId: asset.id),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('错误：找不到父账户')));
                  }
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
              ref.invalidate(shareAssetPerformanceProvider(widget.assetId));
              // (*** 5. 修改：刷新新的组合 provider ***)
              ref.invalidate(shareAssetCombinedChartProvider(widget.assetId));
            },
            child: _ShareAssetDetailView(
              asset: asset,
              performanceAsync: asyncPerformance,
              // (*** 6. 修改：我们不再传递图表数据，视图会自己构建 ***)
              // chartAsync: asyncChartData,
            ),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.sync_alt), 
            tooltip: '更新持仓快照',
            onPressed: () {
              // (*** 7. 修改：调用 State 类中的方法 ***)
              _showUpdateSnapshotDialog(context, ref, asset);
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


  // (*** 8. 修改：_build... 和 _show... 方法现在是 State 的一部分 ***)

  // (*** 9. 新增：快照更新弹窗 ***)
  void _showUpdateSnapshotDialog(BuildContext context, WidgetRef ref, Asset asset) {
    // (*** 10. 修改：从 ref 读取 provider ***)
    final performance = ref.read(shareAssetPerformanceProvider(asset.id));
    final sharesController = TextEditingController(
      text: performance.asData?.value['totalShares']?.toString() ?? ''
    );
    final costController = TextEditingController(
       text: performance.asData?.value['averageCost']?.toString() ?? ''
    );
    final priceController = TextEditingController(text: asset.latestPrice > 0 ? asset.latestPrice.toString() : ''); 
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新持仓快照'),
              content: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: sharesController, decoration: const InputDecoration(labelText: '最新总份额'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    TextField(controller: costController, decoration: InputDecoration(labelText: '最新单位成本', prefixText: getCurrencySymbol(asset.currency)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    TextField(controller: priceController, decoration: InputDecoration(labelText: '最新价格 (可选)', prefixText: getCurrencySymbol(asset.currency)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text("快照日期:", style: TextStyle(fontSize: 16)),
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
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    final priceText = priceController.text.trim();
                    
                    if (shares == null || cost == null) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('请输入有效的份额和成本'))
                         );
                       }
                       return;
                    }

                    try {
                      final syncService = ref.read(syncServiceProvider); 
                      
                      bool assetUpdated = false;
                      if (priceText.isNotEmpty) {
                        asset.latestPrice = double.tryParse(priceText) ?? asset.latestPrice;
                        asset.priceUpdateDate = DateTime.now();
                        assetUpdated = true;
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..assetSupabaseId = asset.supabaseId; 
                      
                      await syncService.savePositionSnapshot(newSnapshot);
                      
                      if(assetUpdated) {
                        await syncService.saveAsset(asset);
                      }

                      ref.invalidate(shareAssetPerformanceProvider(asset.id));
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(); 
                      }
                      
                      if (context.mounted) {
                         Navigator.of(context).push(MaterialPageRoute(
                           builder: (_) => SnapshotHistoryPage(assetId: asset.id),
                         ));
                      }

                    } catch (e) {
                       print('更新快照失败: $e');
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('保存失败: $e'))
                         );
                       }
                    }
                  },
                  child: const Text('保存并查看历史'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- (*** 新增结束 ***) ---


  // --- (*** 11. 关键修改：_buildChartCard ***) ---
  // (它现在 watch 新的 provider，并包含切换按钮)
  Widget _buildChartCard(BuildContext context, Asset asset) {
    // (*** 1. Watch 新的组合 Provider ***)
    final asyncChartData = ref.watch(shareAssetCombinedChartProvider(asset.id));
    
    return asyncChartData.when(
      data: (chartDataMap) {
        
        // (*** 2. 根据 State 选择要显示的列表 ***)
        List<FlSpot> spots;
        String chartTitle;
        bool isPercentage = false; // 标记是否为百分比Y轴

        switch (_selectedChartType) {
          case ShareAssetChartType.totalProfit:
            spots = chartDataMap['totalProfit'] ?? [];
            chartTitle = '持仓收益趋势';
            break;
          case ShareAssetChartType.profitRate:
            spots = chartDataMap['profitRate'] ?? [];
            chartTitle = '持仓收益率趋势';
            isPercentage = true;
            break;
          case ShareAssetChartType.price:
          default:
            spots = chartDataMap['price'] ?? [];
            chartTitle = (asset.subType == AssetSubType.mutualFund) ? '单位净值历史' : '价格历史 (日K收盘)';
            break;
        }

        if (spots.length < 2) return const SizedBox.shrink();
        
        // (*** 3. 动态格式化Y轴 ***)
        final NumberFormat yAxisFormat;
        if (isPercentage) {
          yAxisFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;
        } else if (_selectedChartType == ShareAssetChartType.totalProfit) {
          yAxisFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(asset.currency));
        } else {
          // 价格
          yAxisFormat = (asset.subType == AssetSubType.mutualFund)
            ? NumberFormat("0.0000") 
            : (asset.subType == AssetSubType.etf 
              ? NumberFormat("0.000") 
              : NumberFormat("0.00"));
        }
        final tooltipFormat = (isPercentage || _selectedChartType == ShareAssetChartType.totalProfit) 
          ? yAxisFormat // 对于收益率和收益，工具提示和Y轴用相同格式
          : (asset.subType == AssetSubType.mutualFund // 对于价格，工具提示用更精确的格式
            ? NumberFormat("0.0000")
            : (asset.subType == AssetSubType.etf ? NumberFormat("0.000") : NumberFormat("0.00")));
        
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
                
                // (*** 4. 新增：切换按钮 ***)
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SegmentedButton<ShareAssetChartType>(
                        segments: const [
                          ButtonSegment(value: ShareAssetChartType.price, label: Text('价格'), icon: Icon(Icons.timeline)),
                          ButtonSegment(value: ShareAssetChartType.totalProfit, label: Text('收益'), icon: Icon(Icons.trending_up)),
                          ButtonSegment(value: ShareAssetChartType.profitRate, label: Text('收益率'), icon: Icon(Icons.percent)),
                        ],
                        selected: {_selectedChartType},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedChartType = newSelection.first;
                          });
                        },
                        showSelectedIcon: constraints.maxWidth >= 360,
                      );
                    }
                  ),
                ),
                const SizedBox(height: 24),
                
                // (*** 5. 动态图表 ***)
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
                        leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 50, 
                          getTitlesWidget: (value, meta) => Text(
                              yAxisFormat.format(value), // (使用动态格式)
                              style: const TextStyle(fontSize: 10)),
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
                                final date = DateTime.fromMillisecondsSinceEpoch(spots[index].x.toInt()); 
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('yy-MM-dd').format(date),
                                    style: const TextStyle(fontSize: 10), 
                                    textAlign: TextAlign.center,
                                  ),
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
                              
                              final originalSpot = spots[index]; 
                              final date = DateFormat('yyyy-MM-dd')
                                  .format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                              
                              // (*** 6. 动态工具提示 ***)
                              final String valueStr;
                              if (isPercentage) {
                                valueStr = (NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2).format(originalSpot.y);
                              } else if (_selectedChartType == ShareAssetChartType.totalProfit) {
                                valueStr = formatCurrency(originalSpot.y, asset.currency);
                              } else {
                                valueStr = tooltipFormat.format(originalSpot.y);
                              }

                              return LineTooltipItem(
                                '$date\n$valueStr', 
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
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
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      )),
      error: (e, s) => Text('图表加载失败: $e'),
    );
  }
  // --- (*** 图表卡片修改结束 ***) ---

}


// (*** 这是 _ShareAssetDetailView 的辅助函数，现在是 _ShareAssetDetailPageState 的成员 ***)
class _ShareAssetDetailView extends ConsumerStatefulWidget { // (*** 1. 转换为 Stateful ***)
  final Asset asset;
  final AsyncValue<Map<String, dynamic>> performanceAsync;
  // final AsyncValue<List<FlSpot>> chartAsync; // (*** 2. 移除旧的 chartAsync ***)

  const _ShareAssetDetailView({
    required this.asset,
    required this.performanceAsync,
    // required this.chartAsync, // (*** 2. 移除旧的 chartAsync ***)
  });

  @override
  ConsumerState<_ShareAssetDetailView> createState() => _ShareAssetDetailViewState();
}

class _ShareAssetDetailViewState extends ConsumerState<_ShareAssetDetailView> {
  
  // (*** 3. 新增状态变量 ***)
  ShareAssetChartType _selectedChartType = ShareAssetChartType.price;
  
  // (*** 4. _showUpdateSnapshotDialog 移到这里 ***)
  void _showUpdateSnapshotDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final performance = ref.read(shareAssetPerformanceProvider(asset.id));
    final sharesController = TextEditingController(
      text: performance.asData?.value['totalShares']?.toString() ?? ''
    );
    final costController = TextEditingController(
       text: performance.asData?.value['averageCost']?.toString() ?? ''
    );
    final priceController = TextEditingController(text: asset.latestPrice > 0 ? asset.latestPrice.toString() : ''); 
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新持仓快照'),
              content: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: sharesController, decoration: const InputDecoration(labelText: '最新总份额'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    TextField(controller: costController, decoration: InputDecoration(labelText: '最新单位成本', prefixText: getCurrencySymbol(asset.currency)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    TextField(controller: priceController, decoration: InputDecoration(labelText: '最新价格 (可选)', prefixText: getCurrencySymbol(asset.currency)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text("快照日期:", style: TextStyle(fontSize: 16)),
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
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    final priceText = priceController.text.trim();
                    
                    if (shares == null || cost == null) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('请输入有效的份额和成本'))
                         );
                       }
                       return;
                    }

                    try {
                      final syncService = ref.read(syncServiceProvider); 
                      
                      bool assetUpdated = false;
                      if (priceText.isNotEmpty) {
                        widget.asset.latestPrice = double.tryParse(priceText) ?? widget.asset.latestPrice;
                        widget.asset.priceUpdateDate = DateTime.now();
                        assetUpdated = true;
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..assetSupabaseId = widget.asset.supabaseId; 
                      
                      await syncService.savePositionSnapshot(newSnapshot);
                      
                      if(assetUpdated) {
                        await syncService.saveAsset(widget.asset);
                      }

                      ref.invalidate(shareAssetPerformanceProvider(widget.asset.id));
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(); 
                      }
                      
                      if (context.mounted) {
                         Navigator.of(context).push(MaterialPageRoute(
                           builder: (_) => SnapshotHistoryPage(assetId: widget.asset.id),
                         ));
                      }

                    } catch (e) {
                       print('更新快照失败: $e');
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('保存失败: $e'))
                         );
                       }
                    }
                  },
                  child: const Text('保存并查看历史'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // (*** 5. 修改：使用 widget.asset 和 widget.performanceAsync ***)
    return widget.performanceAsync.when(
      data: (performance) {
        
        final String latestPriceString = formatPrice(widget.asset.latestPrice, widget.asset.subType);
        final String avgCostString = formatPrice(performance['averageCost'] ?? 0.0, widget.asset.subType);

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. 顶部卡片 (总览)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatCurrency(performance['marketValue'] ?? 0.0, widget.asset.currency),
                                style: Theme.of(context).textTheme.headlineMedium),
                            Text('当前市值', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(latestPriceString, style: Theme.of(context).textTheme.headlineSmall),
                            Text(widget.asset.priceUpdateDate != null 
                                ? DateFormat('MM-dd HH:mm').format(widget.asset.priceUpdateDate!) 
                                : '未更新', 
                                style: Theme.of(context).textTheme.bodySmall
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 24),
                    _buildMetricRow(
                      context,
                      '最新价格:',
                      latestPriceString,
                    ),
                    _buildMetricRow(
                      context, 
                      '单位成本:',
                      avgCostString,
                    ),
                    _buildMetricRow(context, '当前份额:', (performance['totalShares'] ?? 0.0).toString()),
                    _buildMetricRow(context, '持仓成本:', formatCurrency(performance['totalCost'] ?? 0.0, widget.asset.currency)),
                  ],
                ),
              ),
            ),
            
            // 2. 中部卡片 (业绩)
            _buildPerformanceCard(context, performance, widget.asset.currency),
            
            // (按钮区已按要求移除)

            // 4. 图表卡片
            // (*** 6. 关键修改：直接调用 _buildChartCard ***)
            _buildChartCard(context, widget.asset),
            
            // 5. 辅助按钮
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                TextButton(
                  child: const Text('查看持仓快照历史'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SnapshotHistoryPage(assetId: widget.asset.id), 
                    ));
                  },
                ),
                // (“交易历史”按钮已移除)
              ],
            ),
            const SizedBox(height: 80), // (为 FAB 留出空间)
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('加载性能数据失败: $e')),
    );
  }

  // (Metric Row 辅助函数)
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

  // (Performance Card 函数)
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

  // (*** 7. 关键修改：_buildChartCard ***)
  Widget _buildChartCard(BuildContext context, Asset asset) {
    // (*** 1. Watch 新的组合 Provider ***)
    final asyncChartData = ref.watch(shareAssetCombinedChartProvider(asset.id));
    
    return asyncChartData.when(
      data: (chartDataMap) {
        
        // (*** 2. 根据 State 选择要显示的列表 ***)
        List<FlSpot> spots;
        String chartTitle;
        bool isPercentage = false; 

        switch (_selectedChartType) {
          case ShareAssetChartType.totalProfit:
            spots = chartDataMap['totalProfit'] ?? [];
            chartTitle = '持仓收益趋势';
            break;
          case ShareAssetChartType.profitRate:
            spots = chartDataMap['profitRate'] ?? [];
            chartTitle = '持仓收益率趋势';
            isPercentage = true;
            break;
          case ShareAssetChartType.price:
          default:
            spots = chartDataMap['price'] ?? [];
            chartTitle = (asset.subType == AssetSubType.mutualFund) ? '单位净值历史' : '价格历史 (日K收盘)';
            break;
        }

        if (spots.length < 2) return const SizedBox.shrink();
        
        // (*** 3. 动态格式化Y轴 ***)
        final NumberFormat yAxisFormat;
        if (isPercentage) {
          yAxisFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;
        } else if (_selectedChartType == ShareAssetChartType.totalProfit) {
          yAxisFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(asset.currency));
        } else {
          yAxisFormat = (asset.subType == AssetSubType.mutualFund)
            ? NumberFormat("0.0000") 
            : (asset.subType == AssetSubType.etf 
              ? NumberFormat("0.000") 
              : NumberFormat("0.00"));
        }
        
        final tooltipFormat = (isPercentage || _selectedChartType == ShareAssetChartType.totalProfit) 
          ? yAxisFormat 
          : (asset.subType == AssetSubType.mutualFund
            ? NumberFormat("0.0000")
            : (asset.subType == AssetSubType.etf ? NumberFormat("0.000") : NumberFormat("0.00")));
        
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

        // ★★★ 修复点: 统一阈值并修正变量名 ★★★
        final bool showDots = spots.length < 40;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chartTitle, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // (*** 4. 新增：切换按钮 ***)
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SegmentedButton<ShareAssetChartType>(
                        segments: const [
                          ButtonSegment(value: ShareAssetChartType.price, label: Text('价格'), icon: Icon(Icons.timeline)),
                          ButtonSegment(value: ShareAssetChartType.totalProfit, label: Text('收益'), icon: Icon(Icons.trending_up)),
                          ButtonSegment(value: ShareAssetChartType.profitRate, label: Text('收益率'), icon: Icon(Icons.percent)),
                        ],
                        selected: {_selectedChartType},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedChartType = newSelection.first;
                          });
                        },
                        showSelectedIcon: constraints.maxWidth >= 360,
                      );
                    }
                  ),
                ),
                const SizedBox(height: 24),
                
                // (*** 5. 动态图表 ***)
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
                          // ★★★ 修复点: 应用新的布尔值 ★★★
                          dotData: FlDotData(show: showDots), 
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 50, 
                          getTitlesWidget: (value, meta) => Text(
                              yAxisFormat.format(value), 
                              style: const TextStyle(fontSize: 10)),
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
                                final date = DateTime.fromMillisecondsSinceEpoch(spots[index].x.toInt()); 
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('yy-MM-dd').format(date),
                                    style: const TextStyle(fontSize: 10), 
                                    textAlign: TextAlign.center,
                                  ),
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
                              
                              final originalSpot = spots[index]; 
                              final date = DateFormat('yyyy-MM-dd')
                                  .format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                              
                              // (*** 6. 动态工具提示 ***)
                              final String valueStr;
                              if (isPercentage) {
                                valueStr = (NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2).format(originalSpot.y);
                              } else if (_selectedChartType == ShareAssetChartType.totalProfit) {
                                valueStr = formatCurrency(originalSpot.y, asset.currency);
                              } else {
                                valueStr = tooltipFormat.format(originalSpot.y);
                              }

                              return LineTooltipItem(
                                '$date\n$valueStr', 
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
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
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      )),
      error: (e, s) => Text('图表加载失败: $e'),
    );
  }
}
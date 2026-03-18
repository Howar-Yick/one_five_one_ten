// 文件: lib/pages/share_asset_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_result.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_step.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/snapshot_history_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';

class ShareAssetDetailPage extends ConsumerStatefulWidget {
  final int assetId;
  const ShareAssetDetailPage({super.key, required this.assetId});

  @override
  ConsumerState<ShareAssetDetailPage> createState() =>
      _ShareAssetDetailPageState();
}

class _ShareAssetDetailPageState extends ConsumerState<ShareAssetDetailPage> {
  @override
  Widget build(BuildContext context) {
    final asyncAsset = ref.watch(shareAssetDetailProvider(widget.assetId));
    final asyncPerformance =
        ref.watch(shareAssetPerformanceProvider(widget.assetId));

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
                  final parentAccount = await isar.accounts
                      .where()
                      .filter()
                      .supabaseIdEqualTo(asset.accountSupabaseId)
                      .findFirst();

                  if (parentAccount != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEditAssetPage(
                            accountId: parentAccount.id, assetId: asset.id),
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('错误：找不到父账户')));
                  }
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
              ref.invalidate(shareAssetPerformanceProvider(widget.assetId));
              ref.invalidate(shareAssetCombinedChartProvider(widget.assetId));
            },
            child: _ShareAssetDetailView(
              asset: asset,
              performanceAsync: asyncPerformance,
            ),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.sync_alt),
            tooltip: '更新持仓快照',
            onPressed: () {
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

  void _showUpdateSnapshotDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
    final performance = ref.read(shareAssetPerformanceProvider(asset.id));
    final sharesController = TextEditingController(
        text: performance.asData?.value['totalShares']?.toString() ?? '');
    final costController = TextEditingController(
        text: performance.asData?.value['averageCost']?.toString() ?? '');
    final comprehensiveProfitController = TextEditingController(
      text: performance.asData?.value['comprehensiveProfit']?.toString() ?? '',
    );
    final fxRateController = TextEditingController();
    final costCnyController = TextEditingController();
    final priceController = TextEditingController(
        text: asset.latestPrice > 0 ? asset.latestPrice.toString() : '');
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
                    TextField(
                        controller: sharesController,
                        decoration: const InputDecoration(labelText: '最新总份额'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    TextField(
                        controller: costController,
                        decoration: InputDecoration(
                            labelText: '最新单位成本',
                            prefixText: getCurrencySymbol(asset.currency)),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    TextField(
                        controller: priceController,
                        decoration: InputDecoration(
                            labelText: '最新价格 (可选)',
                            prefixText: getCurrencySymbol(asset.currency)),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    TextField(
                      controller: comprehensiveProfitController,
                      decoration: InputDecoration(
                        labelText: '综合收益（券商口径）',
                        helperText: '仅录入综合收益，持仓收益和实现盈亏将自动计算',
                        prefixText: getCurrencySymbol(asset.currency),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (asset.currency != 'CNY') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: fxRateController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: '汇率（资产币种→CNY，可选）',
                          helperText: '用于记录快照成本对应的人民币成本',
                        ),
                        onChanged: (_) {
                          final cost = double.tryParse(costController.text);
                          final fx = double.tryParse(fxRateController.text);
                          if (cost != null &&
                              fx != null &&
                              sharesController.text.isNotEmpty) {
                            final shares =
                                double.tryParse(sharesController.text);
                            if (shares != null) {
                              costCnyController.text =
                                  (cost * shares * fx).toStringAsFixed(2);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: costCnyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: '人民币成本（可选）',
                          helperText: '记录该快照对应的累计人民币成本',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text("快照日期:", style: TextStyle(fontSize: 16)),
                        const Spacer(),
                        TextButton(
                          child: Text(
                              DateFormat('yyyy-MM-dd').format(selectedDate)),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now());
                            if (pickedDate != null)
                              setState(() => selectedDate = pickedDate);
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
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    final priceText = priceController.text.trim();
                    final comprehensiveProfit = double.tryParse(
                        comprehensiveProfitController.text.trim());

                    if (shares == null || cost == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入有效的份额和成本')));
                      }
                      return;
                    }

                    try {
                      final syncService = ref.read(syncServiceProvider);

                      bool assetUpdated = false;
                      if (priceText.isNotEmpty) {
                        asset.latestPrice =
                            double.tryParse(priceText) ?? asset.latestPrice;
                        asset.priceUpdateDate = DateTime.now();
                        assetUpdated = true;
                      }

                      double? fxRate;
                      double? costCny;
                      if (asset.currency != 'CNY') {
                        fxRate = double.tryParse(fxRateController.text);
                        costCny = double.tryParse(costCnyController.text);
                        if (fxRate != null && costCny == null) {
                          costCny = shares * cost * fxRate;
                        }
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..assetSupabaseId = asset.supabaseId
                        ..fxRateToCny = fxRate
                        ..costBasisCny = costCny
                        ..brokerComprehensiveProfit = comprehensiveProfit;

                      await syncService.savePositionSnapshot(newSnapshot);

                      if (assetUpdated) {
                        await syncService.saveAsset(asset);
                      }

                      ref.invalidate(shareAssetPerformanceProvider(asset.id));
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }

                      if (context.mounted) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              SnapshotHistoryPage(assetId: asset.id),
                        ));
                      }
                    } catch (e) {
                      print('更新快照失败: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
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
}

class _ShareAssetDetailView extends ConsumerStatefulWidget {
  final Asset asset;
  final AsyncValue<Map<String, dynamic>> performanceAsync;

  const _ShareAssetDetailView({
    required this.asset,
    required this.performanceAsync,
  });

  @override
  ConsumerState<_ShareAssetDetailView> createState() =>
      _ShareAssetDetailViewState();
}

class _ShareAssetDetailViewState extends ConsumerState<_ShareAssetDetailView> {
  ShareAssetChartType _selectedChartType = ShareAssetChartType.price;

  @override
  Widget build(BuildContext context) {
    return widget.performanceAsync.when(
      data: (performance) {
        final String latestPriceString =
            formatPrice(widget.asset.latestPrice, widget.asset.subType);
        final String avgCostString = formatPrice(
            performance['averageCost'] ?? 0.0, widget.asset.subType);
        final double holdingProfit =
            (performance['holdingProfit'] ?? 0.0) as double;
        final double realizedProfit =
            (performance['realizedProfit'] ?? 0.0) as double;
        final double comprehensiveProfit =
            (performance['comprehensiveProfit'] ??
                performance['totalProfit'] ??
                0.0) as double;

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
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
                            Text(
                                formatCurrency(
                                    performance['marketValue'] ?? 0.0,
                                    widget.asset.currency),
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            Text('当前市值',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(latestPriceString,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            Text(
                                widget.asset.priceUpdateDate != null
                                    ? DateFormat('MM-dd HH:mm')
                                        .format(widget.asset.priceUpdateDate!)
                                    : '未更新',
                                style: Theme.of(context).textTheme.bodySmall),
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
                    _buildMetricRow(context, '当前份额:',
                        (performance['totalShares'] ?? 0.0).toString()),
                    _buildMetricRow(
                        context,
                        '持仓成本:',
                        formatCurrency(performance['totalCost'] ?? 0.0,
                            widget.asset.currency)),
                  ],
                ),
              ),
            ),
            _buildPerformanceCard(context, performance, widget.asset.currency),
            _buildProfitStructureCard(
              context,
              holdingProfit,
              realizedProfit,
              comprehensiveProfit,
              widget.asset.currency,
            ),
            _buildGridProfitSummaryCard(
                context, widget.asset.id, widget.asset.currency),
            _buildChartCard(context, widget.asset), // 渲染正确的图表组件
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                TextButton(
                  child: const Text('查看持仓快照历史'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          SnapshotHistoryPage(assetId: widget.asset.id),
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('加载性能数据失败: $e')),
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

  Widget _buildPerformanceCard(BuildContext context,
      Map<String, dynamic> performance, String currencyCode) {
    final double holdingProfit =
        (performance['holdingProfit'] ?? 0.0) as double;
    final double holdingProfitRate =
        (performance['holdingProfitRate'] ?? 0.0) as double;
    final double realizedProfit =
        (performance['realizedProfit'] ?? 0.0) as double;
    final double realizedProfitRate =
        (performance['realizedProfitRate'] ?? 0.0) as double;
    final double comprehensiveProfit = (performance['comprehensiveProfit'] ??
        performance['totalProfit'] ??
        0.0) as double;
    final double comprehensiveProfitRate =
        (performance['comprehensiveProfitRate'] ??
            performance['profitRate'] ??
            0.0) as double;
    final double annualizedReturn =
        (performance['annualizedReturn'] ?? 0.0) as double;

    final percentFormat = NumberFormat.percentPattern('zh_CN')
      ..maximumFractionDigits = 2;

    Color pnlColor(double value) {
      if (value > 0) return Colors.red.shade400;
      if (value < 0) return Colors.green.shade400;
      return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('业绩概览（证券份额法）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '口径统一：综合收益 = 持仓收益 + 实现盈亏',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            _buildMetricRow(
              context,
              '持仓收益:',
              '${formatCurrency(holdingProfit, currencyCode)} (${percentFormat.format(holdingProfitRate)})',
              color: pnlColor(holdingProfit),
            ),
            _buildMetricRow(
              context,
              '实现盈亏:',
              '${formatCurrency(realizedProfit, currencyCode)} (${percentFormat.format(realizedProfitRate)})',
              color: pnlColor(realizedProfit),
            ),
            _buildMetricRow(
              context,
              '综合收益:',
              '${formatCurrency(comprehensiveProfit, currencyCode)} (${percentFormat.format(comprehensiveProfitRate)})',
              color: pnlColor(comprehensiveProfit),
            ),
            const Divider(height: 24),
            _buildMetricRow(
              context,
              'XIRR年化(估算):',
              percentFormat.format(annualizedReturn),
              color: pnlColor(annualizedReturn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridProfitSummaryCard(
    BuildContext context,
    int assetId,
    String currencyCode,
  ) {
    Color pnlColor(double value) {
      if (value > 0) return Colors.red.shade400;
      if (value < 0) return Colors.green.shade400;
      return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

    final debugAsync = ref.watch(gridProfitDebugProvider(assetId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: debugAsync.when(
          data: (data) {
            final snapshots = (data['snapshots'] as List<PositionSnapshot>?) ??
                const <PositionSnapshot>[];
            if (snapshots.length < 2) {
              return const Text(
                '网格利润重构：快照不足',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              );
            }

            final result = data['result'] as GridProfitReconstructionResult;
            final double cumulativeGridProfit = result.cumulativeGridProfit;
            final double costReductionPerShare =
                result.gridCostReductionPerShare;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '网格利润重构摘要',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildMetricRow(
                  context,
                  '重构网格利润:',
                  NumberFormat.currency(
                    locale: 'zh_CN',
                    symbol: getCurrencySymbol(currencyCode),
                    decimalDigits: 2,
                  ).format(cumulativeGridProfit),
                  color: pnlColor(cumulativeGridProfit),
                ),
                _buildMetricRow(
                  context,
                  '每份额降本:',
                  NumberFormat('#,##0.000').format(costReductionPerShare),
                  color: pnlColor(costReductionPerShare),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, s) => Text(
            '网格利润重构：加载失败',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfitStructureCard(
    BuildContext context,
    double holdingProfit,
    double realizedProfit,
    double comprehensiveProfit,
    String currencyCode,
  ) {
    Color pnlColor(double value) {
      if (value > 0) return Colors.red.shade400;
      if (value < 0) return Colors.green.shade400;
      return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    }

    final bool isOppositeSign = (holdingProfit * realizedProfit) < 0;

    final double holdingAbs = holdingProfit.abs();
    final double realizedAbs = realizedProfit.abs();
    final double totalAbs = holdingAbs + realizedAbs;

    final double holdingRatio = totalAbs == 0 ? 0.0 : (holdingAbs / totalAbs);
    final double realizedRatio = totalAbs == 0 ? 0.0 : (realizedAbs / totalAbs);

    final double hedgeRatio =
        holdingAbs == 0 ? 0.0 : (realizedAbs / holdingAbs).clamp(0.0, 1.0);
    final double remainRatio = (1.0 - hedgeRatio).clamp(0.0, 1.0);

    String summaryText;
    if (!isOppositeSign) {
      summaryText =
          '持仓收益占比：${(holdingRatio * 100).toStringAsFixed(1)}%\n实现盈亏占比：${(realizedRatio * 100).toStringAsFixed(1)}%';
    } else if (holdingProfit < 0 && realizedProfit > 0) {
      summaryText = '已实现盈利抵消了持仓亏损的 ${(hedgeRatio * 100).toStringAsFixed(1)}%';
    } else {
      summaryText = '已实现亏损侵蚀了持仓盈利的 ${(hedgeRatio * 100).toStringAsFixed(1)}%';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '收益结构',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '综合收益 = 持仓收益 + 实现盈亏',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '持仓收益 ${formatCurrency(holdingProfit, currencyCode)}',
                    style: TextStyle(color: pnlColor(holdingProfit)),
                  ),
                ),
                Expanded(
                  child: Text(
                    '实现盈亏 ${formatCurrency(realizedProfit, currencyCode)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: pnlColor(realizedProfit)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (!isOppositeSign) ...[
                      Expanded(
                        flex:
                            ((holdingRatio * 1000).round().clamp(1, 999) as num)
                                .toInt(),
                        child: Container(color: Colors.blueGrey.shade300),
                      ),
                      Expanded(
                        flex: ((realizedRatio * 1000).round().clamp(1, 999)
                                as num)
                            .toInt(),
                        child: Container(color: Colors.orange.shade300),
                      ),
                    ] else ...[
                      Expanded(
                        flex: ((hedgeRatio * 1000).round().clamp(1, 999) as num)
                            .toInt(),
                        child: Container(color: Colors.teal.shade300),
                      ),
                      Expanded(
                        flex:
                            ((remainRatio * 1000).round().clamp(1, 999) as num)
                                .toInt(),
                        child: Container(color: Colors.blueGrey.shade300),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summaryText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '综合收益：${formatCurrency(comprehensiveProfit, currencyCode)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ★★★ 唯一的、完全包含所有逻辑的完美版图表构建方法 ★★★
  Widget _buildChartCard(BuildContext context, Asset asset) {
    final asyncChartData = ref.watch(shareAssetCombinedChartProvider(asset.id));
    final debugAsync = ref.watch(gridProfitDebugProvider(asset.id));

    return asyncChartData.when(
      data: (chartDataMap) {
        List<FlSpot> spots;
        String chartTitle;
        bool isPercentage = false;
        String modeLabel = '价格模式';
        final List<FlSpot> comprehensiveSpots =
            chartDataMap['comprehensiveProfit'] ?? [];
        final List<FlSpot> holdingSpots = chartDataMap['holdingProfit'] ?? [];
        final List<FlSpot> realizedSpots = chartDataMap['realizedProfit'] ?? [];

        switch (_selectedChartType) {
          case ShareAssetChartType.comprehensiveProfit:
            spots = comprehensiveSpots;
            chartTitle = '综合收益趋势';
            modeLabel = '当前：综合收益曲线';
            break;
          case ShareAssetChartType.holdingProfit:
            spots = holdingSpots;
            chartTitle = '持仓收益趋势';
            modeLabel = '当前：持仓收益曲线';
            break;
          case ShareAssetChartType.realizedProfit:
            spots = realizedSpots;
            chartTitle = '实现盈亏趋势';
            modeLabel = '当前：实现盈亏曲线';
            break;
          case ShareAssetChartType.price:
          default:
            spots = chartDataMap['price'] ?? [];
            chartTitle = (asset.subType == AssetSubType.mutualFund)
                ? '单位净值历史'
                : '价格历史 (日K收盘)';
            modeLabel = '当前：价格曲线';
            break;
        }

        if (spots.length < 2) return const SizedBox.shrink();

        final GridProfitReconstructionResult? reconstructionResult = debugAsync
            .asData?.value['result'] as GridProfitReconstructionResult?;
        final List<GridProfitReconstructionStep> reconstructionSteps =
            reconstructionResult?.steps ??
                const <GridProfitReconstructionStep>[];
        final bool showAdjustedCostLine =
            _selectedChartType == ShareAssetChartType.price &&
                reconstructionSteps.isNotEmpty;

        DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

        final List<GridProfitReconstructionStep> sortedSteps =
            reconstructionSteps.toList()
              ..sort((a, b) => dateOnly(a.date).compareTo(dateOnly(b.date)));

        final List<FlSpot> adjustedCostOriginalSpots = <FlSpot>[];
        final List<GridProfitReconstructionStep?> activeStepsForSpots = [];

        final Map<int, GridProfitReconstructionStep> stepByDayMap = {
          for (final step in sortedSteps)
            dateOnly(step.date).millisecondsSinceEpoch: step,
        };

        for (final spot in spots) {
          final int spotDayEpoch =
              dateOnly(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))
                  .millisecondsSinceEpoch;

          GridProfitReconstructionStep? matchedStep;
          double? adjustedCost;

          if (stepByDayMap.containsKey(spotDayEpoch)) {
            matchedStep = stepByDayMap[spotDayEpoch];
          } else {
            for (int i = sortedSteps.length - 1; i >= 0; i--) {
              final stepDayEpoch =
                  dateOnly(sortedSteps[i].date).millisecondsSinceEpoch;
              if (stepDayEpoch <= spotDayEpoch) {
                matchedStep = sortedSteps[i];
                break;
              }
            }
          }

          if (matchedStep != null && matchedStep.shares > 0) {
            adjustedCost = matchedStep.netCapital / matchedStep.shares;
            if (!adjustedCost.isFinite) adjustedCost = null;
          }

          activeStepsForSpots.add(matchedStep);
          adjustedCostOriginalSpots.add(
            FlSpot(spot.x, adjustedCost ?? double.nan),
          );
        }

        // ★ 核心修复：强制打穿地板的 min/max 逻辑
        double minY = double.infinity;
        double maxY = double.negativeInfinity;

        for (final spot in spots) {
          if (spot.y.isFinite) {
            if (spot.y < minY) minY = spot.y;
            if (spot.y > maxY) maxY = spot.y;
          }
        }

        if (showAdjustedCostLine) {
          for (final spot in adjustedCostOriginalSpots) {
            if (spot.y.isFinite) {
              if (spot.y < minY) minY = spot.y;
              if (spot.y > maxY) maxY = spot.y;
            }
          }
        }

        if (minY == double.infinity || maxY == double.negativeInfinity) {
          minY = 0;
          maxY = 1;
        } else {
          final padding = (maxY - minY) * 0.1;
          minY -= padding;
          maxY += padding;
        }

        final NumberFormat yAxisFormat;
        if (isPercentage) {
          yAxisFormat = NumberFormat.percentPattern('zh_CN')
            ..maximumFractionDigits = 1;
        } else if (_selectedChartType ==
                ShareAssetChartType.comprehensiveProfit ||
            _selectedChartType == ShareAssetChartType.holdingProfit ||
            _selectedChartType == ShareAssetChartType.realizedProfit) {
          yAxisFormat = NumberFormat.compactCurrency(
              locale: 'zh_CN', symbol: getCurrencySymbol(asset.currency));
        } else {
          yAxisFormat = (asset.subType == AssetSubType.mutualFund)
              ? NumberFormat("0.0000")
              : (asset.subType == AssetSubType.etf
                  ? NumberFormat("0.000")
                  : NumberFormat("0.00"));
        }

        final tooltipFormat = (isPercentage ||
                _selectedChartType == ShareAssetChartType.comprehensiveProfit ||
                _selectedChartType == ShareAssetChartType.holdingProfit ||
                _selectedChartType == ShareAssetChartType.realizedProfit)
            ? yAxisFormat
            : (asset.subType == AssetSubType.mutualFund
                ? NumberFormat("0.0000")
                : (asset.subType == AssetSubType.etf
                    ? NumberFormat("0.000")
                    : NumberFormat("0.00")));

        final colorScheme = Theme.of(context).colorScheme;

        final List<FlSpot> indexedSpots = [];
        final List<FlSpot> indexedAdjustedCostSpots = [];
        for (int i = 0; i < spots.length; i++) {
          indexedSpots.add(FlSpot(i.toDouble(), spots[i].y));
          final adjustedY = adjustedCostOriginalSpots[i].y;
          indexedAdjustedCostSpots.add(FlSpot(i.toDouble(), adjustedY));
        }

        double bottomInterval;
        const desiredLabelCount = 4.0;
        if (spots.length <= desiredLabelCount) {
          bottomInterval = 1;
        } else {
          bottomInterval = (spots.length - 1) / desiredLabelCount;
          if (bottomInterval < 1) bottomInterval = 1;
        }

        final bool showDots = spots.length < 40;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chartTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Center(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return SegmentedButton<ShareAssetChartType>(
                      segments: const [
                        ButtonSegment(
                            value: ShareAssetChartType.price,
                            label: Text('价格'),
                            icon: Icon(Icons.timeline)),
                        ButtonSegment(
                            value: ShareAssetChartType.comprehensiveProfit,
                            label: Text('综合收益'),
                            icon: Icon(Icons.multiline_chart)),
                        ButtonSegment(
                            value: ShareAssetChartType.holdingProfit,
                            label: Text('持仓收益'),
                            icon: Icon(Icons.show_chart)),
                        ButtonSegment(
                            value: ShareAssetChartType.realizedProfit,
                            label: Text('实现盈亏'),
                            icon: Icon(Icons.trending_up)),
                      ],
                      selected: {_selectedChartType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedChartType = newSelection.first;
                        });
                      },
                      showSelectedIcon: constraints.maxWidth >= 360,
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 10, height: 10, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(modeLabel,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                    if (showAdjustedCostLine)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '网格降本线（Adjusted Cost Line）',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: indexedSpots,
                          isCurved: false,
                          barWidth: 3,
                          color: colorScheme.primary,
                          dotData: FlDotData(show: showDots),
                          belowBarData: BarAreaData(show: false),
                        ),
                        if (showAdjustedCostLine)
                          LineChartBarData(
                            spots: indexedAdjustedCostSpots,
                            isCurved: false,
                            barWidth: 2,
                            color: Colors.greenAccent.shade400,
                            //dashArray: const [8, 4],
                            dotData: FlDotData(show: showDots),
                            belowBarData: BarAreaData(show: false),
                          ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) => Text(
                              yAxisFormat.format(value),
                              style: const TextStyle(fontSize: 10)),
                        )),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: bottomInterval,
                                getTitlesWidget: (value, meta) {
                                  final int index = value.toInt();
                                  if (index >= 0 && index < spots.length) {
                                    final date =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            spots[index].x.toInt());
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
                                })),
                      ),
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.2),
                              strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: colorScheme.outline.withOpacity(0.5),
                                strokeWidth: 1,
                                dashArray: const [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, spotIndex) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: bar.color ?? colorScheme.primary,
                                    strokeColor: Colors.white,
                                    strokeWidth: 1.5,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                        touchTooltipData: LineTouchTooltipData(
                          tooltipHorizontalAlignment: FLHorizontalAlignment
                              .left, // 将弹窗右边缘对齐鼠标（即弹窗整体悬浮在鼠标的【左侧】）
                          tooltipHorizontalOffset: -20,
                          tooltipMargin: 0, // 取消向上的默认推移，让它和鼠标保持在同一水平高度
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (touchedSpotsList) {
                            if (touchedSpotsList.isEmpty) return [];

                            final primarySpot = touchedSpotsList.first;
                            final int index = primarySpot.x.round();
                            if (index < 0 || index >= spots.length) return [];

                            final originalSpot = spots[index];
                            final date = DateFormat('yyyy-MM-dd').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                    originalSpot.x.toInt()));

                            if (_selectedChartType ==
                                ShareAssetChartType.price) {
                              final latestPriceText =
                                  '🔵 最新价格: ¥${tooltipFormat.format(originalSpot.y)}';
                              final adjustedCostValue =
                                  adjustedCostOriginalSpots[index].y;
                              final adjustedCostText = adjustedCostValue
                                      .isFinite
                                  ? '🟢 降本后成本: ¥${tooltipFormat.format(adjustedCostValue)}'
                                  : '🟢 降本后成本: —';

                              final step = activeStepsForSpots[index];
                              final profitText = step == null
                                  ? ''
                                  : '\n💡 累计网格利润: ${formatCurrency(step.cumulativeGridProfit, asset.currency)}';

                              final item = LineTooltipItem(
                                '$date\n$latestPriceText\n$adjustedCostText$profitText',
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.45),
                              );
                              return touchedSpotsList
                                  .map((e) => e == primarySpot ? item : null)
                                  .toList();
                            } else {
                              final val = formatCurrency(
                                  originalSpot.y, asset.currency);
                              final comp = index < comprehensiveSpots.length
                                  ? comprehensiveSpots[index].y
                                  : null;
                              final hold = index < holdingSpots.length
                                  ? holdingSpots[index].y
                                  : null;
                              final real = index < realizedSpots.length
                                  ? realizedSpots[index].y
                                  : null;

                              final compStr = comp == null
                                  ? '—'
                                  : formatCurrency(comp, asset.currency);
                              final holdStr = hold == null
                                  ? '—'
                                  : formatCurrency(hold, asset.currency);
                              final realStr = real == null
                                  ? '—'
                                  : formatCurrency(real, asset.currency);

                              final item = LineTooltipItem(
                                '$date\n$val\n综合收益: $compStr\n持仓收益: $holdStr\n实现盈亏: $realStr',
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.45),
                              );
                              return touchedSpotsList
                                  .map((e) => e == primarySpot ? item : null)
                                  .toList();
                            }
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
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      )),
      error: (e, s) => Text('图表加载失败: $e'),
    );
  }
}

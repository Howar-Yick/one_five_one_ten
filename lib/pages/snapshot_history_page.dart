// 文件: lib/pages/snapshot_history_page.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/utils/number_formatter.dart';

class SnapshotHistoryPage extends ConsumerWidget {
  final int assetId;
  const SnapshotHistoryPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAsset = ref.watch(shareAssetDetailProvider(assetId));
    final historyAsync = ref.watch(snapshotHistoryProvider(assetId));
    final priceHistoryAsync = ref.watch(assetHistoryChartProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓快照历史'),
      ),
      body: asyncAsset.when(
        data: (asset) {
          if (asset == null) {
            return const Center(child: Text('未找到资产'));
          }

          final currencyCode = asset.currency;
          final priceSpots = priceHistoryAsync.asData?.value ?? const <FlSpot>[];
          final bool hasPriceData = priceSpots.isNotEmpty;

          return historyAsync.when(
            data: (snapshots) {
              if (snapshots.isEmpty) {
                return const Center(child: Text('暂无快照记录'));
              }

              return ListView.builder(
                itemCount: snapshots.length,
                itemBuilder: (context, index) {
                  final snapshot = snapshots[index];
                  final pnl = _buildSnapshotPnl(snapshot, priceSpots);
                  return _buildSnapshotTile(
                    context,
                    ref,
                    snapshot,
                    currencyCode,
                    asset,
                    pnl,
                    showPriceFallbackHint: !hasPriceData,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('加载失败: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: asyncAsset.when(
        data: (asset) => asset == null
            ? const SizedBox.shrink()
            : FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () => _showUpdateSnapshotDialog(context, ref, asset),
              ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  _SnapshotPnlViewModel _buildSnapshotPnl(
    PositionSnapshot snapshot,
    List<FlSpot> priceSpots,
  ) {
    final double? price = _findPriceOnOrBeforeDate(snapshot.date, priceSpots);

    final double? holdingProfit = price == null
        ? null
        : (price * snapshot.totalShares) -
            (snapshot.averageCost * snapshot.totalShares);

    final double? comprehensiveProfitFromSnapshot =
        snapshot.brokerComprehensiveProfit;
    final double? comprehensiveProfit = comprehensiveProfitFromSnapshot ??
        holdingProfit; // 与详情页口径一致：缺失时回退持仓收益

    final double? realizedProfit =
        (comprehensiveProfit != null && holdingProfit != null)
            ? (comprehensiveProfit - holdingProfit)
            : null;

    return _SnapshotPnlViewModel(
      holdingProfit: holdingProfit,
      comprehensiveProfit: comprehensiveProfit,
      realizedProfit: realizedProfit,
      hasSnapshotComprehensive: comprehensiveProfitFromSnapshot != null,
      hasMatchedPrice: price != null,
    );
  }

  double? _findPriceOnOrBeforeDate(DateTime date, List<FlSpot> priceSpots) {
    if (priceSpots.isEmpty) return null;

    final target = DateTime(date.year, date.month, date.day);
    final sorted = priceSpots.toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    double? matchedPrice;
    for (final spot in sorted) {
      final spotDate = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      final spotDay = DateTime(spotDate.year, spotDate.month, spotDate.day);
      if (spotDay.isAfter(target)) break;
      matchedPrice = spot.y;
    }
    return matchedPrice;
  }

  Widget _buildSnapshotTile(
    BuildContext context,
    WidgetRef ref,
    PositionSnapshot snapshot,
    String currencyCode,
    Asset asset,
    _SnapshotPnlViewModel pnl, {
    required bool showPriceFallbackHint,
  }) {
    final unitCostText = formatSnapshotUnitCost(snapshot.averageCost, asset);
    final dateText = DateFormat('yyyy-MM-dd').format(snapshot.date);

    Color pnlColor(double value) {
      if (value > 0) return Colors.red.shade400;
      if (value < 0) return Colors.green.shade400;
      return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    }

    String displayPnl(double? value) {
      if (value == null) return '—';
      return formatCurrency(value, currencyCode);
    }

    final List<Widget> subtitleLines = [
      Text('单位成本: ${getCurrencySymbol(currencyCode)}$unitCostText'),
      Text('份额: ${snapshot.totalShares.toStringAsFixed(2)}'),
      const SizedBox(height: 6),
      Text(
        '综合收益: ${displayPnl(pnl.comprehensiveProfit)}',
        style: TextStyle(
          color: pnl.comprehensiveProfit == null
              ? Theme.of(context).textTheme.bodyMedium?.color
              : pnlColor(pnl.comprehensiveProfit!),
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        '持仓收益: ${displayPnl(pnl.holdingProfit)}',
        style: TextStyle(
          color: pnl.holdingProfit == null
              ? Theme.of(context).textTheme.bodyMedium?.color
              : pnlColor(pnl.holdingProfit!),
        ),
      ),
      Text(
        '实现盈亏: ${displayPnl(pnl.realizedProfit)}',
        style: TextStyle(
          color: pnl.realizedProfit == null
              ? Theme.of(context).textTheme.bodyMedium?.color
              : pnlColor(pnl.realizedProfit!),
        ),
      ),
    ];

    if (currencyCode != 'CNY' && snapshot.costBasisCny != null) {
      subtitleLines.add(
        Text('人民币成本: ${formatCurrency(snapshot.costBasisCny!, 'CNY')}'),
      );
    }
    if (currencyCode != 'CNY' && snapshot.fxRateToCny != null) {
      subtitleLines.add(
        Text(
          '成本汇率: ${snapshot.fxRateToCny!.toStringAsFixed(4)} ($currencyCode→CNY)',
        ),
      );
    }

    if (!pnl.hasMatchedPrice) {
      subtitleLines.add(
        Text(
          showPriceFallbackHint
              ? '注：暂无历史价格，持仓收益/实现盈亏暂不可计算'
              : '注：该日期未匹配到历史价格，持仓收益/实现盈亏暂不可计算',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (!pnl.hasSnapshotComprehensive) {
      subtitleLines.add(
        Text(
          '注：综合收益缺失时按持仓收益回退展示',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.history_toggle_off),
        title: Text('快照日期: $dateText'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitleLines,
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '综合收益',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                displayPnl(pnl.comprehensiveProfit),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pnl.comprehensiveProfit == null
                      ? Theme.of(context).textTheme.bodyMedium?.color
                      : pnlColor(pnl.comprehensiveProfit!),
                ),
              ),
            ],
          ),
        ),
        onTap: () =>
            _showEditSnapshotDialog(context, ref, snapshot, currencyCode, asset),
        onLongPress: () => _showDeleteConfirmation(context, ref, snapshot),
      ),
    );
  }

  // ============== 编辑快照 ==============
  void _showEditSnapshotDialog(
    BuildContext context,
    WidgetRef ref,
    PositionSnapshot snapshot,
    String currencyCode,
    Asset asset,
  ) {
    final sharesController =
        TextEditingController(text: snapshot.totalShares.toString());
    final costController =
        TextEditingController(text: formatSnapshotUnitCost(snapshot.averageCost, asset));

    // 新增：汇率 / 人民币成本输入框
    final fxRateController = TextEditingController(
      text: snapshot.fxRateToCny?.toStringAsFixed(4) ?? '',
    );
    final cnyCostController = TextEditingController(
      text: snapshot.costBasisCny?.toStringAsFixed(2) ?? '',
    );

    DateTime selectedDate = snapshot.date;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑快照'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: sharesController,
                    decoration: const InputDecoration(labelText: '总份额'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: costController,
                    decoration: const InputDecoration(labelText: '单位成本'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (currencyCode != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      decoration: const InputDecoration(
                        labelText: '成本汇率（资产币种→CNY，可选）',
                        helperText: '留空则不记录汇率',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        final shares =
                            double.tryParse(sharesController.text.trim());
                        final cost =
                            double.tryParse(costController.text.trim());
                        final rate =
                            double.tryParse(fxRateController.text.trim());
                        if (shares != null && cost != null && rate != null) {
                          final cnyCost = shares * cost * rate;
                          cnyCostController.text =
                              cnyCost.toStringAsFixed(2);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnyCostController,
                      decoration: const InputDecoration(
                        labelText: '人民币成本（可选）',
                        helperText: '留空将按 份额×单位成本×汇率 推算',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("快照日期:"),
                      const Spacer(),
                      TextButton(
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
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
                    final shares =
                        double.tryParse(sharesController.text.trim());
                    final cost = double.tryParse(costController.text.trim());

                    if (shares == null || cost == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('请填写有效的份额和单位成本'),
                        ),
                      );
                      return;
                    }

                    snapshot.totalShares = shares;
                    snapshot.averageCost = cost;
                    snapshot.date = selectedDate;

                    if (currencyCode != 'CNY') {
                      final fxRate =
                          double.tryParse(fxRateController.text.trim());
                      double? cnyCost =
                          double.tryParse(cnyCostController.text.trim());

                      if (fxRate != null) {
                        snapshot.fxRateToCny = fxRate;
                        if (cnyCost == null) {
                          cnyCost = shares * cost * fxRate;
                        }
                      } else {
                        snapshot.fxRateToCny = null;
                      }
                      snapshot.costBasisCny = cnyCost;
                    } else {
                      snapshot.fxRateToCny = null;
                      snapshot.costBasisCny = null;
                    }

                    await ref
                        .read(syncServiceProvider)
                        .savePositionSnapshot(snapshot);

                    ref.invalidate(shareAssetPerformanceProvider(assetId));
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
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

  // ============== 新建快照 ==============
  void _showUpdateSnapshotDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
    final sharesController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController(
      text: asset.latestPrice > 0 ? asset.latestPrice.toString() : '',
    );

    // 新增：汇率 + 人民币成本
    final fxRateController = TextEditingController();
    final cnyCostController = TextEditingController();

    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新持仓快照'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: sharesController,
                    decoration: const InputDecoration(labelText: '最新总份额'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  TextField(
                    controller: costController,
                    decoration: const InputDecoration(labelText: '最新单位成本'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: '最新价格 (可选)',
                      prefixText: getCurrencySymbol(asset.currency),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  if (asset.currency != 'CNY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fxRateController,
                      decoration: const InputDecoration(
                        labelText: '成本汇率（资产币种→CNY，可选）',
                        helperText: '例 如 7.0749；留空则不记录汇率',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        final shares =
                            double.tryParse(sharesController.text.trim());
                        final cost =
                            double.tryParse(costController.text.trim());
                        final rate =
                            double.tryParse(fxRateController.text.trim());
                        if (shares != null && cost != null && rate != null) {
                          final cnyCost = shares * cost * rate;
                          cnyCostController.text =
                              cnyCost.toStringAsFixed(2);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnyCostController,
                      decoration: const InputDecoration(
                        labelText: '人民币成本（可选）',
                        helperText: '留空将按 份额×单位成本×汇率 推算',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
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
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
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
                    final shares =
                        double.tryParse(sharesController.text.trim());
                    final cost = double.tryParse(costController.text.trim());
                    final priceText = priceController.text.trim();

                    if (shares == null || cost == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('请填写有效的份额和单位成本')),
                      );
                      return;
                    }

                    final syncService = ref.read(syncServiceProvider);

                    bool assetUpdated = false;
                    if (priceText.isNotEmpty) {
                      asset.latestPrice =
                          double.tryParse(priceText) ?? asset.latestPrice;
                      asset.priceUpdateDate = DateTime.now();
                      assetUpdated = true;
                    }

                    double? fxRate;
                    double? cnyCost;
                    if (asset.currency != 'CNY') {
                      fxRate = double.tryParse(fxRateController.text.trim());
                      cnyCost = double.tryParse(cnyCostController.text.trim());
                      if (fxRate != null && cnyCost == null) {
                        cnyCost = shares * cost * fxRate;
                      }
                    }

                    final newSnapshot = PositionSnapshot()
                      ..totalShares = shares
                      ..averageCost = cost
                      ..date = selectedDate
                      ..createdAt = DateTime.now()
                      ..assetSupabaseId = asset.supabaseId
                      ..fxRateToCny = fxRate
                      ..costBasisCny = cnyCost;

                    await syncService.savePositionSnapshot(newSnapshot);

                    if (assetUpdated) {
                      await syncService.saveAsset(asset);
                    }

                    ref.invalidate(shareAssetPerformanceProvider(asset.id));
                    if (dialogContext.mounted) {
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

  // ============== 删除快照 ==============
  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    PositionSnapshot snapshot,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('您确定要删除这条快照吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final syncService = ref.read(syncServiceProvider);
              await syncService.deletePositionSnapshot(snapshot);

              ref.invalidate(snapshotHistoryProvider(assetId));
              ref.invalidate(shareAssetPerformanceProvider(assetId));

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
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
}

class _SnapshotPnlViewModel {
  final double? comprehensiveProfit;
  final double? holdingProfit;
  final double? realizedProfit;
  final bool hasSnapshotComprehensive;
  final bool hasMatchedPrice;

  const _SnapshotPnlViewModel({
    required this.comprehensiveProfit,
    required this.holdingProfit,
    required this.realizedProfit,
    required this.hasSnapshotComprehensive,
    required this.hasMatchedPrice,
  });
}

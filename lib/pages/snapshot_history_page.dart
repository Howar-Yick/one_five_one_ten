// 文件: lib/pages/snapshot_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// Providers & services
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

class SnapshotHistoryPage extends ConsumerWidget {
  final int assetId;
  const SnapshotHistoryPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAsset = ref.watch(shareAssetDetailProvider(assetId));
    final historyAsync = ref.watch(snapshotHistoryProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓快照历史'),
      ),
      body: historyAsync.when(
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return const Center(child: Text('暂无快照记录'));
          }
          final currencyCode = asyncAsset.asData?.value?.currency ?? 'CNY';
          return ListView.builder(
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              return _buildSnapshotTile(
                context,
                ref,
                snapshot,
                currencyCode,
              );
            },
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

  Widget _buildSnapshotTile(
    BuildContext context,
    WidgetRef ref,
    PositionSnapshot snapshot,
    String currencyCode,
  ) {
    final List<Widget> subtitleLines = [
      Text('单位成本: ${formatCurrency(snapshot.averageCost, currencyCode)}'),
      Text('份额: ${snapshot.totalShares.toStringAsFixed(2)}'),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.history_toggle_off),
        title: Text(
          '快照日期: ${DateFormat('yyyy-MM-dd').format(snapshot.date)}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitleLines,
        ),
        trailing: Text(
          DateFormat('yyyy-MM-dd').format(snapshot.date),
        ),
        onTap: () => _showEditSnapshotDialog(context, ref, snapshot, currencyCode),
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
  ) {
    final sharesController =
        TextEditingController(text: snapshot.totalShares.toString());
    final costController =
        TextEditingController(text: snapshot.averageCost.toStringAsFixed(4));

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

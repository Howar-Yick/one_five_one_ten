// 文件: lib/pages/archived_assets_page.dart
// (这是添加了缺失 import 的最终修复版本)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';
// ★★★ 修复点: 添加这两个缺失的 import ★★★
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';


class ArchivedAssetsPage extends ConsumerWidget {
  const ArchivedAssetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArchivedAssets = ref.watch(archivedAssetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('已清仓资产'),
      ),
      body: asyncArchivedAssets.when(
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(child: Text('没有已归档的资产'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(archivedAssetsProvider);
            },
            child: ListView.builder(
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final assetData = assets[index];
                final asset = assetData['asset'] as Asset;
                final accountName = assetData['accountName'] as String;

                final calculator = CalculatorService();
                final performanceFuture = asset.trackingMethod == AssetTrackingMethod.shareBased
                    ? calculator.calculateArchivedShareAssetPerformance(asset)
                    : calculator.calculateValueAssetPerformance(asset);

                return FutureBuilder<Map<String, dynamic>>(
                  future: performanceFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(asset.name),
                          subtitle: Text('所属账户: $accountName'),
                          trailing: const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(asset.name),
                          subtitle: Text('所属账户: $accountName'),
                          trailing: const Icon(Icons.error_outline, color: Colors.grey),
                          onTap: () => _showActionsDialog(context, ref, asset),
                        ),
                      );
                    }

                    final performance = snapshot.data!;
                    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
                    final double totalCost = (performance['totalCost'] ?? 0.0) as double;
                    final double profitRate = (performance['profitRate'] ?? 0.0) as double;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ShareAssetDetailPage(assetId: asset.id),
                            ));
                          } else {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ValueAssetDetailPage(assetId: asset.id),
                            ));
                          }
                        },
                        onLongPress: () => _showActionsDialog(context, ref, asset),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(asset.name, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('所属账户: $accountName', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildPerformanceColumn(
                                    '已实现盈亏',
                                    formatCurrency(totalProfit, asset.currency),
                                    totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade600,
                                  ),
                                  _buildPerformanceColumn(
                                    '总投入',
                                    formatCurrency(totalCost, asset.currency),
                                    Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                  _buildPerformanceColumn(
                                    '回报率',
                                    '${(profitRate * 100).toStringAsFixed(2)}%',
                                    totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade600,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildPerformanceColumn(String label, String value, Color? valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showActionsDialog(BuildContext context, WidgetRef ref, Asset asset) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(asset.name),
          content: const Text('您想对此资产执行什么操作？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                asset.isArchived = false;
                await ref.read(syncServiceProvider).saveAsset(asset);
                ref.invalidate(archivedAssetsProvider);
                ref.invalidate(trackedAssetsWithPerformanceProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已恢复资产: ${asset.name}')),
                  );
                }
              },
              child: const Text('恢复到持仓'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showDeleteConfirmationDialog(context, ref, asset);
              },
              child: const Text('彻底删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, WidgetRef ref, Asset asset) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('确认彻底删除 "${asset.name}"?'),
          content: const Text('此操作不可撤销，将永久抹掉此资产及其所有相关记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final syncService = ref.read(syncServiceProvider);
                final isar = ref.read(databaseServiceProvider).isar;

                try {
                  Navigator.of(dialogContext).pop(); // 先关闭对话框

                  if (asset.supabaseId != null) {
                    await isar.writeTxn(() async {
                      // 现在 isar.transactions 和 isar.positionSnapshots 可以被正确识别
                      final txs = await isar.transactions.filter().assetSupabaseIdEqualTo(asset.supabaseId).findAll();
                      for (final tx in txs) { await syncService.deleteTransaction(tx); }
                      
                      final snaps = await isar.positionSnapshots.filter().assetSupabaseIdEqualTo(asset.supabaseId).findAll();
                      for (final snap in snaps) { await syncService.deletePositionSnapshot(snap); }
                    });
                  }
                  await syncService.deleteAsset(asset);

                  ref.invalidate(archivedAssetsProvider);
                  ref.invalidate(dashboardDataProvider);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已彻底删除资产：${asset.name}')),
                    );
                  }
                } catch (e) {
                   if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('删除失败: $e')),
                    );
                  }
                }
              },
              child: const Text('确认删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
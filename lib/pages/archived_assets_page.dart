// 文件: lib/pages/archived_assets_page.dart
// (这是已更新交互逻辑的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';


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
                final performance = assetData['performance'] as Map<String, dynamic>;
                final accountName = assetData['accountName'] as String;
                
                final double realizedProfit = (performance['totalProfit'] ?? 0.0) as double;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(asset.name),
                    subtitle: Text('所属账户: $accountName'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency(realizedProfit, asset.currency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: realizedProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400,
                          ),
                        ),
                        const Text('已实现盈亏', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    // ★★★ 关键修改：单击进入详情页 ★★★
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
                    // ★★★ 关键修改：长按弹出操作菜单 ★★★
                    onLongPress: () => _showActionsDialog(context, ref, asset),
                  ),
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

  // (此函数及后续函数保持不变)
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
                Navigator.of(dialogContext).pop();
                final syncService = ref.read(syncServiceProvider);
                final isar = DatabaseService().isar;

                if (asset.supabaseId != null) {
                  final txs = await isar.transactions.where().filter().assetSupabaseIdEqualTo(asset.supabaseId).findAll();
                  final snaps = await isar.positionSnapshots.where().filter().assetSupabaseIdEqualTo(asset.supabaseId).findAll();
                  
                  for (final tx in txs) { await syncService.deleteTransaction(tx); }
                  for (final snap in snaps) { await syncService.deletePositionSnapshot(snap); }
                }
                
                await syncService.deleteAsset(asset); 

                ref.invalidate(archivedAssetsProvider);
                ref.invalidate(dashboardDataProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已彻底删除资产：${asset.name}')),
                  );
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
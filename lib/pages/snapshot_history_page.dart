// 文件: lib/pages/snapshot_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart'; // 引入Provider
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// 1. (*** 新增：导入 Providers 和新服务 ***)
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

class SnapshotHistoryPage extends ConsumerWidget {
  final int assetId;
  const SnapshotHistoryPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAsset = ref.watch(shareAssetDetailProvider(assetId));
    // 2. (*** 已修复 ***) 这个 provider 我们已在上一步修复，它现在是一个实时 Stream
    final historyAsync = ref.watch(snapshotHistoryProvider(assetId)); 

    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓快照历史'),
      ),
      body: historyAsync.when(
        // (*** 读取逻辑保持不变，它现在是实时的！ ***)
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return const Center(child: Text('暂无快照记录'));
          }
          return ListView.builder(
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              final currencyCode =
                  asyncAsset.asData?.value?.currency ?? 'CNY';
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
      // --- 悬浮操作按钮 (逻辑不变，但调用的函数已被修复) ---
      floatingActionButton: asyncAsset.when(
        data: (asset) => asset == null ? const SizedBox.shrink() : FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _showUpdateSnapshotDialog(context, ref, asset),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSnapshotTile(BuildContext context, WidgetRef ref,
      PositionSnapshot snapshot, String currencyCode) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final showCostCny = currencyCode != 'CNY' && snapshot.costBasisCny != null;
    final showFxRate =
        currencyCode != 'CNY' && (snapshot.fxRateToCny != null && snapshot.fxRateToCny! > 0);

    final List<Widget> subtitleLines = [
      Text(
        '单位成本: ${formatCurrency(snapshot.averageCost, currencyCode)}',
        style: subtitleStyle,
      ),
      Text('份额: ${snapshot.totalShares.toStringAsFixed(2)}',
          style: subtitleStyle),
    ];

    if (showFxRate) {
      subtitleLines.add(
        Text(
          '成本汇率: ${snapshot.fxRateToCny!.toStringAsFixed(4)} ($currencyCode→CNY)',
          style: subtitleStyle,
        ),
      );
    }
    if (showCostCny) {
      subtitleLines.add(
        Text(
          '人民币成本: ${formatCurrency(snapshot.costBasisCny!, 'CNY')}',
          style: subtitleStyle,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.history_toggle_off),
        title: Text('快照日期: ${DateFormat('yyyy-MM-dd').format(snapshot.date)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitleLines,
        ),
        trailing: Text(DateFormat('yyyy-MM-dd').format(snapshot.date)),
        onTap: () => _showEditSnapshotDialog(context, ref, snapshot),
        onLongPress: () => _showDeleteConfirmation(context, ref, snapshot),
      ),
    );
  }

  // 3. (*** 关键修复：编辑逻辑 ***)
  void _showEditSnapshotDialog(BuildContext context, WidgetRef ref, PositionSnapshot snapshot) {
    final sharesController = TextEditingController(text: snapshot.totalShares.toString());
    final costController = TextEditingController(text: snapshot.averageCost.toString());
    DateTime selectedDate = snapshot.date;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑快照'),
              content: Column(
                // (UI 保持不变)
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: sharesController, decoration: const InputDecoration(labelText: '总份额')),
                  TextField(controller: costController, decoration: const InputDecoration(labelText: '单位成本')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("快照日期:"),
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
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    if (shares != null && cost != null) {
                      
                      // 4. (修改) 更新本地对象
                      snapshot.totalShares = shares;
                      snapshot.averageCost = cost;
                      snapshot.date = selectedDate;

                      // 5. (关键) 使用 SyncService 保存更新
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.savePositionSnapshot(snapshot); 
                      // (旧的 isar.writeTxn 已删除)
                      
                      ref.invalidate(shareAssetPerformanceProvider(assetId));
                      // (invalidate snapshotHistoryProvider 不再需要，因为它是 Stream)
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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

  // 6. (*** 关键修复：创建逻辑 ***)
  void _showUpdateSnapshotDialog(BuildContext context, WidgetRef ref, Asset asset) {
    // (这个函数与 share_asset_detail_page 中的完全相同)
    final sharesController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController(text: asset.latestPrice > 0 ? asset.latestPrice.toString() : '');
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新持仓快照'),
              content: Column(
                // (UI 保持不变)
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: sharesController, decoration: const InputDecoration(labelText: '最新总份额'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  TextField(controller: costController, decoration: const InputDecoration(labelText: '最新单位成本'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: '最新价格 (可选)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final shares = double.tryParse(sharesController.text);
                    final cost = double.tryParse(costController.text);
                    final priceText = priceController.text.trim();

                    if (shares != null && cost != null) {
                      final syncService = ref.read(syncServiceProvider); // 7. 获取服务
                      
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
                        ..createdAt = DateTime.now() // (设置 createdAt)
                        // 8. (关键) 设置 SUPABASE ID 关系
                        ..assetSupabaseId = asset.supabaseId; 
                      
                      // 9. (关键) 保存快照
                      await syncService.savePositionSnapshot(newSnapshot);
                      
                      if(assetUpdated) {
                        await syncService.saveAsset(asset); // 同时保存资产价格更新
                      }

                      ref.invalidate(shareAssetPerformanceProvider(asset.id));
                      // (snapshotHistoryProvider 是 Stream, 会自动刷新)
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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
  
  // 10. (*** 关键修复：删除逻辑 ***)
  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, PositionSnapshot snapshot) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('您确定要删除这条快照吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              // 11. (关键) 使用 SyncService 删除
              final syncService = ref.read(syncServiceProvider);
              await syncService.deletePositionSnapshot(snapshot);
              
              // (旧的 isar.writeTxn 已删除)
              
              // 12. 刷新计算
              ref.invalidate(snapshotHistoryProvider(assetId)); // (重新invalidate以防万一，虽然 stream 应该自己更新)
              ref.invalidate(shareAssetPerformanceProvider(assetId));

              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
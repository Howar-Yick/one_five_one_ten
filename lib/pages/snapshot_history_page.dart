import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart'; // 引入Provider
import 'package:one_five_one_ten/services/database_service.dart';

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
          return ListView.builder(
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              return _buildSnapshotTile(context, ref, snapshot);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      // --- 新增：悬浮操作按钮 ---
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

  Widget _buildSnapshotTile(
      BuildContext context, WidgetRef ref, PositionSnapshot snapshot) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.history_toggle_off),
        title: Text('份额: ${snapshot.totalShares.toStringAsFixed(2)}'),
        subtitle: Text('单位成本: ¥${snapshot.averageCost.toStringAsFixed(3)}'),
        trailing: Text(DateFormat('yyyy-MM-dd').format(snapshot.date)),
        onTap: () => _showEditSnapshotDialog(context, ref, snapshot),
        onLongPress: () => _showDeleteConfirmation(context, ref, snapshot),
      ),
    );
  }

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
                      final isar = DatabaseService().isar;
                      snapshot.totalShares = shares;
                      snapshot.averageCost = cost;
                      snapshot.date = selectedDate;
                      await isar.writeTxn(() async => await isar.positionSnapshots.put(snapshot));
                      ref.invalidate(shareAssetPerformanceProvider(assetId));
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

  void _showUpdateSnapshotDialog(BuildContext context, WidgetRef ref, Asset asset) {
    final sharesController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController();
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
                      final isar = DatabaseService().isar;
                      
                      if (priceText.isNotEmpty) {
                        asset.latestPrice = double.tryParse(priceText) ?? asset.latestPrice;
                        asset.priceUpdateDate = DateTime.now();
                      }

                      final newSnapshot = PositionSnapshot()
                        ..totalShares = shares
                        ..averageCost = cost
                        ..date = selectedDate
                        ..asset.value = asset;
                      
                      await isar.writeTxn(() async {
                        await isar.assets.put(asset);
                        await isar.positionSnapshots.put(newSnapshot);
                        await newSnapshot.asset.save();
                      });
                      
                      // 注意这里需要同时刷新两个Provider
                      ref.invalidate(shareAssetPerformanceProvider(asset.id));
                      ref.invalidate(snapshotHistoryProvider(asset.id));
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
              final isar = DatabaseService().isar;
              await isar.writeTxn(() async => await isar.positionSnapshots.delete(snapshot.id));
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
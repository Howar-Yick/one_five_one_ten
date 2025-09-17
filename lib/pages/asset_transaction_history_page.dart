// 文件: lib/pages/asset_transaction_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart'; // 引入Provider
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:isar/isar.dart'; // 1. 导入 Isar

// 2. (*** 新增：导入 Providers 和新服务 ***)
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

// 3. (*** 新增：导入修复错误的 Currency Formatter ***)
import 'package:one_five_one_ten/utils/currency_formatter.dart';


// 4. (*** 关键修复：重写 Provider 逻辑 ***)
// 旧代码依赖已删除的 IsarLink
// 新代码改为监听 Transaction 集合，并使用 "assetSupabaseId" 过滤，同时变为 StreamProvider
final assetTransactionHistoryProvider =
    StreamProvider.autoDispose.family<List<Transaction>, int>((ref, assetId) async* { // 5. 改为 StreamProvider
  
  final isar = DatabaseService().isar;
  // 6. 必须先获取 Asset 才能知道它的 Supabase ID
  final asset = await isar.assets.get(assetId);
  if (asset == null || asset.supabaseId == null) {
    yield [];
    return;
  }

  final assetSupabaseId = asset.supabaseId!;

  // 7. (新逻辑) 监听 Transaction 集合中所有匹配此 assetSupabaseId 的记录
  final transactionStream = isar.transactions
      .filter() // (*** 修正：使用 .filter() ***)
      .assetSupabaseIdEqualTo(assetSupabaseId)
      .sortByDateDesc() // 按日期降序排序
      .watch(fireImmediately: true);

  yield* transactionStream; // 8. 直接返回流
});

class AssetTransactionHistoryPage extends ConsumerWidget {
  final int assetId;
  const AssetTransactionHistoryPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 9. (修正) 我们需要 Asset 对象本身（用于币种和浮动按钮）
    final asyncAsset = ref.watch(valueAssetDetailProvider(assetId)); // 假设这个 provider 也适用于 ShareAsset
    
    // 10. (*** 已修复 ***) historyAsync 现在是一个 StreamProvider
    final historyAsync = ref.watch(assetTransactionHistoryProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产更新记录'),
      ),
      body: historyAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('暂无记录'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              // 11. (修正) 将 Asset 币种传递给 Tile Builder
              final currencyCode = asyncAsset.asData?.value?.currency ?? 'CNY';
              return _buildTransactionTile(context, ref, txn, currencyCode);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      // --- 悬浮操作按钮 ---
      floatingActionButton: asyncAsset.when(
        data: (asset) => asset == null ? const SizedBox.shrink() : PopupMenuButton(
          icon: const CircleAvatar(
            child: Icon(Icons.add),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'invest_withdraw',
              child: const Text('资金操作'),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showInvestWithdrawDialog(context, ref, asset);
                });
              }
            ),
            PopupMenuItem(
              value: 'update_value',
              child: const Text('更新总值'),
              onTap: () {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showUpdateValueDialog(context, ref, asset);
                 });
              }
            ),
          ],
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTransactionTile(
      BuildContext context, WidgetRef ref, Transaction txn, String currencyCode) { // 12. (修改) 接收 currencyCode
    String title;
    IconData icon;
    Color color;
    // 13. (修改) 不再硬编码 '¥'，而是使用 formatCurrency 辅助函数
    final formattedAmount = formatCurrency(txn.amount, currencyCode);

    switch (txn.type) {
      case TransactionType.invest:
        title = '投入'; icon = Icons.add; color = Colors.red.shade400; break;
      case TransactionType.withdraw:
        title = '转出'; icon = Icons.remove; color = Colors.green.shade400; break;
      case TransactionType.updateValue:
        title = '当天资产金额'; icon = Icons.assessment; color = Theme.of(context).colorScheme.secondary; break;
      default:
        // (处理您在 Transaction.dart 中定义的其他类型)
        title = txn.type.name; icon = Icons.help_outline; color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(txn.date)),
        trailing: Text(formattedAmount, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)), // 使用 formattedAmount
        onTap: () => _showEditTransactionDialog(context, ref, txn, currencyCode), // 14. (修改) 传递 currencyCode
        onLongPress: () => _showDeleteConfirmation(context, ref, txn),
      ),
    );
  }

  // 15. (*** 关键修复：删除逻辑 ***)
  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, Transaction txn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('您确定要删除这条记录吗？此操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              // 16. (关键) 使用 SyncService 删除
              final syncService = ref.read(syncServiceProvider);
              await syncService.deleteTransaction(txn);
              
              // 17. 刷新计算 Provider
              ref.invalidate(valueAssetPerformanceProvider(assetId)); 
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 18. (*** 关键修复：创建逻辑 (Invest/Withdraw) ***)
  void _showInvestWithdrawDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
    final amountController = TextEditingController();
    final List<bool> isSelected = [true, false];
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('资金操作'),
              content: /* ... 内容不变 ... */ Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToggleButtons(
                    isSelected: isSelected,
                    onPressed: (index) => setState(() { isSelected[0] = index == 0; isSelected[1] = index == 1; }),
                    borderRadius: BorderRadius.circular(8.0),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('投入')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('转出')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 19. (*** 错误修复：导入 getCurrencySymbol ***)
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '金额', prefixText: getCurrencySymbol(asset.currency))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
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
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      final syncService = ref.read(syncServiceProvider); 
                      final newTxn = Transaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now() 
                        ..type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw
                        // 20. (关键) 设置 SUPABASE ID 关系
                        ..assetSupabaseId = asset.supabaseId;
                      
                      await syncService.saveTransaction(newTxn); 
                      
                      ref.invalidate(valueAssetPerformanceProvider(asset.id));
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

  // 21. (*** 关键修复：创建逻辑 (Update Value) ***)
  void _showUpdateValueDialog(
      BuildContext context, WidgetRef ref, Asset asset) {
    final valueController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新资产总值'),
              content: /* ... 内容不变 ... */ Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 22. (*** 错误修复：导入 getCurrencySymbol ***)
                  TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '当前资产总价值', prefixText: getCurrencySymbol(asset.currency))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
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
                    final value = double.tryParse(valueController.text);
                    if (value != null) {
                      final syncService = ref.read(syncServiceProvider); 
                      final newTxn = Transaction()
                        ..amount = value
                        ..date = selectedDate
                        ..createdAt = DateTime.now()
                        ..type = TransactionType.updateValue
                        // 23. (关键) 设置 SUPABASE ID 关系
                        ..assetSupabaseId = asset.supabaseId;
                      
                      await syncService.saveTransaction(newTxn); 
                      
                      ref.invalidate(valueAssetPerformanceProvider(asset.id));
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

  // 24. (*** 关键修复：更新逻辑 (Edit) ***)
  void _showEditTransactionDialog(
      BuildContext context, WidgetRef ref, Transaction txn, String currencyCode) { // 25. (修改) 接收 currencyCode
    final amountController = TextEditingController(text: txn.amount.toString());
    DateTime selectedDate = txn.date;
    final List<bool> isSelected = [
      txn.type == TransactionType.invest,
      txn.type == TransactionType.withdraw
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑记录'),
              content: Column(
                // (UI 保持不变)
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (txn.type != TransactionType.updateValue)
                    ToggleButtons(
                      isSelected: isSelected,
                      onPressed: (index) {
                        setState(() {
                          isSelected[0] = index == 0;
                          isSelected[1] = index == 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('投入')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('转出')),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: txn.type == TransactionType.updateValue ? '总资产金额' : '金额',
                      prefixText: getCurrencySymbol(currencyCode), // 26. (修改) 使用 currencyCode
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
                            setState(() { selectedDate = pickedDate; });
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
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount >= 0) {
                      
                      // 27. (关键) 更新本地对象
                      txn.amount = amount;
                      txn.date = selectedDate;
                      if (txn.type != TransactionType.updateValue) {
                        txn.type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw;
                      }
                      
                      // 28. (关键) 使用 SyncService 保存
                      await ref.read(syncServiceProvider).saveTransaction(txn);

                      // 29. 刷新计算
                      ref.invalidate(valueAssetPerformanceProvider(assetId));
                      // (assetTransactionHistoryProvider 是 Stream, 会自动刷新)
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
}
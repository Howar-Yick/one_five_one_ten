// 文件: lib/pages/accounts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart'; 
import 'package:one_five_one_ten/models/transaction.dart'; 
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/widgets/account_card.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; 

// (*** 新增：导入我们需要的 Sync Service ***)
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. (已修正) accountsProvider 现在是一个 StreamProvider，所以 UI 会自动实时更新！
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Text(
                '还没有账户，点击右上角“+”添加一个吧！',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return RefreshIndicator(
             // 2. (修改) onRefresh 现在应该 invalidate Stream provider (虽然它已经是实时的，但下拉刷新是一个好的交互)
            onRefresh: () async { ref.invalidate(accountsProvider); },
            child: ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                // 3. (*** 关键修复：修复导航错误 ***)
                // 您的 AccountCard 没有 'onTap'。
                // 您的 AccountDetailPage 需要一个 'int accountId'。
                // 我们添加一个 GestureDetector 来处理点击，并传递本地的 Isar ID (account.id)
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                         // 传递本地 Isar ID，这是 AccountDetailPage 期望的
                        builder: (context) => AccountDetailPage(accountId: account.id),
                      ),
                    );
                  },
                  child: AccountCard(
                    account: account, 
                    onLongPress: () => _showAccountActions(context, ref, account),
                  ),
                );
              }, 
            ), 
          ); 
        }, 
      ), 
    ); 
  } 

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController();
    String selectedCurrency = 'CNY'; 

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('添加新账户'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '账户名称',
                      hintText: '例如：国金证券',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('币种:', style: TextStyle(fontSize: 16)),
                      DropdownButton<String>(
                        value: selectedCurrency,
                        items: ['CNY', 'USD', 'HKD'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedCurrency = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  )
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('保存'),
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      
                      // 4. (*** 关键修改：准备新对象 ***)
                      // 我们必须使用我们在模型中定义的空构造函数
                      final newAccount = Account()
                        ..name = name
                        ..createdAt = DateTime.now()
                        ..currency = selectedCurrency; 
                      
                      // 5. (*** 关键修改：使用 SyncService 写入 ***)
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.saveAccount(newAccount);
                      
                      // 6. (移除) ref.invalidate(accountsProvider) 不再需要，因为它是 Stream
                      // 7. (保留) 刷新 dashboard 是必要的，因为它依赖计算
                      ref.invalidate(dashboardDataProvider); 
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAccountActions(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑账户'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditAccountDialog(context, ref, account); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除账户', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteAccount(context, ref, account); 
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditAccountDialog(BuildContext context, WidgetRef ref, Account account) async {
    final TextEditingController nameController = TextEditingController(text: account.name);
    String selectedCurrency = account.currency;
    final isar = DatabaseService().isar;

    // 8. (*** 关键修复：替换已失效的 IsarLink 检查 ***)
    // await account.transactions.load(); // <-- 已失效
    // await account.trackedAssets.load(); // <-- 已失效
    
    // 9. (*** 新的查询逻辑 ***)
    // 检查是否有任何 AccountTransaction 链接到此帐户的 SUPABASE ID
    final txCount = await isar.accountTransactions.where()
                          .filter()
                          .accountSupabaseIdEqualTo(account.supabaseId)
                          .count();
    // 检查是否有任何 Asset 链接到此帐户的 SUPABASE ID
    final assetCount = await isar.assets.where()
                             .filter()
                             .accountSupabaseIdEqualTo(account.supabaseId)
                             .count();
    
    final bool hasTransactions = txCount > 0;
    final bool hasAssets = assetCount > 0;
    final bool allowCurrencyChange = !hasTransactions && !hasAssets;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑账户'),
              content: Column(
                // (内部 UI 保持不变)
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '账户名称',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('币种:', style: TextStyle(fontSize: 16)),
                      DropdownButton<String>(
                        value: selectedCurrency,
                        items: ['CNY', 'USD', 'HKD'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            enabled: allowCurrencyChange || value == account.currency, 
                            child: Text(
                              value,
                              style: TextStyle(
                                color: (allowCurrencyChange || value == account.currency) 
                                        ? Theme.of(context).textTheme.bodyLarge?.color 
                                        : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: allowCurrencyChange ? (newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedCurrency = newValue;
                            });
                          }
                        } : null, 
                      ),
                    ],
                  ),
                  if (!allowCurrencyChange) ...[
                    const SizedBox(height: 10),
                    Text(
                      '注意：账户已包含资产或交易记录，无法修改币种。',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ]
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('保存'),
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      account.name = name;
                      if (allowCurrencyChange) {
                        account.currency = selectedCurrency;
                      }
                      
                      // 10. (*** 关键修改：使用 SyncService 保存 ***)
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.saveAccount(account);
                      
                      // 11. (移除) 无效的 invalidate (accountDetailProvider 稍后修复)
                      // ref.invalidate(accountDetailProvider(account.id));
                      // ref.invalidate(accountPerformanceProvider(account.id));
                      
                      // 12. (保留) 刷新 Dashboard
                      ref.invalidate(dashboardDataProvider); 

                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  } 

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref, Account account) async {
    
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        // (对话框 UI 逻辑保持不变)
        final controller = TextEditingController();
        bool isButtonEnabled = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('删除账户'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('此操作不可撤销。请输入账户名称 "${account.name}" 以确认删除。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '账户名称',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        isButtonEnabled = (value == account.name);
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: isButtonEnabled ? () => Navigator.of(dialogContext).pop(true) : null,
                  child: Text(
                    '删除',
                    style: TextStyle(
                      color: isButtonEnabled ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((ok) async { 
      if (ok != true) return;
      if (account.supabaseId == null) {
         // 安全检查：如果账户从未同步过，执行纯本地删除
         final isar = DatabaseService().isar;
         await isar.writeTxn(() => isar.accounts.delete(account.id));
         ref.invalidate(dashboardDataProvider);
         return;
      }

      final isar = DatabaseService().isar;
      final syncService = ref.read(syncServiceProvider);
      
      // 13. (*** 关键修复：重写整个删除逻辑 ***)
      // 我们必须先删除所有依赖项 (本地和云端)，然后再删除账户
      
      // 我们使用一个新的 writeTxn，因为它只用于读取 ID 列表
      final assetsToDelete = await isar.assets.where()
                              .filter()
                              .accountSupabaseIdEqualTo(account.supabaseId)
                              .findAll();
      
      List<Transaction> txsToDelete = [];
      List<PositionSnapshot> snapsToDelete = [];

      for (final asset in assetsToDelete) {
        if (asset.supabaseId == null) continue; 
        
        final txs = await isar.transactions.where()
                        .filter()
                        .assetSupabaseIdEqualTo(asset.supabaseId)
                        .findAll();
        txsToDelete.addAll(txs);

        final snaps = await isar.positionSnapshots.where()
                              .filter()
                              .assetSupabaseIdEqualTo(asset.supabaseId)
                              .findAll();
        snapsToDelete.addAll(snaps);
      }

      final accTxsToDelete = await isar.accountTransactions.where()
                             .filter()
                             .accountSupabaseIdEqualTo(account.supabaseId)
                             .findAll();

      // (*** 关键：现在我们执行实际的删除操作 (云端+本地) ***)
      // 必须先删除子记录，再删除父记录，以防外键约束
      for (final tx in txsToDelete) { await syncService.deleteTransaction(tx); }
      for (final snap in snapsToDelete) { await syncService.deletePositionSnapshot(snap); }
      for (final accTx in accTxsToDelete) { await syncService.deleteAccountTransaction(accTx); }
      for (final asset in assetsToDelete) { await syncService.deleteAsset(asset); }
      
      // 最后删除账户本身
      await syncService.deleteAccount(account);


      ref.invalidate(dashboardDataProvider); // 刷新 Dashboard
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除账户：${account.name}')),
        );
      }
    });
  }
}
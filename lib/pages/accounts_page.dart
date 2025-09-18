// 文件: lib/pages/accounts_page.dart
// (这是完整、已修复的文件代码)

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

import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart'; // 1. (*** 新增导入 ***)
import 'package:one_five_one_ten/utils/currency_formatter.dart';  // 2. (*** 新增导入 ***)


// (Provider 保持不变)
final dashboardDataProvider = FutureProvider.autoDispose((ref) async {
  final calculator = CalculatorService();
  // final exchange = ExchangeRateService(); // (ExchangeRateService 在你的项目中不存在，已移除)

  final globalPerformance = await calculator.calculateGlobalPerformance();
  final allocation = await calculator.calculateAssetAllocation();
  final history = await calculator.getGlobalValueHistory();

  return {
    'globalPerformance': globalPerformance,
    'allocation': allocation,
    'history': history,
  };
});

// (Provider 保持不变)
final allAccountsStreamProvider = StreamProvider.autoDispose((ref) {
  final isar = DatabaseService().isar;
  return isar.accounts.where().watch(fireImmediately: true);
});

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // (*** 修正：重命名 Provider 变量以匹配你的原始代码 ***)
    final accountsAsync = ref.watch(allAccountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加账户',
            onPressed: () {
              _showAddAccountDialog(context, ref); // (*** 确保 ref 被传递 ***)
            },
          ),
        ],
      ),
      body: accountsAsync.when(
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
            onRefresh: () async { 
              ref.invalidate(allAccountsStreamProvider); // (*** 修正：使用正确的 Provider 名称 ***)
              ref.invalidate(dashboardDataProvider);
            },
            child: ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                // (*** 你的原始文件在这里缺少 onTap，已修复 ***)
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                         builder: (context) => AccountDetailPage(accountId: account.id),
                      ),
                    );
                  },
                  child: AccountCard(
                    account: account, 
                    // (*** 你的原始文件缺少 AccountCard，我假设它存在并接收 onLongPress ***)
                    onLongPress: () => _showAccountActions(context, ref, account),
                  ),
                );
              }, 
            ), 
          ); 
        }, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ), 
    ); 
  } 

  // (*** 这是修复后的 _showAddAccountDialog ***)
  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController();
    // (*** 新增：匹配你日志错误的 description 控制器 ***)
    final TextEditingController descriptionController = TextEditingController(); 
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
                  // (*** 新增：Description 输入框 ***)
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '备注 (可选)',
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
                  // (*** 这是修复后的 onPressed 逻辑 ***)
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    if (name.isEmpty) return;

                    // (*** 1. 用 try-catch 包裹所有操作 ***)
                    try {
                      final syncService = ref.read(syncServiceProvider);
                      
                      // 2. 创建新对象 (包含 description)
                      final newAccount = Account()
                        ..name = name
                        ..description = descriptionController.text.trim() // (*** 已添加 ***)
                        ..createdAt = DateTime.now()
                        ..currency = selectedCurrency; 
                      
                      // 3. (!!! 关键修复：先在本地写入以获取 Isar ID !!!)
                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.accounts.put(newAccount);
                      });
                      // (newAccount.id 现在有效了)

                      // 4. (!!! 然后再同步这个带有 ID 的对象 !!!)
                      //    (如果 Supabase 失败，它现在会抛出异常)
                      await syncService.saveAccount(newAccount);
                      
                      // 5. 刷新
                      ref.invalidate(dashboardDataProvider); 
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    
                    } catch (e) {
                      // (*** 6. 捕获所有错误 (包括 Isar 错误和 Supabase 错误) ***)
                      print("创建账户失败: $e");
                       if (dialogContext.mounted) {
                         ScaffoldMessenger.of(dialogContext).showSnackBar(
                           SnackBar(content: Text('创建失败: $e')),
                         );
                       }
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

  // (*** 这是修复后的 _showAccountActions 和相关函数 ***)
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
    // (*** 修复：添加 description 控制器 ***)
    final TextEditingController descriptionController = TextEditingController(text: account.description); 
    String selectedCurrency = account.currency;
    final isar = DatabaseService().isar;

    // (*** 已修复：使用 Supabase ID 进行依赖检查 ***)
    final txCount = await isar.accountTransactions.where()
                          .filter()
                          .accountSupabaseIdEqualTo(account.supabaseId)
                          .count();
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '账户名称',
                    ),
                  ),
                  // (*** 修复：添加 description 编辑框 ***)
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '备注 (可选)',
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
                  // (*** 修复：编辑逻辑 ***)
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      try {
                        account.name = name;
                        account.description = descriptionController.text.trim(); // (*** 修复：保存 description ***)
                        if (allowCurrencyChange) {
                          account.currency = selectedCurrency;
                        }
                        
                        // (对象已有 Isar ID，直接保存即可，我们的 Service 会处理好)
                        final syncService = ref.read(syncServiceProvider);
                        await syncService.saveAccount(account);
                        
                        ref.invalidate(dashboardDataProvider); 
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();

                      } catch (e) {
                         print("编辑账户失败: $e");
                         if (dialogContext.mounted) {
                           ScaffoldMessenger.of(dialogContext).showSnackBar(
                             SnackBar(content: Text('编辑失败: $e')),
                           );
                         }
                      }
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

  // (*** 这是修复后的删除逻辑 ***)
  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref, Account account) async { 
    
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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

      try {
        final isar = DatabaseService().isar;
        final syncService = ref.read(syncServiceProvider);
        
        // 如果账户从未同步过 (supabaseId 为 null)，我们需要手动清理本地
        if (account.supabaseId == null) {
          await isar.writeTxn(() async {
              // 我们仍然需要删除链接到这个 (已删除) Isar ID 的子项吗？
              // 在我们的新架构中，子项是通过 Supabase ID 链接的。
              // 如果父项没有 Supabase ID，它就不应该有任何子项。
              // 所以直接删除父项是安全的。
              await isar.accounts.delete(account.id);
          });
        } else {
          // 如果它已同步，我们必须删除所有依赖它的子项
          final accountSupaId = account.supabaseId!;
          
          // 1. 查找所有 Assets
          final assetsToDelete = await isar.assets.where()
                                      .filter()
                                      .accountSupabaseIdEqualTo(accountSupaId)
                                      .findAll();
          
          for (final asset in assetsToDelete) {
            if (asset.supabaseId != null) {
              final assetSupaId = asset.supabaseId!;
              // 1a. 删除 Transactions (价值法)
              final txs = await isar.transactions.where().filter().assetSupabaseIdEqualTo(assetSupaId).findAll();
              for (final tx in txs) {
                await syncService.deleteTransaction(tx);
              }
              // 1b. 删除 Snapshots (份额法)
              final snaps = await isar.positionSnapshots.where().filter().assetSupabaseIdEqualTo(assetSupaId).findAll();
              for (final snap in snaps) {
                await syncService.deletePositionSnapshot(snap);
              }
            }
            // 1c. 删除 Asset
            await syncService.deleteAsset(asset);
          }

          // 2. 查找并删除所有 AccountTransactions
          final accTxsToDelete = await isar.accountTransactions.where()
                                    .filter()
                                    .accountSupabaseIdEqualTo(accountSupaId)
                                    .findAll();
          for (final tx in accTxsToDelete) {
            await syncService.deleteAccountTransaction(tx);
          }
        }
        
        // 3. 最后删除 Account (无论是否已同步，deleteAccount 都会处理)
        await syncService.deleteAccount(account);

        ref.invalidate(dashboardDataProvider); 
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除账户：${account.name}')),
          );
        }
      } catch (e) {
          print("删除账户失败: $e");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: $e')),
            );
          }
      }
    });
  }
}
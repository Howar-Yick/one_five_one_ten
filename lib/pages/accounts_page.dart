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
import 'package:one_five_one_ten/providers/global_providers.dart'; // 修正：导入全局 Provider

// 修正：本地 accountsProvider 已被移除，移至 global_providers.dart

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 修正：监听来自 global_providers 的 accountsProvider
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
            onRefresh: () => ref.refresh(accountsProvider.future),
            child: ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                // 修正：使用新的 AccountCard 并传递回调
                return AccountCard(
                  account: account, 
                  onLongPress: () => _showAccountActions(context, ref, account),
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
                      final newAccount = Account()
                        ..name = name
                        ..createdAt = DateTime.now()
                        ..currency = selectedCurrency; 
                      
                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.accounts.put(newAccount);
                      });
                      
                      ref.invalidate(accountsProvider);
                      ref.invalidate(dashboardDataProvider); // 刷新 Dashboard
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

    await account.transactions.load();
    await account.trackedAssets.load();
    
    final bool hasTransactions = account.transactions.isNotEmpty;
    final bool hasAssets = account.trackedAssets.isNotEmpty;
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
                      
                      await isar.writeTxn(() async {
                        await isar.accounts.put(account);
                      });
                      
                      ref.invalidate(accountsProvider);
                      ref.invalidate(accountDetailProvider(account.id));
                      ref.invalidate(accountPerformanceProvider(account.id));
                      ref.invalidate(dashboardDataProvider); // 刷新 Dashboard

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

      final isar = DatabaseService().isar;
      await isar.writeTxn(() async {
        await account.trackedAssets.load();
        final assets = account.trackedAssets.toList();
        for (final asset in assets) {
          await asset.snapshots.load();
          await asset.transactions.load();
          if (asset.snapshots.isNotEmpty) {
            await isar.collection<PositionSnapshot>().deleteAll(asset.snapshots.map((s) => s.id).toList());
          }
          if (asset.transactions.isNotEmpty) {
            await isar.collection<Transaction>().deleteAll(asset.transactions.map((t) => t.id).toList());
          }
        }
        if (assets.isNotEmpty) {
          await isar.collection<Asset>().deleteAll(assets.map((a) => a.id).toList());
        }

        final txnIds = await isar.collection<AccountTransaction>()
            .filter()
            .account((q) => q.idEqualTo(account.id))
            .idProperty()
            .findAll();
        if (txnIds.isNotEmpty) {
          await isar.collection<AccountTransaction>().deleteAll(txnIds);
        }
        
        await isar.accounts.delete(account.id);
      });

      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardDataProvider); // 刷新 Dashboard
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除账户：${account.name}')),
        );
      }
    });
  }
}
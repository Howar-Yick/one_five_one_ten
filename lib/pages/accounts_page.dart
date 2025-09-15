import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart'; // <--- 修正：添加此行
import 'package:one_five_one_ten/models/transaction.dart';       // <--- 修正：添加此行
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/widgets/account_card.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';

/// 用 FutureProvider 拉取账户列表
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final isar = DatabaseService().isar;
  // ❗️关键：where() 之后先 anyId()，再 findAll()
  return isar.accounts.where().anyId().findAll();
});

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                // --- 寻找并替换这里的 GestureDetector ---
                return GestureDetector(
                  // 修正：长按时显示操作菜单，而不是直接删除
                  onLongPress: () => _showAccountActions(context, ref, account), 
                  child: AccountCard(account: account),
                );
                // --- 替换结束 ---
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController();
    String selectedCurrency = 'CNY'; // 默认币种

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // 使用 StatefulBuilder 来管理对话框内部的币种选择状态
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
                        ..currency = selectedCurrency; // 保存选择的币种
                      
                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.accounts.put(newAccount);
                      });
                      
                      ref.invalidate(accountsProvider);
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

  /// --- 新增方法 1：显示账户操作菜单 (编辑/删除) ---
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
                _showEditAccountDialog(context, ref, account); // 调用编辑对话框
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除账户', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteAccount(context, ref, account); // 调用现有的删除确认
              },
            ),
          ],
        );
      },
    );
  }

  /// --- 新增方法 2：显示编辑账户对话框 ---
  void _showEditAccountDialog(BuildContext context, WidgetRef ref, Account account) async {
    final TextEditingController nameController = TextEditingController(text: account.name);
    String selectedCurrency = account.currency;
    final isar = DatabaseService().isar;

    // 关键检查：在显示对话框前，检查该账户是否已有数据
    // 我们需要同时检查 AccountTransactions 和 Assets (因为资产也链接到账户)
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
                            // 如果不允许更改，则禁用 CNY 之外的选项
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
                        // 如果不允许更改，则 onChanged 设置为 null 来禁用整个按钮
                        onChanged: allowCurrencyChange ? (newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedCurrency = newValue;
                            });
                          }
                        } : null, // <--- 关键逻辑
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
                      // 更新现有账户对象
                      account.name = name;
                      if (allowCurrencyChange) {
                        account.currency = selectedCurrency;
                      }
                      
                      await isar.writeTxn(() async {
                        await isar.accounts.put(account);
                      });
                      
                      // 刷新账户列表和详情页（如果已打开）
                      ref.invalidate(accountsProvider);
                      ref.invalidate(accountDetailProvider(account.id));
                      ref.invalidate(accountPerformanceProvider(account.id));

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

  /// 删除账户（会级联清理该账户关联的交易与资产）
  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref, Account account) async {
    
    // 使用 StatefulBuilder 来管理对话框内的状态（输入框内容和按钮是否可用）
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
                      // 监听输入，当输入与账户名完全一致时，激活按钮
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
                // 根据 isButtonEnabled 状态决定按钮是否可点击
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
    ).then((ok) async { // 使用 .then() 来处理对话框关闭后的逻辑
      if (ok != true) return;

      final isar = DatabaseService().isar;
      await isar.writeTxn(() async {
        // --- 级联删除逻辑保持不变 ---
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除账户：${account.name}')),
        );
      }
    });
  }
}
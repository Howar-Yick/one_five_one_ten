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
                // 使用 GestureDetector 来包裹 AccountCard 以添加长按事件
                return GestureDetector(
                  onLongPress: () => _confirmDeleteAccount(context, ref, account),
                  child: AccountCard(account: account),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加新账户'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '账户名称',
            hintText: '例如：国金证券',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final isar = DatabaseService().isar;
              final account = Account()
                ..name = name
                ..createdAt = DateTime.now();
              await isar.writeTxn(() async {
                await isar.accounts.put(account);
              });
              ref.invalidate(accountsProvider);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 删除账户（会级联清理该账户关联的交易与资产）
  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref, Account account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确认删除“${account.name}”以及其所有相关记录吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final isar = DatabaseService().isar;
    await isar.writeTxn(() async {
      // 1. 获取并删除所有关联的资产及其子记录
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

      // 2. 获取并删除该账户的顶层交易记录
      final txnIds = await isar.collection<AccountTransaction>()
          .filter()
          .account((q) => q.idEqualTo(account.id))
          .idProperty()
          .findAll();
      if (txnIds.isNotEmpty) {
        await isar.collection<AccountTransaction>().deleteAll(txnIds);
      }
      
      // 3. 最后删除账户本身
      await isar.accounts.delete(account.id);
    });

    ref.invalidate(accountsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除账户：${account.name}')),
      );
    }
  }
}
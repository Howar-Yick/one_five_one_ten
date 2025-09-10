// lib/pages/accounts_page.dart (Final, Corrected Version)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/widgets/account_card.dart';
import 'package:isar/isar.dart'; // ✅ 关键：引入 Isar 扩展方法（findAll 等）

// --- MAJOR CHANGE: Using FutureProvider instead of StreamProvider ---
// This fetches a snapshot of the data when requested. It is simpler and more robust.
final accountsProvider = FutureProvider<List<Account>>((ref) {
  final isar = DatabaseService().isar;
  // .findAll() is a standard method to get all results of a query. This will work.
  return isar.accounts.where().findAll();
});

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsyncValue = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // We now pass the 'ref' to the dialog so it can trigger a refresh.
              _showAddAccountDialog(context, ref);
            },
          ),
        ],
      ),
      body: accountsAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('发生错误: $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Text(
                '还没有账户，点击右上角“+”添加一个吧！',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AccountCard(account: account);
            },
          );
        },
      ),
    );
  }

  // --- MINOR CHANGE: The dialog now accepts a WidgetRef ---
  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('添加新账户'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '账户名称',
              hintText: '例如：国金证券',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('保存'),
              onPressed: () async {
                final String name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newAccount = Account()
                    ..name = name
                    ..createdAt = DateTime.now();
                  final isar = DatabaseService().isar;
                  await isar.writeTxn(() async {
                    await isar.accounts.put(newAccount);
                  });

                  // --- ADDED LOGIC: Manually refresh the list ---
                  // This tells Riverpod that the data is stale and needs to be fetched again.
                  ref.invalidate(accountsProvider);

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 使用 ConsumerWidget 以便将来可以从 Riverpod 中读取数据
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 实现添加新账户的功能
            },
          ),
        ],
      ),
      body: Center(
        // TODO: 将来这里会是一个账户列表
        child: Text(
          '还没有账户，点击右上角“+”添加一个吧！',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
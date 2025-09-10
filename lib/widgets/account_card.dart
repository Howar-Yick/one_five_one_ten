import 'package:flutter/material.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart'; // 引入我们刚创建的详情页

class AccountCard extends StatelessWidget {
  final Account account;

  const AccountCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('创建于: ${account.createdAt.toLocal().toString().substring(0, 10)}'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // --- 新增代码：页面跳转逻辑 ---
          Navigator.of(context).push(
            MaterialPageRoute(
              // 创建详情页实例，并将当前账户的 id 传递过去
              builder: (context) => AccountDetailPage(accountId: account.id),
            ),
          );
        },
      ),
    );
  }
}
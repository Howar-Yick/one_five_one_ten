import 'package:flutter/material.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';

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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AccountDetailPage(accountId: account.id),
            ),
          );
        },
      ),
    );
  }
}
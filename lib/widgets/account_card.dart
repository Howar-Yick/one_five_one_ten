import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; // 修正：导入全局 providers

// 修正: 不再导入 accounts_page.dart 或 dashboard_page.dart

class AccountCard extends ConsumerWidget { 
  final Account account;
  final VoidCallback? onLongPress; 

  const AccountCard({super.key, required this.account, this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) { 
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
          ).then((_) {
            // 当从 AccountDetailPage 返回时，刷新全局 Provider
            ref.invalidate(accountsProvider);
            ref.invalidate(dashboardDataProvider); 
          });
        },
        onLongPress: onLongPress,
      ),
    );
  }
}
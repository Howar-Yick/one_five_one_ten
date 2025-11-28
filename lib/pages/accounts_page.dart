// 文件: lib/pages/accounts_page.dart
// (这是已添加入口按钮的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/widgets/account_card.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';

// ★ 新增导入
import 'package:one_five_one_ten/pages/archived_assets_page.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _isAmountVisible = true;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账户'),
        actions: [
          // ★★★ 新增：已清仓资产入口按钮 ★★★
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: '查看已清仓资产',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArchivedAssetsPage()),
              );
            },
          ),
          // ★★★ 新增结束 ★★★
          IconButton(
            icon: Icon(_isAmountVisible ? Icons.visibility : Icons.visibility_off),
            tooltip: '隐藏/显示金额',
            onPressed: () {
              setState(() {
                _isAmountVisible = !_isAmountVisible;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加账户',
            onPressed: () => _showAddAccountDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // 总览卡片
          dashboardAsync.when(
            data: (dashboardData) {
              return _buildSummaryCard(context, dashboardData);
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => Card(
              margin: const EdgeInsets.all(16.0),
              child: ListTile(title: Text('加载总览失败: $err')),
            ),
          ),
          // 账户列表
          Expanded(
            child: accountsAsync.when(
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
                    ref.invalidate(accountsProvider);
                    ref.invalidate(dashboardDataProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final performanceAsync = ref.watch(accountPerformanceProvider(account.id));

                      return performanceAsync.when(
                        data: (performanceData) => AccountCard(
                          account: account,
                          accountPerformance: performanceData,
                          isAmountVisible: _isAmountVisible,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AccountDetailPage(accountId: account.id),
                              ),
                            );
                          },
                          onLongPress: () => _showAccountActions(context, ref, account),
                        ),
                        loading: () => Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(account.name.isNotEmpty ? account.name.substring(0, 1) : '?'),
                            ),
                            title: Text(account.name),
                            subtitle: const Text('正在计算账户性能...'),
                          ),
                        ),
                        error: (e, _) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                            title: Text(account.name),
                            subtitle: Text('加载性能数据失败: $e'),
                           ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载账户列表失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> performance) {
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    final colorScheme = Theme.of(context).colorScheme;

    final totalValue = (performance['totalValue'] ?? 0.0) as double;
    final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final profitRate = (performance['profitRate'] ?? 0.0) as double;
    final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;

    Color profitColor = totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor = colorScheme.onSurfaceVariant;
    }

    String formatValue(dynamic value, String type, {String currency = 'CNY'}) {
      if (!_isAmountVisible) return '***';
      if (value is double) {
        if (type == 'currency') return formatCurrency(value, currency);
        if (type == 'percent') return percentFormat.format(value);
      }
      return value.toString();
    }

    return Card(
      color: colorScheme.surfaceVariant,
      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产总览', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant
              )
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryMetric('总资产', formatValue(totalValue, 'currency'), context),
                      const SizedBox(height: 12),
                      _buildSummaryMetric('累计收益', formatValue(totalProfit, 'currency'), context,
                          valueColor: _isAmountVisible ? profitColor : null),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildSummaryMetric('收益率', formatValue(profitRate, 'percent'), context,
                          valueColor: _isAmountVisible ? profitColor : null, alignment: CrossAxisAlignment.end),
                      const SizedBox(height: 12),
                      _buildSummaryMetric('年化', formatValue(annualizedReturn, 'percent'), context,
                          valueColor: _isAmountVisible ? profitColor : null, alignment: CrossAxisAlignment.end),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryMetric(String label, String value, BuildContext context,
      {Color? valueColor, CrossAxisAlignment? alignment}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: alignment ?? CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? colorScheme.onSurfaceVariant,
            ),
        ),
      ],
    );
  }

  void _showAddAccountDialog(
    BuildContext context,
    WidgetRef ref, {
    String initialCurrency = 'CNY',
    String? suggestedSuffix,
    String? initialName,
  }) {
    final TextEditingController nameController = TextEditingController(
      text: initialName ?? (suggestedSuffix != null ? '美元账户$suggestedSuffix' : ''),
    );
    final TextEditingController descriptionController = TextEditingController();
    String selectedCurrency = initialCurrency;

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
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    if (name.isEmpty) return;

                    try {
                      final syncService = ref.read(syncServiceProvider);

                      final newAccount = Account()
                        ..name = name
                        ..description = descriptionController.text.trim()
                        ..createdAt = DateTime.now()
                        ..currency = selectedCurrency;

                      final isar = DatabaseService().isar;
                      await isar.writeTxn(() async {
                        await isar.accounts.put(newAccount);
                      });

                      await syncService.saveAccount(newAccount);

                      ref.invalidate(dashboardDataProvider);
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    } catch (e) {
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
            if (account.currency != 'CNY')
              ListTile(
                leading: const Icon(Icons.history_toggle_off_outlined),
                title: const Text('补录该账户的汇率'),
                subtitle: const Text('为缺失汇率/折算金额的资金操作补齐数据'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _backfillMissingFxRates(context, ref, account);
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
    final TextEditingController descriptionController = TextEditingController(text: account.description);
    String selectedCurrency = account.currency;
    final isar = DatabaseService().isar;

    final txCount = await isar.accountTransactions
        .where()
        .accountSupabaseIdEqualTo(account.supabaseId)
        .count();
    final assetCount = await isar.assets
        .where()
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
                        onChanged: allowCurrencyChange
                            ? (newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedCurrency = newValue;
                                  });
                                }
                              }
                            : null,
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
                      try {
                        account.name = name;
                        account.description = descriptionController.text.trim();
                        if (allowCurrencyChange) {
                          account.currency = selectedCurrency;
                        }
                        
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

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref, Account account) async {
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
                    decoration: const InputDecoration(
                      labelText: '账户名称',
                      border: OutlineInputBorder(),
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
        
        if (account.supabaseId == null) {
          await isar.writeTxn(() async {
            await isar.accounts.delete(account.id);
          });
        } else {
          final accountSupaId = account.supabaseId!;
          
          final assetsToDelete = await isar.assets
              .where()
              .accountSupabaseIdEqualTo(accountSupaId)
              .findAll();
          
          for (final asset in assetsToDelete) {
            if (asset.supabaseId != null) {
              final assetSupaId = asset.supabaseId!;
              final txs = await isar.transactions
                  .where()
                  .assetSupabaseIdEqualTo(assetSupaId)
                  .findAll();
              for (final tx in txs) {
                await syncService.deleteTransaction(tx);
              }
              final snaps = await isar.positionSnapshots
                  .where()
                  .assetSupabaseIdEqualTo(assetSupaId)
                  .findAll();
              for (final snap in snaps) {
                await syncService.deletePositionSnapshot(snap);
              }
            }
            await syncService.deleteAsset(asset);
          }

          final accTxsToDelete = await isar.accountTransactions
              .where()
              .accountSupabaseIdEqualTo(accountSupaId)
              .findAll();
          for (final tx in accTxsToDelete) {
            await syncService.deleteAccountTransaction(tx);
          }
        }
        
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

  Future<void> _backfillMissingFxRates(
      BuildContext context, WidgetRef ref, Account account) async {
    if (account.currency == 'CNY') return;
    final supabaseId = account.supabaseId;
    if (supabaseId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账户缺少同步编号，无法补录汇率，请先同步或重新启动后重试。')),
        );
      }
      return;
    }

    final isar = DatabaseService().isar;
    final missingTxns = await isar.accountTransactions
        .where()
        .accountSupabaseIdEqualTo(supabaseId)
        .filter()
        .group((q) => q.typeEqualTo(TransactionType.invest).or().typeEqualTo(TransactionType.withdraw))
        .and()
        .group((q) => q.fxRateToCnyIsNull().or().baseAmountCnyIsNull())
        .findAll();

    if (missingTxns.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有需要补录汇率的记录')),
        );
      }
      return;
    }

    final rate = await ExchangeRateService().getRate(account.currency, 'CNY');
    final syncService = ref.read(syncServiceProvider);

    for (final txn in missingTxns) {
      txn.fxRateToCny ??= rate;
      txn.baseAmountCny ??= txn.amount * (txn.fxRateToCny ?? rate);
      await syncService.saveAccountTransaction(txn);
    }

    ref.invalidate(accountPerformanceProvider(account.id));
    ref.invalidate(dashboardDataProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已补录 ${missingTxns.length} 条交易的汇率')),
      );
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';

// ... (Providers 保持不变)
final accountDetailProvider = FutureProvider.autoDispose.family<Account?, int>((ref, accountId) {
  final isar = DatabaseService().isar;
  return isar.accounts.get(accountId);
});

final accountPerformanceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, accountId) async {
  final account = await ref.watch(accountDetailProvider(accountId).future);
  if (account == null) {
    throw '未找到账户';
  }
  return CalculatorService().calculateAccountPerformance(account);
});

class AccountDetailPage extends ConsumerWidget {
  final int accountId;
  const AccountDetailPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... (build 方法主体保持不变)
    final asyncAccount = ref.watch(accountDetailProvider(accountId));
    final asyncPerformance = ref.watch(accountPerformanceProvider(accountId));
    return Scaffold(
      appBar: AppBar(
        title: Text(asyncAccount.asData?.value?.name ?? '加载中...'),
      ),
      body: asyncPerformance.when(
        data: (performance) {
          final account = asyncAccount.asData!.value!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildMacroView(context, ref, account, performance),
              const SizedBox(height: 24),
              _buildMicroView(context),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('发生错误: $err')),
      ),
    );
  }

  Widget _buildMacroView(BuildContext context, WidgetRef ref, Account account, Map<String, dynamic> performance) {
    // ... (这部分保持不变)
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
    final totalProfit = performance['totalProfit'] ?? 0.0;
    final profitRate = performance['profitRate'] ?? 0.0;
    final annualizedReturn = performance['annualizedReturn'] ?? 0.0;
    Color profitColor = totalProfit > 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('账户概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _buildMetricRow(context, '当前总值:', currencyFormat.format(performance['currentValue'] ?? 0.0)),
            _buildMetricRow(context, '净投入:', currencyFormat.format(performance['netInvestment'] ?? 0.0)),
            _buildMetricRow(context, '总收益:', '${currencyFormat.format(totalProfit)} (${percentFormat.format(profitRate)})', color: profitColor),
            _buildMetricRow(context, '年化收益率:', percentFormat.format(annualizedReturn), color: annualizedReturn > 0 ? Colors.red.shade400 : Colors.green.shade400),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () { _showInvestWithdrawDialog(context, ref, account); }, child: const Text('资金操作')),
                ElevatedButton(onPressed: () { _showUpdateValueDialog(context, ref, account); }, child: const Text('更新总值')),
              ],
            )
          ],
        ),
      ),
    );
  }
  
  // --- “资金操作”对话框修改 ---
  void _showInvestWithdrawDialog(BuildContext context, WidgetRef ref, Account account) {
    final amountController = TextEditingController();
    final List<bool> isSelected = [true, false];
    // --- 新增：日期状态变量 ---
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('资金操作'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToggleButtons(
                    isSelected: isSelected,
                    onPressed: (index) { setState(() { isSelected[0] = index == 0; isSelected[1] = index == 1; }); },
                    borderRadius: BorderRadius.circular(8.0),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('投入')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('转出')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '金额', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  // --- 新增：日期选择UI ---
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontSize: 16)),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() { selectedDate = pickedDate; });
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      final isar = DatabaseService().isar;
                      final newTxn = AccountTransaction()
                        ..amount = amount
                        ..date = selectedDate // --- 修改：使用选择的日期 ---
                        ..type = isSelected[0] ? TransactionType.invest : TransactionType.withdraw
                        ..account.value = account;
                      await isar.writeTxn(() async { await isar.accountTransactions.put(newTxn); await newTxn.account.save(); });
                      ref.invalidate(accountPerformanceProvider(account.id));
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- “更新总值”对话框修改 ---
  void _showUpdateValueDialog(BuildContext context, WidgetRef ref, Account account) {
    final valueController = TextEditingController();
    // --- 新增：日期状态变量 ---
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        // --- 新增：使用StatefulBuilder来更新对话框内的日期显示 ---
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新账户总值'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '当前总资产价值', prefixText: '¥ ')),
                  const SizedBox(height: 16),
                  // --- 新增：日期选择UI ---
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontSize: 16)),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() { selectedDate = pickedDate; });
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final value = double.tryParse(valueController.text);
                    if (value != null) {
                      final isar = DatabaseService().isar;
                      final newTxn = AccountTransaction()
                        ..amount = value
                        ..date = selectedDate // --- 修改：使用选择的日期 ---
                        ..type = TransactionType.updateTotalValue
                        ..account.value = account;
                      await isar.writeTxn(() async { await isar.accountTransactions.put(newTxn); await newTxn.account.save(); });
                      ref.invalidate(accountPerformanceProvider(account.id));
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMicroView(BuildContext context) { /* ... 保持不变 ... */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('持仓资产', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ]),
        const Divider(height: 20),
        const Card(child: ListTile(title: Text('...'))),
      ],
    );
  }

  Widget _buildMetricRow(BuildContext context, String title, String value, {Color? color}) { /* ... 保持不变 ... */
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
// 文件: lib/pages/account_detail_page.dart
// (这是已移除 Provider 并修复了所有语法错误的完整文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart'; 
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/transaction_history_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; 
import 'package:one_five_one_ten/services/supabase_sync_service.dart';


// --- (*** 排序标准枚举 ***) ---
enum AssetSortCriteria {
  marketValue,    
  totalProfit,    
  profitRate,     
  annualizedReturn, 
}

// --- (*** 1. 关键修复：添加缺失的枚举定义 ***) ---
enum AccountChartType {
  totalValue,
  totalProfit,
  profitRate,
}
// --- (*** 修复结束 ***) ---


// (*** 关键修复：顶部的所有 Provider 定义都已被【移除】 ***)


// (转换为 ConsumerStatefulWidget)
class AccountDetailPage extends ConsumerStatefulWidget {
  final int accountId;
  const AccountDetailPage({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

// (State 类)
class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {

  // (状态变量)
  AssetSortCriteria _sortCriteria = AssetSortCriteria.marketValue; 
  bool _sortAscending = false; 
  AccountChartType _selectedChartType = AccountChartType.totalValue;

  @override
  Widget build(BuildContext context) {
    // (*** 现在 ref.watch 调用的是 global_providers.dart 中的定义 ***)
    final asyncAccount = ref.watch(accountDetailProvider(widget.accountId));
    final asyncPerformance = ref.watch(accountPerformanceProvider(widget.accountId));
    final syncState = ref.watch(priceSyncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(asyncAccount.asData?.value?.name ?? '加载中...'),
        actions: [
          if (syncState == PriceSyncState.loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '同步所有资产价格',
              onPressed: () {
                ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
                ref.invalidate(accountPerformanceProvider(widget.accountId));
                ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
              },
            ),
        ],
      ),
      body: asyncPerformance.when(
        data: (performance) {
          if (asyncAccount.asData?.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final account = asyncAccount.asData!.value!;
          return RefreshIndicator(
               onRefresh: () async {
                ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
                ref.invalidate(accountPerformanceProvider(widget.accountId));
                ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
                await ref.read(accountHistoryProvider(account).future);
               },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildMacroView(context, ref, account, performance),
                const SizedBox(height: 24),
                _buildMicroView(widget.accountId, account), 
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('发生错误: $err')),
      ),
    );
  }

  
  // ( _buildMacroView, _showInvestWithdrawDialog, _showUpdateValueDialog 保持不变 )
  Widget _buildMacroView(BuildContext context, WidgetRef ref, Account account,
    Map<String, dynamic> performance) {
  
  final percentFormat =
      NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;
  final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
  final profitRate = (performance['profitRate'] ?? 0.0) as double;
  final annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
  Color profitColor =
      totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
  if (totalProfit == 0) {
    profitColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  }

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('账户概览',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: '查看更新记录',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionHistoryPage(accountId: account.id),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 20),
          _buildMetricRow(
            context,
            '当前总值:',
            formatCurrency(performance['currentValue'] ?? 0.0, account.currency),
          ),
          _buildMetricRow(
            context,
            '净投入:',
            formatCurrency(performance['netInvestment'] ?? 0.0, account.currency),
          ),
          _buildMetricRow(
            context,
            '总收益:',
            '${formatCurrency(totalProfit, account.currency)} (${percentFormat.format(profitRate)})',
            color: profitColor,
          ),
          _buildMetricRow(
            context,
            '年化收益率:',
            percentFormat.format(annualizedReturn),
            color: annualizedReturn > 0
                ? Colors.red.shade400
                : Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                  onPressed: () {
                    _showInvestWithdrawDialog(context, ref, account);
                  },
                  child: const Text('资金操作')),
              ElevatedButton(
                  onPressed: () {
                    _showUpdateValueDialog(context, ref, account);
                  },
                  child: const Text('更新总值')),
            ],
          )
        ],
      ),
    ),
  );
}

  void _showInvestWithdrawDialog(
      BuildContext context, WidgetRef ref, Account account) {
    final amountController = TextEditingController();
    final List<bool> isSelected = [true, false];
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
                    onPressed: (index) {
                      setState(() {
                        isSelected[0] = index == 0;
                        isSelected[1] = index == 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('投入')),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('转出')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: '金额', prefixText: getCurrencySymbol(account.currency))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    try {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入有效的金额')),
                        );
                        return;
                      }

                      final syncService = ref.read(syncServiceProvider);
                      
                      final newTxn = AccountTransaction()
                        ..amount = amount
                        ..date = selectedDate
                        ..createdAt = DateTime.now() 
                        ..type = isSelected[0]
                            ? TransactionType.invest
                            : TransactionType.withdraw
                        ..accountSupabaseId = account.supabaseId; 

                      final isar = DatabaseService().isar; 
                      await isar.writeTxn(() async {
                        await isar.accountTransactions.put(newTxn);
                      });

                      await syncService.saveAccountTransaction(newTxn);

                      ref.invalidate(accountPerformanceProvider(account.id)); 
                      ref.invalidate(dashboardDataProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).push( 
                          MaterialPageRoute(
                            builder: (_) => TransactionHistoryPage(accountId: account.id),
                          ),
                        );
                      }
                    } catch (e) {
                      print('资金操作失败: $e');
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('操作失败: $e')),
                        );
                      }
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

  void _showUpdateValueDialog(
      BuildContext context, WidgetRef ref, Account account) {
    final valueController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('更新账户总值'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: valueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: '当前总资产价值', prefixText: getCurrencySymbol(account.currency))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("日期:", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                       try {
                        final value = double.tryParse(valueController.text);
                        if (value == null) { 
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入有效的价值')),
                          );
                          return;
                        }

                        final syncService = ref.read(syncServiceProvider);

                        final newTxn = AccountTransaction()
                          ..amount = value
                          ..date = selectedDate
                          ..createdAt = DateTime.now() 
                          ..type = TransactionType.updateValue
                          ..accountSupabaseId = account.supabaseId; 
                        
                        final isar = DatabaseService().isar;
                         await isar.writeTxn(() async {
                          await isar.accountTransactions.put(newTxn);
                        });

                        await syncService.saveAccountTransaction(newTxn);
                        
                        ref.invalidate(accountPerformanceProvider(account.id));
                        ref.invalidate(dashboardDataProvider);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                            Navigator.of(context).push(
                             MaterialPageRoute(
                                builder: (_) => TransactionHistoryPage(accountId: account.id),
                             ),
                           );
                        }
                      } catch (e) {
                        print('更新总值失败: $e');
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('操作失败: $e')),
                          );
                        }
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
  
  Widget _buildMicroView(int accountId, Account account) {
    final asyncAssets = ref.watch(trackedAssetsWithPerformanceProvider(accountId));
    
    return Column(
      children: [
        ref.watch(accountHistoryProvider(account)).when( 
          data: (chartDataMap) { 
            
            List<FlSpot> spots;
            String chartTitle;
            bool isPercentage = false; 

            switch (_selectedChartType) {
              case AccountChartType.totalProfit:
                spots = chartDataMap['totalProfit'] ?? [];
                chartTitle = '累计收益趋势';
                break;
              case AccountChartType.profitRate:
                spots = chartDataMap['profitRate'] ?? [];
                chartTitle = '收益率趋势';
                isPercentage = true;
                break;
              case AccountChartType.totalValue:
              default:
                spots = chartDataMap['totalValue'] ?? [];
                chartTitle = '账户净值趋势';
                break;
            }

            if (spots.length < 2) return const SizedBox.shrink();
            
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chartTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    LayoutBuilder(
                      builder: (context, constraints) {
                        
                        // --- (*** 2. 关键修复：修正 SegmentedButton 语法 ***) ---
                        return SegmentedButton<AccountChartType>(
                          segments: const [
                            ButtonSegment(value: AccountChartType.totalValue, label: Text('净值'), icon: Icon(Icons.show_chart)),
                            ButtonSegment(value: AccountChartType.totalProfit, label: Text('收益'), icon: Icon(Icons.trending_up)),
                            ButtonSegment(value: AccountChartType.profitRate, label: Text('收益率'), icon: Icon(Icons.percent)),
                          ],
                          selected: {_selectedChartType},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _selectedChartType = newSelection.first;
                            });
                          },
                          // (*** 修复：将 showSelectedIcon 移到正确的位置 ***)
                          showSelectedIcon: constraints.maxWidth >= 360,
                          // (*** 修复：移除无效的 style: 属性 ***)
                          // style: constraints.maxWidth < 360 
                          //   ? SegmentedButton.styleFrom(showSelectedIcon: false) // <-- 这是错误的
                          //   : null,
                        );
                        // --- (*** 修复结束 ***) ---
                      }
                    ),
                    const SizedBox(height: 24),
                    
                    _buildHistoryChart(context, spots, account, isPercentage), 
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e,s) => Text('图表加载失败: $e'),
        ),
        
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('持仓资产', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                PopupMenuButton<AssetSortCriteria>(
                  onSelected: (criteria) {
                    setState(() {
                      if (_sortCriteria == criteria) {
                        _sortAscending = !_sortAscending;
                      } else {
                        _sortCriteria = criteria;
                        _sortAscending = false;
                      }
                    });
                  },
                  icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.primary),
                  tooltip: '排序',
                  itemBuilder: (context) => [
                    _buildSortMenuItem(AssetSortCriteria.marketValue, '按持仓金额'),
                    _buildSortMenuItem(AssetSortCriteria.totalProfit, '按收益金额'),
                    _buildSortMenuItem(AssetSortCriteria.profitRate, '按收益率'),
                    _buildSortMenuItem(AssetSortCriteria.annualizedReturn, '按年化收益率'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '添加持仓资产',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEditAssetPage(accountId: accountId), 
                      ),
                    ).then((_) {
                      ref.invalidate(accountDetailProvider(accountId));
                      ref.invalidate(accountPerformanceProvider(accountId));
                      ref.invalidate(trackedAssetsWithPerformanceProvider(accountId)); 
                    });
                  },
                ),
              ],
            )
          ],
        ),
        
        const Divider(height: 20),
        asyncAssets.when(
          data: (assetsData) {
            
            final sortedAssets = _sortAssetList(assetsData, _sortCriteria, _sortAscending);
            
            if (sortedAssets.isEmpty) { 
              return const Card(child: ListTile(title: Text('暂无持仓资产')));
            }
            return Column(
              children: sortedAssets.map((assetData) => _buildAssetCard(context, ref, assetData, accountId)).toList(), 
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('加载资产失败: $err')),
        )
      ],
    );
  }
  
  PopupMenuItem<AssetSortCriteria> _buildSortMenuItem(AssetSortCriteria criteria, String text) {
    bool isSelected = _sortCriteria == criteria;
    return PopupMenuItem(
      value: criteria,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          if (isSelected)
            Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 20),
        ],
      ),
    );
  }

  double _getSortableValue(Map<String, dynamic> assetData, AssetSortCriteria criteria) {
    final performance = assetData['performance'] as Map<String, dynamic>;
    final asset = assetData['asset'] as Asset;

    switch (criteria) {
      case AssetSortCriteria.marketValue:
        return (asset.trackingMethod == AssetTrackingMethod.shareBased
            ? performance['marketValue']
            : performance['currentValue']) ?? 0.0;
      case AssetSortCriteria.totalProfit:
        return (performance['totalProfit'] ?? 0.0) as double;
      case AssetSortCriteria.profitRate:
        return (performance['profitRate'] ?? 0.0) as double;
      case AssetSortCriteria.annualizedReturn:
        return (performance['annualizedReturn'] ?? 0.0) as double;
    }
  }

  List<Map<String, dynamic>> _sortAssetList(List<Map<String, dynamic>> list, AssetSortCriteria criteria, bool ascending) {
    final sortedList = List<Map<String, dynamic>>.from(list);
    
    sortedList.sort((a, b) {
      final valA = _getSortableValue(a, criteria);
      final valB = _getSortableValue(b, criteria);
      
      if (valA.isNaN && valB.isNaN) return 0;
      if (valA.isNaN) return 1; 
      if (valB.isNaN) return -1; 

      final comparison = valA.compareTo(valB);
      return ascending ? comparison : -comparison; 
    });
    
    return sortedList;
  }

  Widget _buildAssetCard(BuildContext context, WidgetRef ref, Map<String, dynamic> assetData, int accountId) {
    final Asset asset = assetData['asset'];
    final Map<String, dynamic> performance = assetData['performance'];
    
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    final double totalValue = _getSortableValue(assetData, AssetSortCriteria.marketValue); 
    
    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    
    Color profitColor = totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Card(
      child: ListTile(
        leading: Icon(asset.trackingMethod == AssetTrackingMethod.shareBased 
          ? Icons.pie_chart_outline
          : Icons.account_balance_wallet_outlined),
        title: Text('${asset.name} (${asset.currency})', style: const TextStyle(fontWeight: FontWeight.bold)),
        
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (asset.code.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  asset.code,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 4), 
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('市值/价值: ${formatCurrency(totalValue, asset.currency)}', overflow: TextOverflow.ellipsis)),
                Text('收益: ${formatCurrency(totalProfit, asset.currency)} (${percentFormat.format(profitRate)})', 
                  style: TextStyle(color: profitColor)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  asset.priceUpdateDate != null 
                    ? '价格 @ ${DateFormat('MM-dd HH:mm').format(asset.priceUpdateDate!)}'
                    : '价格未更新', 
                  style: const TextStyle(fontSize: 12, color: Colors.grey)
                ),
                Text('年化: ${percentFormat.format(annualizedReturn)}',
                  style: TextStyle(color: profitColor, fontSize: 12)),
              ],
            )
          ],
        ),

        trailing: const Icon(Icons.arrow_forward_ios),
        
        onTap: () {
          final pageRoute = MaterialPageRoute(builder: (context) {
            return asset.trackingMethod == AssetTrackingMethod.shareBased
                ? ShareAssetDetailPage(assetId: asset.id)
                : ValueAssetDetailPage(assetId: asset.id);
          });

          Navigator.of(context).push(pageRoute).then((_) {
            ref.invalidate(accountDetailProvider(accountId));
            ref.invalidate(accountPerformanceProvider(accountId));
            ref.invalidate(trackedAssetsWithPerformanceProvider(accountId)); 
          });
        },
        
        onLongPress: () => _showDeleteAssetConfirmationDialog(context, ref, asset, accountId), 
      ),
    );
  }

  void _showDeleteAssetConfirmationDialog(BuildContext context, WidgetRef ref, Asset asset, int accountId) {
    // ( ... 此函数保持不变 ...)
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('删除资产 "${asset.name}"'),
          content: const Text('此操作不可撤销，将删除此资产下的所有记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed:() => Navigator.of(dialogContext).pop(true),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((ok) async {
      if (ok != true) return;
      
      final syncService = ref.read(syncServiceProvider);
      final isar = DatabaseService().isar;

      if (asset.supabaseId != null) {
          final txs = await isar.transactions.where()
                          .filter()
                          .assetSupabaseIdEqualTo(asset.supabaseId)
                          .findAll();
          final snaps = await isar.positionSnapshots.where()
                                .filter()
                                .assetSupabaseIdEqualTo(asset.supabaseId)
                                .findAll();
          
          for (final tx in txs) { await syncService.deleteTransaction(tx); }
          for (final snap in snaps) { await syncService.deletePositionSnapshot(snap); }
      }
      
      await syncService.deleteAsset(asset); 

      ref.invalidate(accountPerformanceProvider(accountId));
      ref.invalidate(dashboardDataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除资产：${asset.name}')),
        );
      }
    });
  }

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots, Account account, bool isPercentage) {
    
    final NumberFormat yAxisFormat;
    if (isPercentage) {
      yAxisFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;
    } else {
      yAxisFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: getCurrencySymbol(account.currency));
    }
    
    final colorScheme = Theme.of(context).colorScheme;
    
    final List<FlSpot> indexedSpots = [];
    for (int i = 0; i < spots.length; i++) {
      indexedSpots.add(FlSpot(i.toDouble(), spots[i].y));
    }
    
    double bottomInterval;
    const desiredLabelCount = 4.0;
    if (spots.length <= desiredLabelCount) {
      bottomInterval = 1; 
    } else {
      bottomInterval = (spots.length - 1) / desiredLabelCount;
      if (bottomInterval < 1) bottomInterval = 1;
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0, 
          maxX: (spots.length - 1).toDouble(), 

          lineBarsData: [
            LineChartBarData(
              spots: indexedSpots,
              isCurved: false,
              barWidth: 3,
              color: colorScheme.primary, 
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(yAxisFormat.format(value), style: const TextStyle(fontSize: 10)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 30, 
                interval: bottomInterval, 
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index >= 0 && index < spots.length) {
                    final originalSpot = spots[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('yy-MM-dd').format(date), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center,),
                    );
                  }
                  return const Text('');
                }
              )
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpotsList) {
                return touchedSpotsList.map((touchedSpot) {
                  final int index = touchedSpot.x.round();
                  
                  if (index < 0 || index >= spots.length) {
                       return null;
                  }

                  final FlSpot originalSpot = spots[index];
                  final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                  
                  final String valueStr;
                  if (isPercentage) {
                    valueStr = (NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2).format(originalSpot.y);
                  } else {
                    valueStr = formatCurrency(originalSpot.y, account.currency);
                  }
                  
                  return LineTooltipItem(
                    '$date\n$valueStr', 
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).where((item) => item != null).cast<LineTooltipItem>().toList(); 
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String title, String value,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
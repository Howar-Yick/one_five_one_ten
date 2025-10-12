// 文件: lib/pages/account_detail_page.dart
// (这是已整合“归档/删除”与“搜索”功能的完整文件)

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


// (*** 排序标准枚举 ***)
enum AssetSortCriteria {
  marketValue,    // 持仓金额
  totalProfit,    // 收益金额
  profitRate,     // 收益率
  annualizedReturn, // 年化
}

// (*** 图表类型枚举 ***)
enum AccountChartType {
  totalValue,
  totalProfit,
  profitRate,
}


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

  void _showAssetSearch(BuildContext context, List<Map<String, dynamic>> assets, Account account) {
    showSearch(
      context: context,
      delegate: _AssetSearchDelegate(
        allAssets: assets,
        accountId: widget.accountId,
        account: account,
        ref: ref,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncAccount = ref.watch(accountDetailProvider(widget.accountId));
    final asyncPerformance = ref.watch(accountPerformanceProvider(widget.accountId));
    final syncState = ref.watch(priceSyncControllerProvider);
    final asyncAssets = ref.watch(trackedAssetsWithPerformanceProvider(widget.accountId));

    return Scaffold(
      appBar: AppBar(
        title: Text(asyncAccount.asData?.value?.name ?? '加载中...'),
        actions: [
          
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索资产',
            onPressed: () {
              final assets = asyncAssets.asData?.value ?? [];
              final account = asyncAccount.asData?.value;
              if (account != null) {
                _showAssetSearch(context, assets, account);
              }
            },
          ),
          
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
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            itemBuilder: (context) => [
              _buildSortMenuItem(AssetSortCriteria.marketValue, '按持仓金额'),
              _buildSortMenuItem(AssetSortCriteria.totalProfit, '按收益金额'),
              _buildSortMenuItem(AssetSortCriteria.profitRate, '按收益率'),
              _buildSortMenuItem(AssetSortCriteria.annualizedReturn, '按年化收益率'),
            ],
          ),
          
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
      
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('添加资产'),
        tooltip: '添加持仓资产',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditAssetPage(accountId: widget.accountId),
            ),
          ).then((_) {
            ref.invalidate(accountDetailProvider(widget.accountId));
            ref.invalidate(accountPerformanceProvider(widget.accountId));
            ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
          });
        },
      ),
    );
  }

  // ===================== 以下是所有辅助方法 =====================

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
    // ... (此函数保持不变)
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
    // ... (此函数保持不变)
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
                          showSelectedIcon: constraints.maxWidth >= 360,
                        );
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

        const Align(
          alignment: Alignment.centerLeft,
          child: Text('持仓资产', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildAssetCard(BuildContext context, WidgetRef ref,
      Map<String, dynamic> assetData, int accountId) {
    final Asset asset = assetData['asset'];
    final Map<String, dynamic> performance = assetData['performance'];

    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    final double totalValue =
        _getSortableValue(assetData, AssetSortCriteria.marketValue);

    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn =
        (performance['annualizedReturn'] ?? 0.0) as double;

    Color profitColor =
        totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

    final bool isShareBased =
        asset.trackingMethod == AssetTrackingMethod.shareBased;

    String formattedShares = '';
    String formattedCost = '';
    String formattedPrice = '';

    if (isShareBased) {
      final double totalShares = performance['totalShares'] ?? 0.0;
      final double averageCost = performance['averageCost'] ?? 0.0;
      final double latestPrice = performance['latestPrice'] ?? 0.0;
      
      if (asset.subType == AssetSubType.mutualFund) {
        formattedShares = '份额: ${totalShares.toStringAsFixed(2)}';
        formattedCost = '成本: ${averageCost.toStringAsFixed(4)}';
        formattedPrice = '价格: ${latestPrice.toStringAsFixed(4)}';
      } else if (asset.subType == AssetSubType.etf ||
          asset.subType == AssetSubType.stock) {
        formattedShares = '份额: ${totalShares.toStringAsFixed(0)}';
        formattedCost = '成本: ${averageCost.toStringAsFixed(3)}';
        formattedPrice = '价格: ${latestPrice.toStringAsFixed(3)}';
      } else {
        formattedShares = '份额: ${totalShares.toStringAsFixed(2)}';
        formattedCost = '成本: ${averageCost.toStringAsFixed(4)}';
        formattedPrice = '价格: ${latestPrice.toStringAsFixed(4)}';
      }
    }

    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: Icon(isShareBased
            ? Icons.pie_chart_outline
            : Icons.account_balance_wallet_outlined),
        title: Text('${asset.name} (${asset.currency})',
            style: const TextStyle(fontWeight: FontWeight.bold)),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asset.code.isNotEmpty)
                Text(
                  asset.code,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              
              const SizedBox(height: 8),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isShareBased) ...[
                          _buildInfoRow(formattedShares, color: Colors.grey),
                          const SizedBox(height: 4),
                          _buildInfoRow(formattedCost, color: Colors.grey),
                          const SizedBox(height: 4),
                          _buildInfoRow(formattedPrice, color: Colors.grey),
                        ]
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),

                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          '总值: ${formatCurrency(totalValue, asset.currency)}'
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          '收益: ${formatCurrency(totalProfit, asset.currency)} (${percentFormat.format(profitRate)})',
                          color: profitColor
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          '年化: ${percentFormat.format(annualizedReturn)}',
                          color: profitColor
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
        // ★★★ 修复点: 调用新的 _showDeleteOrArchiveDialog 方法 ★★★
        onLongPress: () => _showDeleteOrArchiveDialog(context, ref, asset, accountId),
      ),
    );
  }

  Widget _buildInfoRow(String text, {Color? color}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ★★★ 修复点: 这是新的“归档/删除”对话框方法 ★★★
  void _showDeleteOrArchiveDialog(BuildContext context, WidgetRef ref, Asset asset, int accountId) {
    showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('操作资产 "${asset.name}"'),
          content: const Text('“归档”会将已清仓的资产移至历史记录，保留其盈亏分析。\n“彻底删除”将永久抹掉此资产及其所有记录，用于修正错误录入。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('archive'),
              child: const Text('归档'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('delete'),
              child: const Text('彻底删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((result) async {
      if (result == null) return;

      final syncService = ref.read(syncServiceProvider);
      final isar = DatabaseService().isar;

      if (result == 'archive') {
        asset.isArchived = true;
        await syncService.saveAsset(asset);
        
        ref.invalidate(trackedAssetsWithPerformanceProvider(accountId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已归档资产：${asset.name}')),
          );
        }

      } else if (result == 'delete') {
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
            SnackBar(content: Text('已彻底删除资产：${asset.name}')),
          );
        }
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
              dotData: FlDotData(show: spots.length < 40),
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

// (*** 3. 关键修改：添加处理资产搜索的委托类 ***)
class _AssetSearchDelegate extends SearchDelegate<Asset?> {
  final List<Map<String, dynamic>> allAssets;
  final int accountId;
  final Account account;
  final WidgetRef ref;

  _AssetSearchDelegate({
    required this.allAssets,
    required this.accountId,
    required this.account,
    required this.ref,
  });

  @override
  String get searchFieldLabel => '搜索资产名称或代码';

  @override
  List<Widget>? buildActions(BuildContext context) {
    // 搜索框右侧的动作按钮，这里是一个清除按钮
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    // 搜索框左侧的按钮，这里是一个返回按钮
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // 当用户在键盘上点击“搜索”后显示的结果
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // 当用户在搜索框中输入时，动态显示的建议
    return _buildSearchResults(context);
  }

  // 辅助方法，用于构建搜索结果和建议的列表
  Widget _buildSearchResults(BuildContext context) {
    final suggestions = allAssets.where((assetData) {
      final asset = assetData['asset'] as Asset;
      final input = query.toLowerCase();
      final name = asset.name.toLowerCase();
      final code = asset.code.toLowerCase();
      // 模糊匹配资产名称或代码
      return name.contains(input) || code.contains(input);
    }).toList();

    if (query.isEmpty) {
      return const Center(
        child: Text('请输入资产名称或代码进行搜索'),
      );
    }
    
    if (suggestions.isEmpty) {
      return const Center(
        child: Text('未找到匹配的资产'),
      );
    }

    // 使用 ListView 显示过滤后的资产列表
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final assetData = suggestions[index];
        final asset = assetData['asset'] as Asset;
        final performance = assetData['performance'] as Map<String, dynamic>;
        final totalValue = (asset.trackingMethod == AssetTrackingMethod.shareBased
                ? performance['marketValue']
                : performance['currentValue']) ?? 0.0;

        return ListTile(
          leading: Icon(asset.trackingMethod == AssetTrackingMethod.shareBased
              ? Icons.pie_chart_outline
              : Icons.account_balance_wallet_outlined),
          title: Text(asset.name),
          subtitle: Text(asset.code.isNotEmpty ? asset.code : '价值型资产'),
          trailing: Text(formatCurrency(totalValue, account.currency)),
          onTap: () {
            // 点击后，关闭搜索页面并导航到资产详情页
            close(context, asset); 
            
            final pageRoute = MaterialPageRoute(builder: (context) {
              return asset.trackingMethod == AssetTrackingMethod.shareBased
                  ? ShareAssetDetailPage(assetId: asset.id)
                  : ValueAssetDetailPage(assetId: asset.id);
            });

            Navigator.of(context).push(pageRoute).then((_) {
              // 从详情页返回后，刷新相关数据
              ref.invalidate(accountDetailProvider(accountId));
              ref.invalidate(accountPerformanceProvider(accountId));
              ref.invalidate(trackedAssetsWithPerformanceProvider(accountId));
            });
          },
        );
      },
    );
  }
}
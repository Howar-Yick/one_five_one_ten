import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';

final globalPerformanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // 当任何一个账户的数据发生变化时，我们希望这个Provider能刷新
  // 这是一个简化的刷新机制，更复杂的可以监听所有账户
  // 为简单起见，我们暂时不加自动刷新，后续可以优化
  return CalculatorService().calculateGlobalPerformance();
});

final assetAllocationProvider = FutureProvider<Map<AssetSubType, double>>((ref) {
  // 当全局数据变化时，这个也应该刷新
  ref.watch(globalPerformanceProvider); 
  return CalculatorService().calculateAssetAllocation();
});

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _touchedIndex = -1; // -1 表示没有扇区被触摸

  String _getSubTypeLabel(AssetSubType subType) {
    switch (subType) {
      case AssetSubType.stock:
        return '股票';
      case AssetSubType.etf:
        return '场内基金';
      case AssetSubType.mutualFund:
        return '场外基金';
      case AssetSubType.other:
      default:
        return '其他资产';
    }
  }

  // 为不同资产类型分配颜色
  Color _getColorForSubType(AssetSubType subType, int index) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final asyncPerformance = ref.watch(globalPerformanceProvider);
    final asyncAllocation = ref.watch(assetAllocationProvider);
    
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新数据',
            onPressed: () {
              ref.invalidate(globalPerformanceProvider);
              ref.invalidate(assetAllocationProvider);
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(globalPerformanceProvider);
          ref.invalidate(assetAllocationProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            asyncPerformance.when(
              data: (performance) {
                final totalValue = (performance['totalValue'] ?? 0.0) as double;
                final totalProfit = (performance['totalProfit'] ?? 0.0) as double;
                final totalProfitRate = (performance['totalProfitRate'] ?? 0.0) as double;
                final globalAnnualizedReturn = (performance['globalAnnualizedReturn'] ?? 0.0) as double;
                Color profitColor = totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('总资产', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(currencyFormat.format(totalValue), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _buildMetricRow(context, '累计收益:', '${currencyFormat.format(totalProfit)} (${percentFormat.format(totalProfitRate)})', profitColor),
                        const SizedBox(height: 8),
                        _buildMetricRow(context, '总年化收益率:', percentFormat.format(globalAnnualizedReturn), profitColor),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(child: SizedBox(height: 170, child: Center(child: CircularProgressIndicator()))),
              error: (err, stack) => Card(child: SizedBox(height: 170, child: Center(child: Text('加载失败: $err')))),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    asyncAllocation.when(
                      data: (allocation) {
                        if (allocation.isEmpty) {
                          return const SizedBox(height: 200, child: Center(child: Text('暂无持仓资产数据')));
                        }
                        
                        final totalAssetValue = allocation.values.fold(0.0, (sum, item) => sum + item);
                        int colorIndex = 0;

                        return Column(
                          children: [
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  sections: List.generate(allocation.length, (index) {
                                    final isTouched = index == _touchedIndex;
                                    final radius = isTouched ? 90.0 : 80.0;
                                    final entry = allocation.entries.elementAt(index);
                                    final percentage = (entry.value / totalAssetValue) * 100;
                                    
                                    return PieChartSectionData(
                                      value: entry.value,
                                      title: '${percentage.toStringAsFixed(1)}%',
                                      color: _getColorForSubType(entry.key, index),
                                      radius: radius,
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                                      badgeWidget: isTouched ? _buildBadge(_getSubTypeLabel(entry.key)) : null,
                                      badgePositionPercentageOffset: .98,
                                    );
                                  }),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ...List.generate(allocation.length, (index) {
                              final entry = allocation.entries.elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  children: [
                                    Container(width: 16, height: 16, color: _getColorForSubType(entry.key, index)),
                                    const SizedBox(width: 8),
                                    Text('${_getSubTypeLabel(entry.key)} (${percentFormat.format(entry.value/totalAssetValue)})'),
                                    const Spacer(),
                                    Text(currencyFormat.format(entry.value))
                                  ],
                                ),
                              );
                            })
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                      error: (err, stack) => SizedBox(height: 200, child: Center(child: Text('加载失败: $err'))),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
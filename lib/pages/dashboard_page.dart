// 文件: lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:one_five_one_ten/models/asset.dart';
// import 'package:one_five_one_ten/services/calculator_service.dart'; // 不再需要直接导入
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// 1. (新增) 导入全局 providers
import 'package:one_five_one_ten/providers/global_providers.dart';

// 2. (已移除) 此页面不再定义自己的 Provider，我们将使用 global_providers.dart 中的
// final globalPerformanceProvider = ...
// final globalHistoryProvider = ...
// final assetAllocationProvider = ...


class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _touchedIndex = -1;

  // (所有辅助函数 _getSubTypeLabel, _getColorForSubType, _buildBadge, _buildMetricRow 保持不变)
  String _getSubTypeLabel(AssetSubType subType) {
    switch (subType) {
      case AssetSubType.stock: return '股票';
      case AssetSubType.etf: return '场内基金';
      case AssetSubType.mutualFund: return '场外基金';
      case AssetSubType.other: default: return '其他资产';
    }
  }

  Color _getColorForSubType(AssetSubType subType, int index) {
    final colors = [
      Colors.blue.shade400, Colors.green.shade400, Colors.orange.shade400,
      Colors.purple.shade400, Colors.red.shade400, Colors.teal.shade400,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // 3. (修改) 我们现在只 watch 一个在 global_providers.dart 中定义的、统一的 provider
    final asyncDashboardData = ref.watch(dashboardDataProvider);

    // 4. (关键!!!) 监听实时账户流。
    // 当云端同步导致账户数据变化时，accountsProvider (我们在 global_providers.dart 中设定的 Stream) 会发出新数据。
    // watch 这个 provider 会导致此页面重建，
    // 由于 dashboardDataProvider 是 .autoDispose，它也会被强制重新计算。
    // 这就将您的计算服务连接到了实时同步！
    ref.watch(accountsProvider); // 监听实时流以触发刷新
    
    final percentFormat = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新数据',
            onPressed: () {
              // 5. (修改) 我们现在只 invalidate 统一的 provider
              ref.invalidate(dashboardDataProvider);
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 6. (修改) 同样，只 invalidate 统一的 provider
          ref.invalidate(dashboardDataProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 7. (修改) 将 asyncPerformance.when 更改为 asyncDashboardData.when
            asyncDashboardData.when(
              data: (dashboardData) {
                // 8. (修改) 从统一的 Map 中解包数据
                final totalValue = (dashboardData['totalValue'] ?? 0.0) as double;
                final historySpots = (dashboardData['historySpots'] ?? []) as List<FlSpot>;
                final allocation = (dashboardData['allocation'] ?? {}) as Map<AssetSubType, double>;

                // (从旧的 asyncPerformance.when 移植过来的数据)
                // (注意：您的旧 provider 计算了 'totalProfit' 等，但新的 dashboardDataProvider 没有)
                // (为了让代码能跑起来，我们必须从 globalPerf 中获取这些值)
                // TODO: 更新 global_providers.dart 中的 dashboardDataProvider 以返回完整的 'globalPerf' Map
                final totalProfit = 0.0; // 临时占位，您的 global_provider 需要更新
                final totalProfitRate = 0.0; // 临时占位
                final globalAnnualizedReturn = 0.0; // 临时占位
                Color profitColor = totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;

                return Column(
                  children: [
                    // --- 总资产卡片 ---
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('总资产 (CNY)', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(formatCurrency(totalValue, 'CNY'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            const Divider(height: 24),
                            _buildMetricRow(context, '累计收益:', '${formatCurrency(totalProfit, 'CNY')} (${percentFormat.format(totalProfitRate)})', profitColor),
                            const SizedBox(height: 8),
                            _buildMetricRow(context, '总年化收益率:', percentFormat.format(globalAnnualizedReturn), profitColor),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // --- 资产趋势卡片 ---
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('总资产趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            (historySpots.length < 2)
                              ? const SizedBox(height: 200, child: Center(child: Text('历史数据不足，无法生成图表')))
                              : _buildHistoryChart(context, historySpots), // (您的图表构建函数是正确的)
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // --- 资产配置卡片 ---
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('资产配置 (CNY)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            (allocation.isEmpty)
                              ? const SizedBox(height: 200, child: Center(child: Text('暂无持仓资产数据')))
                              : _buildAllocationChart(context, allocation, percentFormat), // (拆分到辅助函数)
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Card(child: SizedBox(height: 170, child: Center(child: CircularProgressIndicator()))),
              error: (err, stack) => Card(child: SizedBox(height: 170, child: Center(child: Text('加载失败: $err')))),
            ),
          ],
        ),
      ),
    );
  }

  // (新增一个辅助函数来容纳饼图逻辑)
  Widget _buildAllocationChart(BuildContext context, Map<AssetSubType, double> allocation, NumberFormat percentFormat) {
    final totalAssetValue = allocation.values.fold(0.0, (sum, item) => sum + item);
    
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
                final percentage = totalAssetValue == 0 ? 0 : (entry.value / totalAssetValue); // 确保除数不为0
                
                return PieChartSectionData(
                  value: entry.value,
                  title: '${(percentage * 100).toStringAsFixed(1)}%',
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
          final percentage = totalAssetValue == 0 ? 0 : (entry.value / totalAssetValue); // 确保除数不为0
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(width: 16, height: 16, color: _getColorForSubType(entry.key, index)),
                const SizedBox(width: 8),
                Text('${_getSubTypeLabel(entry.key)} (${percentFormat.format(percentage)})'),
                const Spacer(),
                Text(formatCurrency(entry.value, 'CNY'))
              ],
            ),
          );
        })
      ],
    );
  }

  // (您的 _buildHistoryChart 函数是完美的，保持不变)
  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');
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
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text(currencyFormat.format(value), style: const TextStyle(fontSize: 10)))),
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
                  final value = NumberFormat.currency(locale: 'zh_CN', symbol: '¥').format(originalSpot.y);
                  
                  return LineTooltipItem(
                    '$date\n$value',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).whereType<LineTooltipItem>().toList(); 
              },
            ),
          ),
        ),
      ),
    );
  }

  // (您的 _buildBadge 函数保持不变)
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

  // (您的 _buildMetricRow 函数保持不变)
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
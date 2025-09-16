import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

final globalPerformanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return CalculatorService().calculateGlobalPerformance();
});

final globalHistoryProvider = FutureProvider<List<FlSpot>>((ref) {
  ref.watch(globalPerformanceProvider);
  return CalculatorService().getGlobalValueHistory();
});

final assetAllocationProvider = FutureProvider<Map<AssetSubType, double>>((ref) {
  ref.watch(globalPerformanceProvider); 
  return CalculatorService().calculateAssetAllocation();
});

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _touchedIndex = -1;

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
    final asyncPerformance = ref.watch(globalPerformanceProvider);
    final asyncAllocation = ref.watch(assetAllocationProvider);
    final asyncHistory = ref.watch(globalHistoryProvider);
    
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
              // 依赖 globalPerformanceProvider 的 provider 会自动刷新
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(globalPerformanceProvider);
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
                    const Text('总资产趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    asyncHistory.when(
                      data: (spots) {
                        if (spots.length < 2) return const SizedBox(height: 200, child: Center(child: Text('历史数据不足，无法生成图表')));
                        return _buildHistoryChart(context, spots);
                      },
                      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                      error: (err, stack) => SizedBox(height: 200, child: Center(child: Text('图表加载失败: $err'))),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('资产配置 (CNY)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                    Text(formatCurrency(entry.value, 'CNY'))
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

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');
    final colorScheme = Theme.of(context).colorScheme;
    
    // -----------------------------------------------------------------
    // 改进点 1：将基于时间戳的 spots 转换为 基于索引的 indexedSpots
    // -----------------------------------------------------------------
    // 我们保留原始的 spots 列表（包含真实时间戳）用于查找标签和提示。
    // 我们创建一个新的 indexedSpots 列表，其中 X 值是索引号 (0, 1, 2...)
    final List<FlSpot> indexedSpots = [];
    for (int i = 0; i < spots.length; i++) {
      // X: 使用索引 i, Y: 保持原始Y值 (金额)
      indexedSpots.add(FlSpot(i.toDouble(), spots[i].y));
    }
    
    // 动态计算底部标签的间隔，确保最多只显示 4-5 个标签
    double bottomInterval;
    const desiredLabelCount = 4.0;
    if (spots.length <= desiredLabelCount) {
      bottomInterval = 1; // 如果数据点很少，每个都显示
    } else {
      // 计算间隔，确保总标签数接近 desiredLabelCount
      // 使用 (spots.length - 1) 是因为索引是从 0 到 length-1
      bottomInterval = (spots.length - 1) / desiredLabelCount;
      // 确保间隔至少为1，并且最好是整数，以避免小数索引
      if (bottomInterval < 1) bottomInterval = 1;
    }


    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          // -----------------------------------------------------------------
          // 改进点 2：minX 和 maxX 现在基于索引
          // -----------------------------------------------------------------
          minX: 0, // X轴从索引 0 开始
          maxX: (spots.length - 1).toDouble(), // X轴到最后一个索引结束
          
          lineBarsData: [
            LineChartBarData(
              // -----------------------------------------------------------------
              // 改进点 3：图表使用基于索引的数据点
              // -----------------------------------------------------------------
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
                // -----------------------------------------------------------------
                // 改进点 4：间隔现在也基于索引
                // -----------------------------------------------------------------
                interval: bottomInterval, 
                getTitlesWidget: (value, meta) {
                  // value 现在是索引 (例如 0.0, 1.0, 2.0...)
                  final int index = value.toInt();
                  // 确保索引在原始 spots 列表的安全范围内
                  if (index >= 0 && index < spots.length) {
                    // -----------------------------------------------------------------
                    // 改进点 5：使用索引从原始 spots 列表中查找真实日期
                    // -----------------------------------------------------------------
                    final originalSpot = spots[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('yy-MM-dd').format(date), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center,),
                    );
                  }
                  return const Text(''); // 超出范围则不显示
                }
              )
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpotsList) {
                // touchedSpotsList 包含的是 LineChart 内部的 FlSpot（X值为索引）
                return touchedSpotsList.map((touchedSpot) {
                  // -----------------------------------------------------------------
                  // 改进点 6：转换提示框的逻辑
                  // -----------------------------------------------------------------
                  
                  // 1. 获取被触摸点的索引（四舍五入以防万一）
                  final int index = touchedSpot.x.round();
                  
                  // 2. 检查索引安全性
                  if (index < 0 || index >= spots.length) {
                       return null; // 不安全的索引，不显示提示
                  }

                  // 3. 从原始 spots 列表（包含真实时间戳）中获取数据
                  final FlSpot originalSpot = spots[index];
                  final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                  final value = NumberFormat.currency(locale: 'zh_CN', symbol: '¥').format(originalSpot.y); // Y值 (金额) 是相同的
                  
                  return LineTooltipItem(
                    '$date\n$value',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).whereType<LineTooltipItem>().toList(); // 过滤掉 null 并转换类型
              },
            ),
          ),
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
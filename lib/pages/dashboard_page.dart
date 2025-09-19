// 文件: lib/pages/dashboard_page.dart
// (这是已修复首页概览指标的完整代码)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // <-- 1. 新增导入
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardDataAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
      ),
      body: dashboardDataAsync.when(
        // --- (*** 2. 这是修改后的 data 分支 ***) ---
        data: (dashboardData) {
          // (我们不再需要在这里单独解析 totalValue)
          final historySpots = (dashboardData['historySpots'] ?? []) as List<FlSpot>;
          final allocation = (dashboardData['allocation'] ?? {}) as Map<AssetSubType, double>;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardDataProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 关键修改：把整个 map 传给 header card
                _buildHeaderCard(context, dashboardData), // <-- 3. 修改了这一行
                
                if (historySpots.length >= 2)
                  _buildChartCard(context, historySpots),
                  
                if (allocation.isNotEmpty)
                  _buildAllocationCard(context, allocation),
              ],
            ),
          );
        },
        // --- (*** 修改结束 ***) ---
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('加载仪表盘失败: $err'),
          ),
        ),
      ),
    );
  }

  // --- (*** 4. 这是完全替换后的 _buildHeaderCard ***) ---
  Widget _buildHeaderCard(BuildContext context, Map<String, dynamic> performance) {
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    // 从 Map 中解析所有性能指标
    final double totalValue = (performance['totalValue'] ?? 0.0) as double;
    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
    final double netInvestment = (performance['netInvestment'] ?? 0.0) as double;

    // 决定颜色
    Color profitColor =
        totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('总览 (CNY)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            // 显示总资产 (大字号)
            Text(
              currencyFormat.format(totalValue),
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 使用我们复制过来的辅助函数显示其他指标
            _buildMetricRow(
              context,
              '净投入:',
              currencyFormat.format(netInvestment),
            ),
            _buildMetricRow(
              context,
              '总收益:',
              '${currencyFormat.format(totalProfit)} (${percentFormat.format(profitRate)})',
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
          ],
        ),
      ),
    );
  }
  // --- (*** 替换结束 ***) ---


  // (这是你原有的 _buildChartCard 函数，保持不变)
  Widget _buildChartCard(BuildContext context, List<FlSpot> spots) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('净值趋势',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(
                            currencyFormat.format(value),
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: bottomInterval,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index >= 0 && index < spots.length) {
                            final date = _getSpotDate(spots, index);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('yy-MM-dd').format(date),
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpotsList) {
                        return touchedSpotsList.map((touchedSpot) {
                          final int index = touchedSpot.x.round();
                          if (index < 0 || index >= spots.length) return null;
                          final date = _getSpotDate(spots, index);
                          final value = spots[index].y;
                          return LineTooltipItem(
                            '${DateFormat('yyyy-MM-dd').format(date)}\n${formatCurrency(value, 'CNY')}',
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          );
                        }).whereType<LineTooltipItem>().toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (这是你原有的 _buildAllocationCard 函数，保持不变)
  Widget _buildAllocationCard(
      BuildContext context, Map<AssetSubType, double> allocation) {
    final List<PieChartSectionData> sections = [];
    final double totalValue =
        allocation.values.fold(0.0, (prev, element) => prev + element);
    
    // (Ensure consistent colors for chart)
    final Map<AssetSubType, Color> colorMap = {
      AssetSubType.stock: Colors.blue.shade400,
      AssetSubType.etf: Colors.green.shade400,
      AssetSubType.mutualFund: Colors.orange.shade400,
      AssetSubType.other: Colors.purple.shade400,
    };

    allocation.forEach((subType, value) {
      final percentage = (value / totalValue) * 100;
      sections.add(
        PieChartSectionData(
          color: colorMap[subType] ?? Colors.grey,
          value: value,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PieChart(PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    )),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: allocation.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: colorMap[entry.key] ?? Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatAllocationName(entry.key),
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- (*** 5. 新增：从 account_detail_page 复制而来的辅助函数 ***) ---
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
  // --- (*** 新增结束 ***) ---
}


// (这是你原有的辅助函数，保持不变)
DateTime _getSpotDate(List<FlSpot> spots, int index) {
  if (index < 0 || index >= spots.length) {
    return DateTime.now();
  }
  return DateTime.fromMillisecondsSinceEpoch(spots[index].x.toInt());
}

String _formatAllocationName(AssetSubType subType) {
  switch (subType) {
    case AssetSubType.stock:
      return '股票';
    case AssetSubType.etf:
      return '场内基金 (ETF)';
    case AssetSubType.mutualFund:
      return '场外基金';
    case AssetSubType.other:
      return '其他资产 (价值法)';
  }
}
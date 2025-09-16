import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart'; // 全局 Provider

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dashboardDataProvider);
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

    return Scaffold(
      appBar: AppBar(title: const Text('资产总览')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
        data: (data) {
          final double totalValue = (data['totalValue'] ?? 0.0) as double;
          final List<FlSpot> spots =
              (data['historySpots'] as List<FlSpot>? ?? const <FlSpot>[]);
          final Map<AssetSubType, double> allocation =
              (data['allocation'] as Map<AssetSubType, double>? ??
                  const <AssetSubType, double>{})
                  .map((k, v) => MapEntry(k, v));

          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(dashboardDataProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildTotalAssetCard(context, currencyFormat.format(totalValue)),
                const SizedBox(height: 24),

                if (spots.length >= 2) _buildHistoryChartCard(context, spots),

                const SizedBox(height: 24),

                if (allocation.isNotEmpty) _buildAllocationCard(context, allocation),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------ 总资产卡片 ------------------------

  Widget _buildTotalAssetCard(BuildContext context, String totalValueStr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '总资产 (CNY)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              totalValueStr,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------ 历史曲线 ------------------------

  Widget _buildHistoryChartCard(BuildContext context, List<FlSpot> spots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('总资产趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildHistoryChart(context, spots),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryChart(BuildContext context, List<FlSpot> spots) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');
    final colorScheme = Theme.of(context).colorScheme;

    // 绘图使用“按索引”的 X；标签/Tooltip 用原 spot.x（时间戳）
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) =>
                    Text(currencyFormat.format(value), style: const TextStyle(fontSize: 10)),
              ),
            ),
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

                  final FlSpot originalSpot = spots[index];
                  final date = DateFormat('yyyy-MM-dd')
                      .format(DateTime.fromMillisecondsSinceEpoch(originalSpot.x.toInt()));
                  final value =
                      NumberFormat.currency(locale: 'zh_CN', symbol: '¥').format(originalSpot.y);

                  return LineTooltipItem(
                    '$date\n$value',
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

  // ------------------------ 资产配置饼图 ------------------------

  Widget _buildAllocationCard(
    BuildContext context,
    Map<AssetSubType, double> allocation,
  ) {
    // 过滤掉非正值
    final filtered = allocation.entries.where((e) => (e.value) > 0).toList();
    if (filtered.isEmpty) {
      return const Card(child: ListTile(title: Text('暂无资产配置数据')));
    }

    // 总额
    final double total = filtered.fold(0.0, (sum, e) => sum + e.value);

    // === 关键修复：不再直接引用 AssetSubType.cash 等常量，改为按名称字符串匹配 ===
    String labelOf(AssetSubType t) {
      // Dart 2.17+ 可用 t.name；为兼容性，这里用 toString 拆分
      final raw = t.toString().split('.').last.toLowerCase();
      switch (raw) {
        case 'stock':
          return '股票';
        case 'bond':
          return '债券';
        case 'cash':
        case 'cashequivalent':
        case 'money':
        case 'currency':
          return '现金/现金等价';
        case 'fund':
          return '基金';
        case 'crypto':
        case 'cryptocurrency':
          return '加密资产';
        case 'realestate':
        case 'real_estate':
        case 're':
          return '不动产';
        case 'commodity':
          return '大宗商品';
        default:
          // 未知枚举名直接原样显示
          return raw;
      }
    }

    final percentFmt = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;

    // 简单配色（避免未指定颜色导致的可读性问题）
    final palette = Colors.primaries;

    final sections = <PieChartSectionData>[
      for (int i = 0; i < filtered.length; i++)
        PieChartSectionData(
          value: filtered[i].value,
          color: palette[i % palette.length],
          title: percentFmt.format(filtered[i].value / total),
          radius: 70,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];

    // Legend
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in filtered)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${labelOf(e.key)}  ${percentFmt.format(e.value / total)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置（CNY）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 140, child: legend),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

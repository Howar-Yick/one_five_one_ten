// 文件: lib/pages/dashboard_page.dart
// (这是最终修复了饼图布局溢出问题的完整代码)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; 
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// (保持 ConsumerStatefulWidget 不变，悬停状态依然需要它)
class DashboardPage extends ConsumerStatefulWidget {
 const DashboardPage({super.key});

 @override
 ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
 
 // (保持状态变量不变)
 int _touchedPieIndex = -1;

 @override
 Widget build(BuildContext context) {
  final dashboardDataAsync = ref.watch(dashboardDataProvider);

  return Scaffold(
   appBar: AppBar(
    title: const Text('概览'),
   ),
   body: dashboardDataAsync.when(
    data: (dashboardData) {
     final historySpots = (dashboardData['historySpots'] ?? []) as List<FlSpot>;
     final allocation = (dashboardData['allocation'] ?? {}) as Map<AssetSubType, double>;

     return RefreshIndicator(
      onRefresh: () async {
       ref.invalidate(dashboardDataProvider); 
      },
      child: ListView(
       padding: const EdgeInsets.all(16.0),
       children: [
        _buildHeaderCard(context, dashboardData), 
        
        if (historySpots.length >= 2)
         _buildChartCard(context, historySpots),
         
        if (allocation.isNotEmpty)
         _buildAllocationCard(context, allocation),
       ],
      ),
     );
    },
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

 // (Header Card 保持不变)
 Widget _buildHeaderCard(BuildContext context, Map<String, dynamic> performance) {
    // ... (此函数的所有代码保持不变，为简洁起见省略) ...
    // (我们从你提供的文件中复制了完全相同的内容)
  final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
  final percentFormat =
    NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

  final double totalValue = (performance['totalValue'] ?? 0.0) as double;
  final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
  final double profitRate = (performance['profitRate'] ?? 0.0) as double;
  final double annualizedReturn = (performance['annualizedReturn'] ?? 0.0) as double;
  final double netInvestment = (performance['netInvestment'] ?? 0.0) as double;

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
      Text(
       currencyFormat.format(totalValue),
       style: Theme.of(context)
         .textTheme
         .headlineLarge
         ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
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


 // (Chart Card 保持不变)
 Widget _buildChartCard(BuildContext context, List<FlSpot> spots) {
    // ... (此函数的所有代码保持不变，为简洁起见省略) ...
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

  // --- (*** 5. 这是大改的 _buildAllocationCard ***) ---
  // --- (*** 修复了布局溢出问题 ***) ---
 Widget _buildAllocationCard(
   BuildContext context, Map<AssetSubType, double> allocation) {
    
  final double totalValue =
    allocation.values.fold(0.0, (prev, element) => prev + element);
  
  final Map<AssetSubType, Color> colorMap = {
   AssetSubType.stock: Colors.blue.shade400,
   AssetSubType.etf: Colors.green.shade400,
   AssetSubType.mutualFund: Colors.orange.shade400,
   AssetSubType.other: Colors.purple.shade400,
  };

  // (动态生成切片列表的逻辑保持不变)
  final List<PieChartSectionData> sections = [];
  final allocationEntries = allocation.entries.toList(); 

  for (int i = 0; i < allocationEntries.length; i++) {
   final entry = allocationEntries[i];
   final subType = entry.key;
   final value = entry.value;

   final bool isTouched = (i == _touchedPieIndex); 
   final double radius = isTouched ? 90.0 : 80.0; 
   final double fontSize = isTouched ? 16.0 : 14.0; 
   final percentage = (value / totalValue) * 100;

   sections.add(
    PieChartSectionData(
     color: colorMap[subType] ?? Colors.grey,
     value: value,
     title: '${percentage.toStringAsFixed(1)}%',
     radius: radius, 
     titleStyle: TextStyle( 
       fontSize: fontSize, 
       fontWeight: FontWeight.bold, 
       color: Colors.white),
    ),
   );
  }

    // --- (*** 这是布局修复 ***) ---
    // 我们不再使用 Center(Row(...))，因为它在窄屏上会导致溢出。
    // 我们改为使用 垂直堆叠 布局。
  return Card(
   child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.start, // 保持标题在左侧
     children: [
      const Text('资产配置',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24), // 增大标题和图表间距

            // --- 控件 1: 饼图 ---
            SizedBox(
              height: 200, // 给予图表一个固定的高度
              width: double.infinity, // 让它撑满卡片宽度
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData( // (悬停逻辑保持不变)
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = -1; // 鼠标移出
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: sections, 
                  centerSpaceRadius: 60, // 半径改大一点，做成环形图
                  sectionsSpace: 2,
                ),
              ),
            ),

            const SizedBox(height: 24), // 图表和图例之间的间距

            // --- 控件 2: 图例 ---
            // (我们不再需要 Row/Center/SizedBox，只需直接构建图例列)
            Column(
              mainAxisSize: MainAxisSize.min, // 让图例列表自然包裹内容
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
                      Text( // (移除了 Expanded)
                        _formatAllocationName(entry.key),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ), // <-- 图例 Column 结束
     ],
    ),
   ),
  );
    // --- (*** 修复结束 ***) ---
 }

 // (Metric Row 辅助函数保持不变)
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
// --- (*** 类定义结束 ***) ---


// (文件末尾的辅助函数保持不变)
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
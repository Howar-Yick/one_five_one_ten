// 文件: lib/pages/dashboard_page.dart
// (*** 关键修复：添加了对 AssetSubType.wealthManagement 的处理 ***)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; 
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// --- (*** 1. 新增：饼图切换的枚举 ***) ---
enum AllocationChartType {
  assetClass, // 按资产大类
  subType,      // 按资产类型
}
// --- (*** 新增结束 ***) ---

// --- (*** 2. 新增：AssetClass 的中文名称和颜色 ***) ---
const Map<AssetClass, String> assetClassDisplayNames = {
  AssetClass.equity: '权益类',
  AssetClass.fixedIncome: '固定收益类',
  AssetClass.cashEquivalent: '现金及等价物',
  AssetClass.alternative: '另类投资',
  AssetClass.other: '其他',
};
const Map<AssetClass, Color> assetClassColorMap = {
  AssetClass.equity: Colors.blue,
  AssetClass.fixedIncome: Colors.green,
  AssetClass.cashEquivalent: Colors.orange,
  AssetClass.alternative: Colors.purple,
  AssetClass.other: Colors.grey,
};
// --- (*** 新增结束 ***) ---


// (保持 ConsumerStatefulWidget 不变，悬停状态依然需要它)
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  
  // (保持状态变量不变)
  int _touchedPieIndex = -1;
  // --- (*** 3. 新增：切换按钮的状态 ***) ---
  AllocationChartType _selectedChartType = AllocationChartType.assetClass; // 默认显示“按大类”
  // --- (*** 新增结束 ***) ---

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
          
          // --- (*** 4. 修改：获取两种 allocation 数据 ***) ---
          final allocationSubType = (dashboardData['allocationSubType'] ?? {}) as Map<AssetSubType, double>;
          final allocationClass = (dashboardData['allocationClass'] ?? {}) as Map<AssetClass, double>;
          // --- (*** 修改结束 ***) ---

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
                
                // --- (*** 5. 新增：切换按钮 ***) ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SegmentedButton<AllocationChartType>(
                    segments: const [
                      ButtonSegment(value: AllocationChartType.assetClass, label: Text('按资产大类'), icon: Icon(Icons.class_)),
                      ButtonSegment(value: AllocationChartType.subType, label: Text('按资产类型'), icon: Icon(Icons.category)),
                    ],
                    selected: {_selectedChartType},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedChartType = newSelection.first;
                        _touchedPieIndex = -1; // 切换时重置悬停
                      });
                    },
                  ),
                ),
                // --- (*** 新增结束 ***) ---
                  
                // --- (*** 6. 修改：条件化显示饼图 ***) ---
                if (allocationClass.isNotEmpty && _selectedChartType == AllocationChartType.assetClass)
                  _buildAssetClassAllocationCard(context, allocationClass) // <-- 调用新函数
                else if (allocationSubType.isNotEmpty && _selectedChartType == AllocationChartType.subType)
                  _buildAllocationCard(context, allocationSubType), // <-- 调用旧函数
                // --- (*** 修改结束 ***) ---
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('加载仪表盘失败: $err\n$stack'), // (添加 stack 帮助调试)
          ),
        ),
      ),
    );
  }

  // (Header Card 保持不变)
  Widget _buildHeaderCard(BuildContext context, Map<String, dynamic> performance) {
    // ... (此函数的所有代码保持不变，为简洁起见省略) ...
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

  // (*** 这是你原有的 SubType 饼图 ***)
  Widget _buildAllocationCard(
      BuildContext context, Map<AssetSubType, double> allocation) {
    
    final double totalValue =
        allocation.values.fold(0.0, (prev, element) => prev + element);
    
    // (*** 1. 关键修复：为 '理财' 添加颜色 ***)
    final Map<AssetSubType, Color> colorMap = {
      AssetSubType.stock: Colors.blue.shade400,
      AssetSubType.etf: Colors.green.shade400,
      AssetSubType.mutualFund: Colors.orange.shade400,
      AssetSubType.wealthManagement: Colors.teal.shade400, // (新增的颜色)
      AssetSubType.other: Colors.purple.shade400,
    };
    // (*** 修复结束 ***)

    final List<PieChartSectionData> sections = [];
    final allocationEntries = allocation.entries.toList(); 

    for (int i = 0; i < allocationEntries.length; i++) {
      final entry = allocationEntries[i];
      final subType = entry.key;
      final value = entry.value;

      final bool isTouched = (i == _touchedPieIndex); // 检查是否被悬停
      final double radius = isTouched ? 90.0 : 80.0; // 悬停时半径更大
      final double fontSize = isTouched ? 16.0 : 14.0; // 悬停时字体更大
      final percentage = (totalValue == 0) ? 0.0 : (value / totalValue) * 100; // (修复除零)

      final String title;
      if (isTouched) {
        final String name = _formatAllocationName(subType);
        title = '$name\n${percentage.toStringAsFixed(1)}%';
      } else {
        title = '${percentage.toStringAsFixed(1)}%';
      }

      sections.add(
        PieChartSectionData(
          color: colorMap[subType] ?? Colors.grey,
          value: value,
          title: title, 
          radius: radius, 
          titleStyle: TextStyle( 
              fontSize: fontSize, 
              fontWeight: FontWeight.bold, 
              color: Colors.white),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置 (按类型)', // (我给标题加了后缀)
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24), 

            SizedBox(
              height: 240, 
              width: double.infinity, 
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData( 
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
                  centerSpaceRadius: 60, 
                  sectionsSpace: 2,
                ),
              ),
            ),

            const SizedBox(height: 24), // 图表和图例之间的间距

            Wrap(
              alignment: WrapAlignment.center, 
              spacing: 16.0, 
              runSpacing: 8.0, 
              children: allocation.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: colorMap[entry.key] ?? Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text( 
                      _formatAllocationName(entry.key),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                );
              }).toList(),
            ), // <-- Wrap 结束
          ],
        ),
      ),
    );
  }

  // --- (*** 7. 新增：用于 AssetClass 饼图的函数 ***) ---
  Widget _buildAssetClassAllocationCard(
      BuildContext context, Map<AssetClass, double> allocation) {
    
    final double totalValue =
        allocation.values.fold(0.0, (prev, element) => prev + element);
    
    // (使用我们文件顶部定义的 AssetClass 颜色)
    final Map<AssetClass, Color> colorMap = assetClassColorMap;

    final List<PieChartSectionData> sections = [];
    final allocationEntries = allocation.entries.toList(); 

    for (int i = 0; i < allocationEntries.length; i++) {
      final entry = allocationEntries[i];
      final assetClass = entry.key; // (变量重命名)
      final value = entry.value;

      final bool isTouched = (i == _touchedPieIndex);
      final double radius = isTouched ? 90.0 : 80.0;
      final double fontSize = isTouched ? 16.0 : 14.0;
      final percentage = (totalValue == 0) ? 0.0 : (value / totalValue) * 100; // (修复除零)

      final String title;
      if (isTouched) {
        final String name = _formatAssetClassName(assetClass); // (调用新函数)
        title = '$name\n${percentage.toStringAsFixed(1)}%';
      } else {
        title = '${percentage.toStringAsFixed(1)}%';
      }

      sections.add(
        PieChartSectionData(
          color: colorMap[assetClass] ?? Colors.grey, // (使用新 colorMap)
          value: value,
          title: title, 
          radius: radius, 
          titleStyle: TextStyle( 
              fontSize: fontSize, 
              fontWeight: FontWeight.bold, 
              color: Colors.white),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置 (按大类)', // (新标题)
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24), 

            SizedBox(
              height: 240, 
              width: double.infinity, 
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData( 
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = -1; 
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: sections, 
                  centerSpaceRadius: 60, 
                  sectionsSpace: 2,
                ),
              ),
            ),

            const SizedBox(height: 24), 

            Wrap(
              alignment: WrapAlignment.center, 
              spacing: 16.0, 
              runSpacing: 8.0, 
              children: allocation.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: colorMap[entry.key] ?? Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text( 
                      _formatAssetClassName(entry.key), // (调用新函数)
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                );
              }).toList(),
            ), 
          ],
        ),
      ),
    );
  }
  // --- (*** 新增结束 ***) ---

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

// (这是你原有的 SubType 名称函数)
String _formatAllocationName(AssetSubType subType) {
  // (*** 2. 关键修复：修复 switch 语句 ***)
  switch (subType) {
    case AssetSubType.stock:
      return '股票';
    case AssetSubType.etf:
      return '场内基金 (ETF)';
    case AssetSubType.mutualFund:
      return '场外基金';
    case AssetSubType.wealthManagement: // (新增的 case)
      return '理财';
    case AssetSubType.other:
      return '其他资产 (价值法)';
    default: // (新增 default 以确保安全)
      return subType.name;
  }
  // (*** 修复结束 ***)
}

// --- (*** 8. 新增：用于 AssetClass 名称的函数 ***) ---
String _formatAssetClassName(AssetClass assetClass) {
  return assetClassDisplayNames[assetClass] ?? assetClass.name;
}
// --- (*** 新增结束 ***) ---
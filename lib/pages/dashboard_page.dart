// 文件: lib/pages/dashboard_page.dart
// (*** 已为你集成 ChatGPT 方案的入口 ***)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

// (*** 1. 导入新模块 ***)
import 'package:one_five_one_ten/allocation/feature_flags.dart';
// (*** 导入结束 ***)


/// --- (*** 1. 新增：饼图切换的枚举 ***) ---
enum AllocationChartType {
  assetClass, // 按资产大类
  subType, // 按资产类型
}
/// --- (*** 新增结束 ***) ---

/// --- (*** 2. AssetClass 的中文名称和颜色 ***) ---
const Map<AssetClass, String> assetClassDisplayNames = {
  AssetClass.equity: '权益类',
  AssetClass.fixedIncome: '固定收益类',
  AssetClass.cashEquivalent: '现金及等价物',
  AssetClass.alternative: '另类投资',
  AssetClass.other: '其他',
};

const Map<AssetClass, Color> assetClassColorMap = {
  AssetClass.equity: Color(0xFF4DA3FF),
  AssetClass.fixedIncome: Color(0xFF3CB371),
  AssetClass.cashEquivalent: Color(0xFFB39DDB),
  AssetClass.alternative: Color(0xFFFFC107),
  AssetClass.other: Color(0xFF90A4AE),
};
/// --- (*** 新增结束 ***) ---

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _touchedPieIndex = -1;

  /// --- (*** 3. 新增：切换按钮的状态 ***) ---
  AllocationChartType _selectedChartType = AllocationChartType.assetClass; // 默认显示“按大类”
  /// --- (*** 新增结束 ***) ---

  @override
  Widget build(BuildContext context) {
    final dashboardDataAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        // (*** 2. 在这里添加新按钮 ***)
        actions: [
          if (kFeatureAllocation)
            IconButton(
              tooltip: '资产配置',
              icon: const Icon(Icons.pie_chart_outline),
              onPressed: () {
                ref.read(mainNavIndexProvider.notifier).state = kNavTabConfig;
              },
            ),
        ],
        // (*** 添加结束 ***)
      ),
      body: dashboardDataAsync.when(
        data: (dashboardData) {
          final historySpots =
              (dashboardData['historySpots'] ?? []) as List<FlSpot>;

          /// --- (*** 4. 修改：获取两种 allocation 数据 ***) ---
          final allocationSubType =
              (dashboardData['allocationSubType'] ?? {}) as Map<AssetSubType, double>;
          final allocationClass =
              (dashboardData['allocationClass'] ?? {}) as Map<AssetClass, double>;
          /// --- (*** 修改结束 ***) ---

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardDataProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildHeaderCard(context, dashboardData),

                if (historySpots.length >= 2) _buildChartCard(context, historySpots),

                /// --- (*** 5. 新增：切换按钮 ***) ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SegmentedButton<AllocationChartType>(
                    segments: const [
                      ButtonSegment(
                        value: AllocationChartType.assetClass,
                        label: Text('按资产大类'),
                        icon: Icon(Icons.class_),
                      ),
                      ButtonSegment(
                        value: AllocationChartType.subType,
                        label: Text('按资产类型'),
                        icon: Icon(Icons.category),
                      ),
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
                /// --- (*** 新增结束 ***) ---

                /// --- (*** 6. 修改：条件化显示饼图 ***) ---
                if (_selectedChartType == AllocationChartType.assetClass)
                  _buildAssetClassAllocationCard(context, allocationClass)
                else
                  _buildAllocationCard(context, allocationSubType),
                /// --- (*** 修改结束 ***) ---
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('加载仪表盘失败: $err\n$stack'),
          ),
        ),
      ),
    );
  }

  // ===================== 顶部总览卡片 =====================
  Widget _buildHeaderCard(BuildContext context, Map<String, dynamic> performance) {
    final currencyFormat = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    final double totalValue = (performance['totalValue'] ?? 0.0) as double;
    final double totalProfit = (performance['totalProfit'] ?? 0.0) as double;
    final double profitRate = (performance['profitRate'] ?? 0.0) as double;
    final double annualizedReturn =
        (performance['annualizedReturn'] ?? 0.0) as double;
    final double netInvestment = (performance['netInvestment'] ?? 0.0) as double;
    final double fxProfit = (performance['fxProfit'] ?? 0.0) as double;

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
              '其中汇率影响:',
              currencyFormat.format(fxProfit),
              color: fxProfit >= 0
                  ? Colors.red.shade400
                  : Colors.green.shade400,
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

  // ===================== 折线图 =====================
  Widget _buildChartCard(BuildContext context, List<FlSpot> spots) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat =
        NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥');

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
                      // ★★★ 修复点: 根据数据点数量动态显示圆点 ★★★
                      dotData: FlDotData(show: spots.length < 40),
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
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                              fontWeight: FontWeight.bold,
                            ),
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

  // ===================== 饼图（按子类型） =====================
  Widget _buildAllocationCard(
    BuildContext context,
    Map<AssetSubType, double> allocation,
  ) {
    if (allocation.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('资产配置 (按类型)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('暂无可展示的数据'),
            ],
          ),
        ),
      );
    }

    final double totalValue =
        allocation.values.fold(0.0, (prev, e) => prev + (e.isFinite ? e : 0.0));

    // 1) 完整颜色映射（含理财）——与你之前模型一致（etf/mutualFund）
    final Map<AssetSubType, Color> fixedColors = {
      AssetSubType.stock: const Color(0xFF4DA3FF),
      AssetSubType.etf: const Color(0xFF3CB371),
      AssetSubType.mutualFund: const Color(0xFFFFA726),
      AssetSubType.wealthManagement: const Color(0xFF7E57C2), // ★ 关键：理财
      AssetSubType.other: const Color(0xFF90A4AE),
      // 若你的模型还有 crypto/cash/domesticEtf/overseasFund，请在下面名称函数中兜底
    };

    // 2) 兜底配色：任何未知枚举都有稳定色
    Color fallbackColor(AssetSubType t) {
      final h = t.hashCode & 0xFFFFFF;
      // 简单 HSL → RGB（固定亮度/饱和度）
      final hue = (h % 360).toDouble();
      final hsl = HSLColor.fromAHSL(1, hue, 0.55, 0.55);
      return hsl.toColor();
    }

    final entries = allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < entries.length; i++) {
      final subType = entries[i].key;
      final value = entries[i].value.isFinite ? entries[i].value : 0.0;

      final bool isTouched = (i == _touchedPieIndex);
      final double radius = isTouched ? 90.0 : 80.0;
      final double fontSize = isTouched ? 16.0 : 14.0;
      final percent = totalValue == 0 ? 0.0 : (value / totalValue) * 100.0;

      final name = _formatAllocationName(subType);
      final title = isTouched ? '$name\n${percent.toStringAsFixed(1)}%' : '${percent.toStringAsFixed(1)}%';

      sections.add(
        PieChartSectionData(
          color: fixedColors[subType] ?? fallbackColor(subType),
          value: value,
          title: title,
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置 (按类型)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 240,
              width: double.infinity,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
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

            // 图例（含金额，便于核对）
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16.0,
              runSpacing: 8.0,
              children: entries.map((e) {
                final color = fixedColors[e.key] ?? fallbackColor(e.key);
                final name = _formatAllocationName(e.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      '$name  ${formatCurrency(e.value, "CNY")}',
                      style: const TextStyle(fontSize: 12),
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

  // ===================== 饼图（按资产大类） =====================
  Widget _buildAssetClassAllocationCard(
    BuildContext context,
    Map<AssetClass, double> allocation,
  ) {
    if (allocation.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('资产配置 (按大类)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('暂无可展示的数据'),
            ],
          ),
        ),
      );
    }

    final double totalValue =
        allocation.values.fold(0.0, (prev, e) => prev + (e.isFinite ? e : 0.0));

    Color fallbackColor(AssetClass c) {
      final h = c.hashCode & 0xFFFFFF;
      final hue = (h % 360).toDouble();
      final hsl = HSLColor.fromAHSL(1, hue, 0.55, 0.55);
      return hsl.toColor();
    }

    final entries = allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < entries.length; i++) {
      final klass = entries[i].key;
      final value = entries[i].value.isFinite ? entries[i].value : 0.0;

      final bool isTouched = (i == _touchedPieIndex);
      final double radius = isTouched ? 90.0 : 80.0;
      final double fontSize = isTouched ? 16.0 : 14.0;
      final percent = totalValue == 0 ? 0.0 : (value / totalValue) * 100.0;

      final name = _formatAssetClassName(klass);
      final title = isTouched ? '$name\n${percent.toStringAsFixed(1)}%' : '${percent.toStringAsFixed(1)}%';

      sections.add(
        PieChartSectionData(
          color: assetClassColorMap[klass] ?? fallbackColor(klass),
          value: value,
          title: title,
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置 (按大类)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 240,
              width: double.infinity,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
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
              children: entries.map((e) {
                final color = assetClassColorMap[e.key] ?? fallbackColor(e.key);
                final name = _formatAssetClassName(e.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      '$name  ${formatCurrency(e.value, "CNY")}',
                      style: const TextStyle(fontSize: 12),
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

  // ===================== 公共小部件 =====================
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
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ===================== 文件末尾的辅助函数 =====================
DateTime _getSpotDate(List<FlSpot> spots, int index) {
  if (index < 0 || index >= spots.length) {
    return DateTime.now();
  }
  return DateTime.fromMillisecondsSinceEpoch(spots[index].x.toInt());
}

/// （保持你原有的 SubType 名称函数，并增强兼容性）
String _formatAllocationName(AssetSubType subType) {
  switch (subType) {
    case AssetSubType.stock:
      return '股票';
    case AssetSubType.etf: // 你的模型之一
      return '场内基金 (ETF)';
    case AssetSubType.mutualFund: // 你的模型之一
      return '场外基金';
    case AssetSubType.wealthManagement:
      return '理财';
    case AssetSubType.other:
      return '其他资产 (价值法)';

    // 如果你的 enum 还有以下成员，统一中文（不会影响已有分支）
    // ignore: dead_code
    default:
      final name = subType.name;
      if (name == 'domesticEtf') return '场内基金 (ETF)';
      if (name == 'overseasFund') return '场外基金';
      if (name == 'crypto') return '加密资产';
      if (name == 'cash') return '现金/存款';
      if (name == 'wealthManagement') return '理财';
      return name;
  }
}

String _formatAssetClassName(AssetClass assetClass) {
  return assetClassDisplayNames[assetClass] ?? assetClass.name;
}
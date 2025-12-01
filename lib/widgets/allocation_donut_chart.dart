import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:one_five_one_ten/models/allocation_overview.dart';

class AllocationDonutChart extends StatelessWidget {
  final List<AllocationChartSlice> targetSlices;
  final List<AllocationChartSlice> actualSlices;

  const AllocationDonutChart({
    super.key,
    required this.targetSlices,
    required this.actualSlices,
  });

  @override
  Widget build(BuildContext context) {
    const double minLabelPercent = 0.03;
    const double centerSpace = 60.0;

    List<PieChartSectionData> toSections(
      List<AllocationChartSlice> slices, {
      required bool translucent,
      required double radius,
    }) {
      return slices
          .map(
            (slice) => PieChartSectionData(
              color: translucent ? slice.color.withOpacity(0.45) : slice.color,
              value: slice.percent,
              radius: radius,
              title: slice.percent >= minLabelPercent
                  ? '${(slice.percent * 100).toStringAsFixed(1)}%'
                  : '',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )
          .toList();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (targetSlices.isNotEmpty)
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: centerSpace,
              sections: toSections(
                targetSlices,
                translucent: true,
                radius: 110,
              ),
            ),
          ),
        if (actualSlices.isNotEmpty)
          PieChart(
            PieChartData(
              sectionsSpace: 1,
              centerSpaceRadius: centerSpace,
              sections: toSections(
                actualSlices,
                translucent: false,
                radius: 90,
              ),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '资产配置',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              actualSlices.isEmpty
                  ? '外圈：目标 / 内圈：实际（暂无数据）'
                  : '外圈：目标 / 内圈：实际',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }
}

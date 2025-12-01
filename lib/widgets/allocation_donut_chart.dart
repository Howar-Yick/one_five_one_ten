import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:one_five_one_ten/models/allocation_overview.dart';

class AllocationDonutChart extends StatefulWidget {
  final List<AllocationChartSlice> targetSlices;
  final List<AllocationChartSlice> actualSlices;

  const AllocationDonutChart({
    super.key,
    required this.targetSlices,
    required this.actualSlices,
  });

  @override
  State<AllocationDonutChart> createState() => _AllocationDonutChartState();
}

class _AllocationDonutChartState extends State<AllocationDonutChart> {
  static const double _minLabelPercent = 0.03;
  static const double _centerSpace = 60.0;
  static const double _outerRadius = 110.0;
  static const double _innerRadius = 90.0;
  static const double _outerSize = (_outerRadius * 2) + 14;
  // 调整实际绘制区域，避免内圈的组件遮挡外圈的鼠标事件。
  static const double _innerSize = _innerRadius * 2;

  int? _hoveredOuterIndex;
  int? _hoveredInnerIndex;

  @override
  Widget build(BuildContext context) {
    List<PieChartSectionData> toSections(
      List<AllocationChartSlice> slices, {
      required bool translucent,
      required double radius,
      required int? hoveredIndex,
    }) {
      return slices.asMap().entries.map((entry) {
        final index = entry.key;
        final slice = entry.value;
        final isHovered = hoveredIndex == index;
        return PieChartSectionData(
          color: translucent ? slice.color.withOpacity(0.45) : slice.color,
          value: slice.percent,
          radius: isHovered ? radius + 6 : radius,
          showTitle: true,
          title: isHovered || slice.percent >= _minLabelPercent
              ? '${(slice.percent * 100).toStringAsFixed(1)}%'
              : '',
          titleStyle: TextStyle(
            color: Colors.white,
            fontWeight: isHovered ? FontWeight.w800 : FontWeight.bold,
            fontSize: isHovered ? 13 : 12,
          ),
          borderSide: isHovered
              ? BorderSide(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.4,
                )
              : BorderSide.none,
        );
      }).toList();
    }

    AllocationChartSlice? _sliceByLabel(
      List<AllocationChartSlice> slices,
      String label,
    ) {
      for (final slice in slices) {
        if (slice.label == label) return slice;
      }
      return null;
    }

    int? _indexByLabel(List<AllocationChartSlice> slices, String label) {
      for (int i = 0; i < slices.length; i++) {
        if (slices[i].label == label) return i;
      }
      return null;
    }

    String _buildCenterTitle() {
      String? label;
      AllocationChartSlice? target;
      AllocationChartSlice? actual;

      if (_hoveredOuterIndex != null &&
          _hoveredOuterIndex! < widget.targetSlices.length) {
        target = widget.targetSlices[_hoveredOuterIndex!];
        label = target.label;
        actual = _sliceByLabel(widget.actualSlices, label);
      } else if (_hoveredInnerIndex != null &&
          _hoveredInnerIndex! < widget.actualSlices.length) {
        actual = widget.actualSlices[_hoveredInnerIndex!];
        label = actual.label;
        target = _sliceByLabel(widget.targetSlices, label);
      }

      if (label != null) {
        final targetText = target != null
            ? '目标 ${(target.percent * 100).toStringAsFixed(1)}%'
            : '目标 --';
        final actualText = actual != null
            ? '实际 ${(actual.percent * 100).toStringAsFixed(1)}%'
            : '实际 --';
        return '$label\n$targetText / $actualText';
      }

      return widget.actualSlices.isEmpty
          ? '资产配置\n外圈：目标 / 内圈：实际（暂无数据）'
          : '资产配置\n外圈：目标 / 内圈：实际';
    }

    Widget _buildLegendPill({
      required Color color,
      required String text,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    Widget _buildChartLayer({
      required bool translucent,
      required double radius,
      required int? hoveredIndex,
      required void Function(int? index) onHoverChanged,
      required List<AllocationChartSlice> slices,
      required double size,
    }) {
      if (slices.isEmpty) return const SizedBox.shrink();
      return SizedBox.square(
        dimension: size,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              enabled: true,
              touchCallback: (event, response) {
                final touchedIndex =
                    response?.touchedSection?.touchedSectionIndex;
                if (!event.isInterestedForInteractions ||
                    touchedIndex == null ||
                    touchedIndex < 0 ||
                    touchedIndex >= slices.length) {
                  onHoverChanged(null);
                  return;
                }
                onHoverChanged(touchedIndex);
              },
            ),
            sectionsSpace: translucent ? 2 : 1,
            centerSpaceRadius: _centerSpace,
            sections: toSections(
              slices,
              translucent: translucent,
              radius: radius,
              hoveredIndex: hoveredIndex,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: _outerSize,
            width: _outerSize,
            child: MouseRegion(
              onExit: (_) {
                setState(() {
                  _hoveredInnerIndex = null;
                  _hoveredOuterIndex = null;
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildChartLayer(
                    translucent: true,
                    radius: _outerRadius,
                    hoveredIndex: _hoveredOuterIndex,
                    onHoverChanged: (index) {
                      setState(() {
                        _hoveredOuterIndex = index;
                        if (index != null &&
                            index < widget.targetSlices.length) {
                          final label = widget.targetSlices[index].label;
                          _hoveredInnerIndex =
                              _indexByLabel(widget.actualSlices, label);
                        } else {
                          _hoveredInnerIndex = null;
                        }
                      });
                    },
                    slices: widget.targetSlices,
                    size: _outerSize,
                  ),
                  _buildChartLayer(
                    translucent: false,
                    radius: _innerRadius,
                    hoveredIndex: _hoveredInnerIndex,
                    onHoverChanged: (index) {
                      setState(() {
                        _hoveredInnerIndex = index;
                        if (index != null &&
                            index < widget.actualSlices.length) {
                          final label = widget.actualSlices[index].label;
                          _hoveredOuterIndex =
                              _indexByLabel(widget.targetSlices, label);
                        }
                      });
                    },
                    slices: widget.actualSlices,
                    size: _innerSize,
                  ),
                  Text(
                    _buildCenterTitle(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildLegendPill(
              color: Colors.grey.withOpacity(0.35),
              text: '外圈：目标占比（方案）',
            ),
            _buildLegendPill(
              color: Colors.grey.shade600,
              text: '内圈：实际占比（当前持仓）',
            ),
          ],
        ),
      ],
    );
  }
}

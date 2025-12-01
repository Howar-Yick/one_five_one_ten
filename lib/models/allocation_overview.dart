import 'package:flutter/material.dart';

class AllocationChartSlice {
  final String label;
  final double percent;
  final Color color;

  const AllocationChartSlice({
    required this.label,
    required this.percent,
    required this.color,
  });
}

class AllocationOverview {
  final List<AllocationChartSlice> targetSlices;
  final List<AllocationChartSlice> actualSlices;

  const AllocationOverview({
    required this.targetSlices,
    required this.actualSlices,
  });
}

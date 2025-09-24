// 文件: lib/allocation/allocation_page.dart
// (*** 功能增强：在配置明细中显示每个类别的总金额 ***)

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/pages/add_edit_asset_page.dart';
import 'feature_flags.dart';
import 'allocation_service.dart';
import 'mapping.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';
import 'override_service.dart';

const Map<AllocationBucket, double> targetAllocations = {
  AllocationBucket.us: 0.55,
  AllocationBucket.cn: 0.10,
  AllocationBucket.hk: 0.05,
  AllocationBucket.gold: 0.10,
  AllocationBucket.oil: 0.03,
  AllocationBucket.bondCash: 0.17,
};

class AllocationPage extends StatefulWidget {
  const AllocationPage({super.key});

  @override
  State<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends State<AllocationPage> {
  final _svc = AllocationService();
  final _overrideService = OverrideService();
  int _touchedPieIndex = -1;

  AllocationSnapshot? _snapshot;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final source = AllocationRegistry.source;
    if (source == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '未连接数据源：请在 main.dart 中注册数据源。';
        });
      }
      return;
    }

    try {
      final items = await source();
      final snapshot = await _svc.buildSnapshot(items);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = '$e\n$stack';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kFeatureAllocation) {
      return const Scaffold(
        body: Center(child: Text('资产配置功能未开启（kFeatureAllocation=false）')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('投资组合配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData, 
            tooltip: '刷新',
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('加载失败：\n$_error', textAlign: TextAlign.center),
        ),
      );
    }

    if (_snapshot == null || _snapshot!.weights.isEmpty) {
      return const Center(child: Text('暂无资产数据'));
    }

    final shot = _snapshot!;
    final entries = shot.weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final labels = entries.map((e) => e.key).toList();
    final values = entries.map((e) => e.value).toList();

    List<PieChartSectionData> sections() {
      // (sections() 函数保持不变)
      return List.generate(labels.length, (i) {
        final pct = values[i] * 100;
        final isTouched = (i == _touchedPieIndex);
        final radius = isTouched ? 85.0 : 75.0;
        final fontSize = isTouched ? 14.0 : 12.0;
        
        return PieChartSectionData(
          value: values[i],
          title: pct >= 3 ? '${bucketLabel(labels[i])}\n${pct.toStringAsFixed(1)}%' : '',
          radius: radius,
          titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
        );
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text(
            '总资产: ${NumberFormat.currency(locale: 'zh_CN', symbol: '¥').format(shot.total)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 260, 
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
              sections: sections(),
              centerSpaceRadius: 60,
              sectionsSpace: 2,
            )
          )
        ),
        const SizedBox(height: 24),
        const Text('配置明细', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        // (*** 关键修改：更新 ExpansionTile 以显示类别总金额 ***)
        ...labels.map((bucket) {
          final currentWeight = values[labels.indexOf(bucket)];
          final currentPct = currentWeight * 100;
          final targetWeight = targetAllocations[bucket] ?? 0.0;
          final targetPct = targetWeight * 100;
          final diff = currentPct - targetPct;
          
          final assetsInBucket = shot.groupedItems[bucket] ?? [];
          // (*** 1. 获取类别总金额 ***)
          final bucketValue = shot.values[bucket] ?? 0.0;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ExpansionTile(
              // (*** 2. 将金额添加到标题中 ***)
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(bucketLabel(bucket)),
                  Text(
                    formatCurrency(bucketValue, "CNY"),
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              trailing: RichText(
                textAlign: TextAlign.end,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${currentPct.toStringAsFixed(1)}%\n',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: diff.isNegative ? ' (${diff.toStringAsFixed(1)}%)' : ' (+${diff.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: diff.abs() < 2.0 
                          ? Colors.grey 
                          : (diff.isNegative ? Colors.green.shade400 : Colors.red.shade400),
                      ),
                    ),
                  ],
                ),
              ),
              subtitle: Text('目标: ${targetPct.toStringAsFixed(0)}%'),
              children: assetsInBucket.map((asset) {
                return ListTile(
                  dense: true,
                  title: Text(asset.name),
                  subtitle: Text('代码: ${asset.code.isEmpty ? "--" : asset.code}'),
                  trailing: DropdownButton<AllocationBucket>(
                    value: bucket, 
                    items: AllocationBucket.values.map((b) {
                      return DropdownMenuItem(
                        value: b,
                        child: Text(bucketLabel(b)),
                      );
                    }).toList(),
                    onChanged: (newBucket) async {
                      if (newBucket != null && newBucket != bucket) {
                        await _overrideService.saveOverride(asset.id, newBucket);
                        await _fetchData();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          );
        }),
        // (*** 修改结束 ***)
      ],
    );
  }
}
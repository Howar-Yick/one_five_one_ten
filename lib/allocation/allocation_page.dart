// 文件: lib/allocation/allocation_page.dart
// (*** 关键修复：重构数据加载逻辑，移除 FutureBuilder，解决悬停闪烁问题 ***)

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'feature_flags.dart';
import 'allocation_service.dart';
import 'mapping.dart';

class AllocationPage extends StatefulWidget {
  const AllocationPage({super.key});

  @override
  State<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends State<AllocationPage> {
  final _svc = AllocationService();
  int _touchedPieIndex = -1;

  // (*** 1. 新增状态变量来管理数据 ***)
  AllocationSnapshot? _snapshot;
  bool _isLoading = true;
  Object? _error;
  // (*** 新增结束 ***)


  @override
  void initState() {
    super.initState();
    // (*** 2. 在页面初始化时获取一次数据 ***)
    _fetchData();
  }

  Future<void> _fetchData() async {
    final source = AllocationRegistry.source;
    if (source == null) {
      setState(() {
        _isLoading = false;
        _error = '未连接数据源：请在 main.dart 中注册数据源。';
      });
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }
  // (*** 修复结束 ***)

  @override
  Widget build(BuildContext context) {
    if (!kFeatureAllocation) {
      return const Scaffold(
        body: Center(child: Text('资产配置功能未开启（kFeatureAllocation=false）')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('标的配置（只读）')),
      // (*** 3. 移除 FutureBuilder，改用 if/else 判断状态 ***)
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
                  // (*** 4. 现在这个 setState 只会更新悬停状态，不会重新加载数据 ***)
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
        ...labels.map((b) {
          final v = values[labels.indexOf(b)];
          return Card(
            child: ListTile(
              dense: true,
              title: Text(bucketLabel(b)),
              trailing: Text('${(v * 100).toStringAsFixed(2)}%'),
            ),
          );
        }),
      ],
    );
  }
  // (*** 修复结束 ***)
}
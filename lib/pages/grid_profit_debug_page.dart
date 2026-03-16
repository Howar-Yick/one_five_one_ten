import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_result.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_step.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

class GridProfitDebugPage extends ConsumerWidget {
  final int assetId;

  const GridProfitDebugPage({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugAsync = ref.watch(gridProfitDebugProvider(assetId));
    final assetAsync = ref.watch(shareAssetDetailProvider(assetId));

    return Scaffold(
      appBar: AppBar(title: const Text('网格利润调试页')),
      body: debugAsync.when(
        data: (data) {
          final snapshots = (data['snapshots'] as List<PositionSnapshot>?) ??
              const <PositionSnapshot>[];
          final result = data['result'] as GridProfitReconstructionResult;
          final eventCounts =
              (data['eventCounts'] as Map<String, int>?) ?? const <String, int>{};
          final confidence = (data['confidence'] as String?) ?? '低';

          final currencyCode = assetAsync.asData?.value?.currency ?? 'CNY';

          if (snapshots.length < 2) {
            return const Center(
              child: Text('快照不足，无法重构网格利润'),
            );
          }

          final List<GridProfitReconstructionStep> displaySteps =
              result.steps.reversed.toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSummaryCard(context, result, snapshots.length, currencyCode),
              const SizedBox(height: 10),
              _buildEventStatsCard(context, eventCounts, confidence),
              const SizedBox(height: 10),
              _buildEventHintCard(context),
              const SizedBox(height: 10),
              ...displaySteps.map(
                (step) => _buildStepCard(context, step, currencyCode),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    GridProfitReconstructionResult result,
    int snapshotsCount,
    String currencyCode,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '摘要',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _row(
              '累计网格利润',
              _formatMoney(result.cumulativeGridProfit, currencyCode),
              _pnlColor(context, result.cumulativeGridProfit),
            ),
            _row(
              '每份额降本',
              _formatCost(result.gridCostReductionPerShare),
              _pnlColor(context, result.gridCostReductionPerShare),
            ),
            _row('快照数量', snapshotsCount.toString(), null),
            _row('步骤数量', result.steps.length.toString(), null),
          ],
        ),
      ),
    );
  }

  Widget _buildEventStatsCard(
    BuildContext context,
    Map<String, int> counts,
    String confidence,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '事件统计',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _row(_eventTypeLabel('init'), (counts['init'] ?? 0).toString(), null),
            _row(
              _eventTypeLabel('flat_trade'),
              (counts['flat_trade'] ?? 0).toString(),
              null,
            ),
            _row(_eventTypeLabel('buy'), (counts['buy'] ?? 0).toString(), null),
            _row(_eventTypeLabel('sell'), (counts['sell'] ?? 0).toString(), null),
            _row(
              _eventTypeLabel('sell_with_fallback'),
              (counts['sell_with_fallback'] ?? 0).toString(),
              Colors.orange.shade700,
            ),
            _row(_eventTypeLabel('none'), (counts['none'] ?? 0).toString(), null),
            const Divider(height: 16),
            _row(
              '可信度提示',
              confidence,
              confidence == '高'
                  ? Colors.green.shade700
                  : (confidence == '中'
                      ? Colors.orange.shade700
                      : Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventHintCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '事件说明',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            _hintLine('初始化基准：第一条快照，仅作为起点'),
            _hintLine('同份额套利：份额没变，但净投入本金下降，识别为网格利润'),
            _hintLine('净买入建仓：份额增加，记录为后续卖出配对批次'),
            _hintLine('净卖出兑现：份额减少，按 LIFO 配对计算网格利润'),
            _hintLine('卖出兑现（兜底）：历史批次不足时使用兜底成本'),
            _hintLine('无变化：本次快照未识别出有效事件'),
          ],
        ),
      ),
    );
  }

  Widget _hintLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text),
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    GridProfitReconstructionStep step,
    String currencyCode,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('yyyy-MM-dd').format(step.date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _eventColor(step.eventType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _eventTypeLabel(step.eventType),
                    style: TextStyle(
                      color: _eventColor(step.eventType),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('当前份额', _formatShares(step.shares), null),
            _row('单位成本', _formatCost(step.averageCost), null),
            _row(
              '净投入本金',
              _formatMoney(step.netCapital, currencyCode),
              _pnlColor(context, step.netCapital),
            ),
            _row(
              '份额变化',
              _formatShares(step.deltaShares),
              _pnlColor(context, step.deltaShares),
            ),
            _row(
              '本金变化',
              _formatMoney(step.deltaCapital, currencyCode),
              _pnlColor(context, step.deltaCapital),
            ),
            _row(
              '当步网格利润',
              _formatMoney(step.gridProfitDelta, currencyCode),
              _pnlColor(context, step.gridProfitDelta),
            ),
            _row(
              '累计网格利润',
              _formatMoney(step.cumulativeGridProfit, currencyCode),
              _pnlColor(context, step.cumulativeGridProfit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _eventTypeLabel(String eventType) {
    switch (eventType) {
      case 'init':
        return '初始化基准';
      case 'flat_trade':
        return '同份额套利';
      case 'buy':
        return '净买入建仓';
      case 'sell':
        return '净卖出兑现';
      case 'sell_with_fallback':
        return '卖出兑现（兜底）';
      case 'none':
        return '无变化';
      default:
        return eventType;
    }
  }

  String _formatMoney(double value, String currencyCode) {
    return formatCurrency(value, currencyCode);
  }

  String _formatShares(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatCost(double value) {
    return value.toStringAsFixed(3);
  }

  Color _pnlColor(BuildContext context, double value) {
    if (value > 0) return Colors.red.shade400;
    if (value < 0) return Colors.green.shade400;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Color _eventColor(String eventType) {
    switch (eventType) {
      case 'buy':
        return Colors.blue.shade700;
      case 'sell':
        return Colors.purple.shade700;
      case 'sell_with_fallback':
        return Colors.orange.shade700;
      case 'flat_trade':
        return Colors.teal.shade700;
      case 'init':
        return Colors.grey.shade700;
      default:
        return Colors.brown.shade700;
    }
  }
}

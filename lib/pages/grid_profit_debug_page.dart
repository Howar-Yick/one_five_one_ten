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

          final currencyCode =
              assetAsync.asData?.value?.currency ?? 'CNY';

          if (snapshots.length < 2) {
            return const Center(
              child: Text('快照不足，无法重构网格利润'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSummaryCard(context, result, snapshots.length, currencyCode),
              const SizedBox(height: 10),
              _buildEventStatsCard(context, eventCounts, confidence),
              const SizedBox(height: 10),
              ...result.steps.map(
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
            _row('累计网格利润', _formatMoney(result.cumulativeGridProfit, currencyCode),
                _pnlColor(context, result.cumulativeGridProfit)),
            _row('每份额降本', _formatCost(result.gridCostReductionPerShare),
                _pnlColor(context, result.gridCostReductionPerShare)),
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
            _row('init', (counts['init'] ?? 0).toString(), null),
            _row('flat_trade', (counts['flat_trade'] ?? 0).toString(), null),
            _row('buy', (counts['buy'] ?? 0).toString(), null),
            _row('sell', (counts['sell'] ?? 0).toString(), null),
            _row('sell_with_fallback',
                (counts['sell_with_fallback'] ?? 0).toString(),
                Colors.orange.shade700),
            _row('none', (counts['none'] ?? 0).toString(), null),
            const Divider(height: 16),
            _row(
              '可信度提示',
              confidence,
              confidence == '高'
                  ? Colors.green.shade700
                  : (confidence == '中' ? Colors.orange.shade700 : Colors.red.shade700),
            ),
          ],
        ),
      ),
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
                    step.eventType,
                    style: TextStyle(
                      color: _eventColor(step.eventType),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('shares', _formatShares(step.shares), null),
            _row('averageCost', _formatCost(step.averageCost), null),
            _row('netCapital', _formatMoney(step.netCapital, currencyCode),
                _pnlColor(context, step.netCapital)),
            _row('deltaShares', _formatShares(step.deltaShares),
                _pnlColor(context, step.deltaShares)),
            _row('deltaCapital', _formatMoney(step.deltaCapital, currencyCode),
                _pnlColor(context, step.deltaCapital)),
            _row('gridProfitDelta',
                _formatMoney(step.gridProfitDelta, currencyCode),
                _pnlColor(context, step.gridProfitDelta)),
            _row('cumulativeGridProfit',
                _formatMoney(step.cumulativeGridProfit, currencyCode),
                _pnlColor(context, step.cumulativeGridProfit)),
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

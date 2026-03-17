import 'package:one_five_one_ten/models/grid_profit_reconstruction_result.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_step.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';

class GridProfitReconstructionService {
  static const double _eps = 1e-6;

  GridProfitReconstructionResult reconstructFromSnapshots(
    List<PositionSnapshot> snapshots,
  ) {
    if (snapshots.length < 2) {
      return const GridProfitReconstructionResult(
        cumulativeGridProfit: 0.0,
        gridCostReductionPerShare: 0.0,
        steps: [],
      );
    }

    final sorted = snapshots.toList()..sort((a, b) => a.date.compareTo(b.date));

    final List<_Lot> stack = <_Lot>[];
    final List<GridProfitReconstructionStep> steps =
        <GridProfitReconstructionStep>[];

    double cumulativeGridProfit = 0.0;

    final first = sorted.first;
    final firstShares = _sanitize(first.totalShares);
    final firstAverageCost = _sanitize(first.averageCost);
    final firstNetCapital = _resolveNetCapital(first);

    steps.add(
      GridProfitReconstructionStep(
        date: first.date,
        shares: firstShares,
        averageCost: firstAverageCost,
        netCapital: firstNetCapital,
        deltaShares: 0.0,
        deltaCapital: 0.0,
        gridProfitDelta: 0.0,
        cumulativeGridProfit: 0.0,
        eventType: 'init',
      ),
    );

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final now = sorted[i];

      final prevShares = _sanitize(prev.totalShares);
      final prevAvgCost = _sanitize(prev.averageCost);
      final prevNetCapital = _resolveNetCapital(prev);

      final nowShares = _sanitize(now.totalShares);
      final nowAvgCost = _sanitize(now.averageCost);
      final nowNetCapital = _resolveNetCapital(now);

      final deltaSharesRaw = nowShares - prevShares;
      final deltaCapitalRaw = nowNetCapital - prevNetCapital;

      final deltaShares = _nearZero(deltaSharesRaw) ? 0.0 : deltaSharesRaw;
      final deltaCapital = _nearZero(deltaCapitalRaw) ? 0.0 : deltaCapitalRaw;

      double gridProfitDelta = 0.0;
      String eventType = 'none';

      if (_nearZero(deltaShares)) {
        // 情况1：ΔQ == 0，网格闭环利润 = -ΔV
        gridProfitDelta = -deltaCapital;
        eventType = 'flat_trade';
      } else if (deltaShares > 0) {
        // 情况2：ΔQ > 0，净买入，压入 LIFO 栈
        stack.add(_Lot(deltaShares, deltaCapital));
        gridProfitDelta = 0.0;
        eventType = 'buy';
      } else {
        // 情况3：ΔQ < 0，净卖出，使用 LIFO 栈
        double sellSharesRemaining = -deltaShares;
        final double cashIn = -deltaCapital;
        double costOut = 0.0;

        while (sellSharesRemaining > _eps && stack.isNotEmpty) {
          final lot = stack.removeLast();

          if (lot.shares <= sellSharesRemaining + _eps) {
            costOut += lot.cost;
            sellSharesRemaining -= lot.shares;
          } else {
            final portion = sellSharesRemaining / lot.shares;
            final consumedCost = lot.cost * portion;
            costOut += consumedCost;

            final remainingShares = lot.shares - sellSharesRemaining;
            final remainingCost = lot.cost - consumedCost;
            stack.add(_Lot(remainingShares, remainingCost));
            sellSharesRemaining = 0.0;
          }
        }

        // 若历史栈不足以覆盖卖出份额，做温和兜底，避免结果失真为 NaN
        if (sellSharesRemaining > _eps) {
          costOut += sellSharesRemaining * prevAvgCost;
          eventType = 'sell_with_fallback';
        } else {
          eventType = 'sell';
        }

        gridProfitDelta = cashIn - costOut;
      }

      if (_nearZero(gridProfitDelta)) {
        gridProfitDelta = 0.0;
      }

      cumulativeGridProfit += gridProfitDelta;
      if (_nearZero(cumulativeGridProfit)) {
        cumulativeGridProfit = 0.0;
      }

      steps.add(
        GridProfitReconstructionStep(
          date: now.date,
          shares: nowShares,
          averageCost: nowAvgCost,
          netCapital: nowNetCapital,
          deltaShares: deltaShares,
          deltaCapital: deltaCapital,
          gridProfitDelta: gridProfitDelta,
          cumulativeGridProfit: cumulativeGridProfit,
          eventType: eventType,
        ),
      );
    }

    final currentShares = _sanitize(sorted.last.totalShares);
    final gridCostReductionPerShare = currentShares.abs() <= _eps
        ? 0.0
        : cumulativeGridProfit / currentShares;

    return GridProfitReconstructionResult(
      cumulativeGridProfit: cumulativeGridProfit,
      gridCostReductionPerShare:
          _nearZero(gridCostReductionPerShare) ? 0.0 : gridCostReductionPerShare,
      steps: steps,
    );
  }

  double _resolveNetCapital(PositionSnapshot snapshot) {
    final shares = _sanitize(snapshot.totalShares);
    final averageCost = _sanitize(snapshot.averageCost);
    final fallbackNetCapital = _sanitize(shares * averageCost);

    final comprehensiveProfit = snapshot.brokerComprehensiveProfit;
    if (comprehensiveProfit == null || !comprehensiveProfit.isFinite) {
      return fallbackNetCapital;
    }

    final marketValue = _tryResolveMarketValue(snapshot);
    if (marketValue == null) {
      return fallbackNetCapital;
    }

    return _sanitize(marketValue - comprehensiveProfit);
  }

  double? _tryResolveMarketValue(PositionSnapshot snapshot) {
    final dynamic snap = snapshot;

    double? readNum(dynamic value) {
      if (value is num) {
        final v = value.toDouble();
        return v.isFinite ? v : null;
      }
      return null;
    }

    try {
      final v = readNum(snap.marketValue);
      if (v != null) return v;
    } catch (_) {}

    try {
      final v = readNum(snap.currentMarketValue);
      if (v != null) return v;
    } catch (_) {}

    double? price;
    try {
      price = readNum(snap.price);
    } catch (_) {}
    try {
      price ??= readNum(snap.latestPrice);
    } catch (_) {}

    if (price != null) {
      final shares = _sanitize(snapshot.totalShares);
      return _sanitize(shares * price);
    }

    return null;
  }

  bool _nearZero(double value) => value.abs() <= _eps;

  double _sanitize(double value) {
    if (!value.isFinite) return 0.0;
    return value;
  }
}

class _Lot {
  double shares;
  double cost;

  _Lot(this.shares, this.cost);
}

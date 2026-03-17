import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_result.dart';
import 'package:one_five_one_ten/models/grid_profit_reconstruction_step.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/price_sync_service.dart';

class GridProfitReconstructionService {
  static const double _eps = 1e-6;
  static const int _maxLookbackDays = 5;

  Isar get _isar => DatabaseService().isar;

  Future<GridProfitReconstructionResult> reconstructFromSnapshots(
    List<PositionSnapshot> snapshots,
  ) async {
    if (snapshots.length < 2) {
      return const GridProfitReconstructionResult(
        cumulativeGridProfit: 0.0,
        gridCostReductionPerShare: 0.0,
        steps: [],
      );
    }

    final sorted = snapshots.toList()..sort((a, b) => a.date.compareTo(b.date));
    final asset = await _resolveAsset(sorted);
    final priceByDay = await _loadHistoricalPriceMap(asset);

    final Map<DateTime, int> dayTotalCounts = <DateTime, int>{};
    for (final snapshot in sorted) {
      final day = _dateOnly(snapshot.date);
      dayTotalCounts[day] = (dayTotalCounts[day] ?? 0) + 1;
    }

    final List<double> netCapitals = <double>[];
    final Map<DateTime, int> dayCurrentIndexes = <DateTime, int>{};

    for (final snapshot in sorted) {
      final currentDay = _dateOnly(snapshot.date);
      final dayIndex = dayCurrentIndexes[currentDay] ?? 0;
      final dayTotal = dayTotalCounts[currentDay] ?? 0;
      final bool forceUsePreviousDay = dayTotal > 1 && dayIndex == 0;

      final netCapital = _resolveNetCapital(
        snapshot: snapshot,
        priceByDay: priceByDay,
        forceUsePreviousDay: forceUsePreviousDay,
      );
      netCapitals.add(netCapital);
      dayCurrentIndexes[currentDay] = dayIndex + 1;
    }

    final List<_Lot> stack = <_Lot>[];
    final List<GridProfitReconstructionStep> steps =
        <GridProfitReconstructionStep>[];

    double cumulativeGridProfit = 0.0;

    final first = sorted.first;
    final firstShares = _sanitize(first.totalShares);
    final firstAverageCost = _sanitize(first.averageCost);
    final firstNetCapital = netCapitals.first;

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
      final prevNetCapital = netCapitals[i - 1];

      final nowShares = _sanitize(now.totalShares);
      final nowAvgCost = _sanitize(now.averageCost);
      final nowNetCapital = netCapitals[i];

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

  Future<Asset?> _resolveAsset(List<PositionSnapshot> snapshots) async {
    String? assetSupabaseId;
    for (final snapshot in snapshots) {
      final id = snapshot.assetSupabaseId;
      if (id != null && id.isNotEmpty) {
        assetSupabaseId = id;
        break;
      }
    }
    if (assetSupabaseId == null) return null;

    return _isar.assets.where().supabaseIdEqualTo(assetSupabaseId).findFirst();
  }

  Future<Map<DateTime, double>> _loadHistoricalPriceMap(Asset? asset) async {
    if (asset == null || asset.code.isEmpty) return const {};

    final service = PriceSyncService();
    List<FlSpot> spots = const [];

    switch (asset.subType) {
      case AssetSubType.stock:
      case AssetSubType.etf:
        spots = await service.syncKLineHistory(asset.code);
        break;
      case AssetSubType.mutualFund:
        spots = await service.syncNavHistory(asset.code);
        break;
      default:
        spots = const [];
    }

    final map = <DateTime, double>{};
    for (final spot in spots) {
      final day = _dateOnly(
        DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()).toLocal(),
      );
      final price = _sanitize(spot.y);
      if (price > 0) {
        map[day] = price;
      }
    }
    return map;
  }

  double _resolveNetCapital({
    required PositionSnapshot snapshot,
    required Map<DateTime, double> priceByDay,
    required bool forceUsePreviousDay,
  }) {
    final shares = _sanitize(snapshot.totalShares);
    final averageCost = _sanitize(snapshot.averageCost);
    final fallbackNetCapital = _sanitize(shares * averageCost);

    final comprehensiveProfit = snapshot.brokerComprehensiveProfit;
    if (comprehensiveProfit == null || !comprehensiveProfit.isFinite) {
      return fallbackNetCapital;
    }

    final baseDay = _dateOnly(snapshot.date);
    final startDay = forceUsePreviousDay
        ? baseDay.subtract(const Duration(days: 1))
        : baseDay;

    double? historicalPrice;
    for (int i = 0; i <= _maxLookbackDays; i++) {
      final candidate = startDay.subtract(Duration(days: i));
      final price = priceByDay[candidate];
      if (price != null && price.isFinite && price > 0) {
        historicalPrice = price;
        break;
      }
    }

    if (historicalPrice == null) {
      return fallbackNetCapital;
    }

    final marketValue = _sanitize(shares * historicalPrice);
    return _sanitize(marketValue - comprehensiveProfit);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

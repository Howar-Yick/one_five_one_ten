class GridProfitReconstructionStep {
  final DateTime date;
  final double shares;
  final double averageCost;
  final double netCapital;
  final double deltaShares;
  final double deltaCapital;
  final double gridProfitDelta;
  final double cumulativeGridProfit;
  final String eventType;

  const GridProfitReconstructionStep({
    required this.date,
    required this.shares,
    required this.averageCost,
    required this.netCapital,
    required this.deltaShares,
    required this.deltaCapital,
    required this.gridProfitDelta,
    required this.cumulativeGridProfit,
    required this.eventType,
  });
}

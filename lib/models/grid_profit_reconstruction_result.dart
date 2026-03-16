import 'package:one_five_one_ten/models/grid_profit_reconstruction_step.dart';

class GridProfitReconstructionResult {
  final double cumulativeGridProfit;
  final double gridCostReductionPerShare;
  final List<GridProfitReconstructionStep> steps;

  const GridProfitReconstructionResult({
    required this.cumulativeGridProfit,
    required this.gridCostReductionPerShare,
    required this.steps,
  });
}

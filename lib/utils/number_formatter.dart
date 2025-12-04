import 'package:one_five_one_ten/models/asset.dart';

String formatSnapshotUnitCost(double cost, Asset asset) {
  if (asset.subType == AssetSubType.etf) {
    return cost.toStringAsFixed(3);
  }

  if (asset.subType == AssetSubType.mutualFund) {
    return cost.toStringAsFixed(4);
  }

  // 其他资产类型维持默认行为（当前为 3 位小数）
  return cost.toStringAsFixed(3);
}

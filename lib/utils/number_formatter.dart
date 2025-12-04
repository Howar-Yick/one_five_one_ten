import 'package:one_five_one_ten/models/asset.dart';

String formatSnapshotUnitCost(double cost, Asset asset) {
  if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
    return cost.toStringAsFixed(3);
  }
  return cost.toStringAsFixed(4);
}

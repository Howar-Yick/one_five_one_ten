// 文件: lib/allocation/allocation_service.dart
// (*** 关键修改：增加了一个 'values' 字段来存储每个类别的总金额 ***)

import 'dart:math';
import 'mapping.dart';
import 'override_service.dart';

/// —— 轻量数据面向接口 ——
class PositionLike {
  final int id;
  final int accountId;
  final String code;
  final String name;
  final double marketValue;
  final String? subType;

  PositionLike({
    required this.id,
    required this.accountId,
    required this.code,
    required this.name,
    required this.marketValue,
    this.subType,
  });
}

/// —— 数据源注册 ——
typedef AllocationDataSource = Future<List<PositionLike>> Function();

class AllocationRegistry {
  static AllocationDataSource? _source;
  static void register(AllocationDataSource source) { _source = source; }
  static AllocationDataSource? get source => _source;
}

/// —— 汇总计算 ——
class AllocationSnapshot {
  final Map<AllocationBucket, double> weights;
  final double total;
  final Map<AllocationBucket, List<PositionLike>> groupedItems;
  // (*** 1. 新增：存储每个类别的具体金额 ***)
  final Map<AllocationBucket, double> values;

  AllocationSnapshot(this.weights, this.total, this.groupedItems, this.values);
}

class AllocationService {
  final _overrideService = OverrideService();

  Future<AllocationSnapshot> buildSnapshot(List<PositionLike> items) async {
    double total = 0;
    final byBucketValue = <AllocationBucket, double>{};
    final byBucketItems = <AllocationBucket, List<PositionLike>>{};
    
    final overrides = await _overrideService.loadOverrides();

    for (final p in items) {
      final v = max(0.0, p.marketValue);
      total += v;
      
      final bucket = mapToBucket(
        id: p.id, 
        code: p.code, 
        name: p.name, 
        subType: p.subType, 
        overrides: overrides,
      );
      
      byBucketValue.update(bucket, (x) => x + v, ifAbsent: () => v);
      byBucketItems.putIfAbsent(bucket, () => []).add(p);
    }

    final weights = <AllocationBucket, double>{};
    byBucketValue.forEach((b, v) {
      weights[b] = total > 0 ? v / total : 0.0;
    });

    // (*** 2. 在返回结果中包含具体金额的 Map ***)
    return AllocationSnapshot(weights, total, byBucketItems, byBucketValue);
  }
}
// 文件: lib/allocation/allocation_service.dart
// (*** 关键修复：修正了 'max' 函数的类型错误 ***)

import 'dart:math';
import 'mapping.dart';

/// —— 轻量数据面向接口 ——
/// 你的适配器只要返回这一组即可（不需改数据库）
class PositionLike {
  final String code;         // 证券代码（如 159509）
  final String name;         // 名称（UI展示）
  final double marketValue;  // 以 CNY 计的市值
  final String? subType;     // 可空，用于更准确归桶（如 fixedIncome/wealthManagement/commodity 等）

  PositionLike({
    required this.code,
    required this.name,
    required this.marketValue,
    this.subType,
  });
}

/// —— 数据源注册 ——
/// 由主工程在启动时注入一个函数即可；未注册时页面会给出提示，不会报错。
typedef AllocationDataSource = Future<List<PositionLike>> Function();

class AllocationRegistry {
  static AllocationDataSource? _source;
  static void register(AllocationDataSource source) { _source = source; }
  static AllocationDataSource? get source => _source;
}

/// —— 汇总计算 ——
/// 输入：PositionLike 列表
/// 输出：各 bucket 的权重（0~1）与总资产
class AllocationSnapshot {
  final Map<AllocationBucket, double> weights;
  final double total;

  AllocationSnapshot(this.weights, this.total);
}

class AllocationService {
  Future<AllocationSnapshot> buildSnapshot(List<PositionLike> items) async {
    double total = 0;
    final byBucket = <AllocationBucket, double>{};

    for (final p in items) {
      // (*** 修复逻辑：将 0 改为 0.0，确保返回类型为 double ***)
      final v = max(0.0, p.marketValue);
      // (*** 修复结束 ***)

      total += v;
      final bucket = mapToBucket(code: p.code, subType: p.subType);
      byBucket.update(bucket, (x) => x + v, ifAbsent: () => v);
    }

    final weights = <AllocationBucket, double>{};
    byBucket.forEach((b, v) {
      weights[b] = total > 0 ? v / total : 0.0;
    });

    return AllocationSnapshot(weights, total);
  }
}
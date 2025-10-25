// File: lib/services/allocation_service.dart
import 'dart:math';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/allocation_bucket.dart';
import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_plan_bucket.dart';
import 'package:one_five_one_ten/models/asset_bucket_map.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';

/// 仅做读取与计算，不改动原有资产/交易/快照数据
class AllocationService {
  final Isar _isar;
  final CalculatorService _calc;

  AllocationService({Isar? isar, CalculatorService? calculator})
      : _isar = isar ?? DatabaseService().isar,
        _calc = calculator ?? CalculatorService();

  /// 读取默认方案；若没有默认，则返回任意一个方案（或 null）
  Future<AllocationPlan?> getDefaultPlan() async {
    final plans = await _isar.allocationPlans.where().findAll();
    if (plans.isEmpty) return null;
    final def = plans.firstWhere((p) => p.isDefault, orElse: () => plans.first);
    return def;
  }

  /// 获取某方案下的桶定义（含覆盖权重逻辑）
  Future<List<_ResolvedBucket>> getResolvedBuckets(int planId) async {
    final buckets = await _isar.allocationBuckets
        .where()
        .filter()
        .isActiveEqualTo(true)
        .sortByOrder()
        .findAll();

    final overrides = await _isar.allocationPlanBuckets
        .where()
        .filter()
        .planIdEqualTo(planId)
        .findAll();

    final byId = {for (final b in buckets) b.id: b};
    final List<_ResolvedBucket> result = [];
    for (final b in buckets) {
      final ov = overrides.firstWhere(
        (x) => x.bucketId == b.id,
        orElse: () => AllocationPlanBucket()
          ..planId = planId
          ..bucketId = b.id
          ..targetWeightOverride = null,
      );
      result.add(_ResolvedBucket(
        bucket: b,
        targetWeight: ov.targetWeightOverride ?? b.targetWeight,
      ));
    }
    return result;
  }

  /// 读取“资产→桶”映射（该 planId 下 + 默认映射）
  Future<List<AssetBucketMap>> getAssetMappings({int? planId}) async {
    final defaultMaps = await _isar.assetBucketMaps
        .where()
        .filter()
        .planIdIsNull()
        .findAll();
    if (planId == null) return defaultMaps;

    final planMaps = await _isar.assetBucketMaps
        .where()
        .filter()
        .planIdEqualTo(planId)
        .findAll();

    // 同一资产在 plan 中映射优先覆盖默认映射
    final key = (AssetBucketMap m) =>
        '${m.assetSupabaseId ?? ''}#${m.assetId ?? -1}';
    final merged = <String, AssetBucketMap>{};
    for (final m in defaultMaps) merged[key(m)] = m;
    for (final m in planMaps) merged[key(m)] = m;
    return merged.values.toList();
  }

  /// 计算当前配置情况（全局或按账户过滤）
  ///
  /// 返回：
  /// - buckets: 每个桶当前金额 & 当前权重 & 目标权重 & 偏离
  /// - total: 总额
  Future<AllocationSummary> buildCurrentAllocation({
    required int planId,
    int? accountId, // 可选：按账户维度统计
  }) async {
    final resolved = await getResolvedBuckets(planId);
    final mappings = await getAssetMappings(planId: planId);

    // 构建 bucket 聚合容器
    final byBucket = <int, _BucketAgg>{
      for (final r in resolved) r.bucket.id: _BucketAgg(targetWeight: r.targetWeight)
    };

    // 读取资产 & 金额（只读，复用现有计算）
    final isarAssets = await _isar.assets.where().findAll();
    // 过滤账号
    // 过滤账户：根据 supabaseId 关联
    List<Asset> filtered = isarAssets;
    if (accountId != null) {
      // 先找到该账户对应的 supabaseId
      final acc = await _isar.accounts.get(accountId);
      final accSupa = acc?.supabaseId;
      if (accSupa != null) {
        filtered = isarAssets
            .where((a) => a.accountSupabaseId == accSupa)
            .toList();
      } else {
        // 没找到 supabaseId，就返回空（理论上不应出现）
        filtered = [];
      }
    }
    // 建索引：assetId/supabaseId -> bucketId
    int? resolveBucketIdForAsset(Asset a) {
      final hit = mappings.firstWhere(
        (m) =>
            (a.supabaseId != null && a.supabaseId == m.assetSupabaseId) ||
            (a.id == m.assetId),
        orElse: () => AssetBucketMap()..bucketId = -1,
      );
      return hit.bucketId == -1 ? null : hit.bucketId;
    }

    // 逐资产累加现值
    for (final a in filtered) {
      final bId = resolveBucketIdForAsset(a);
      if (bId == null) continue;
      if (!byBucket.containsKey(bId)) {
        // 映射到了“非激活/未在方案中”的桶：忽略（保证方案干净）
        continue;
      }
      // shareBased -> marketValue, valueBased -> currentValue
      final perf = a.trackingMethod == AssetTrackingMethod.shareBased
          ? await _calc.calculateShareAssetPerformance(a)
          : await _calc.calculateValueAssetPerformance(a);

      final mv = a.trackingMethod == AssetTrackingMethod.shareBased
          ? (perf['marketValue'] ?? 0.0) as double
          : (perf['currentValue'] ?? 0.0) as double;

      byBucket[bId]!.amount += mv;
    }

    // 计算权重与偏离
    final total = byBucket.values.fold<double>(0.0, (s, x) => s + x.amount);
    final items = <AllocationItem>[];
    for (final entry in byBucket.entries) {
      final bucket =
          await _isar.allocationBuckets.where().idEqualTo(entry.key).findFirst();
      if (bucket == null) continue;
      final curW = total <= 0 ? 0.0 : (entry.value.amount / max(total, 1e-9));
      items.add(AllocationItem(
        bucket: bucket,
        amount: entry.value.amount,
        currentWeight: curW,
        targetWeight: entry.value.targetWeight,
        drift: curW - entry.value.targetWeight,
      ));
    }

    // 按偏离绝对值倒序，便于 UI 展示
    items.sort((a, b) => b.drift.abs().compareTo(a.drift.abs()));

    return AllocationSummary(
      items: items,
      total: total,
    );
  }
}

/// —— 数据载体 ——
/// 这些是计算层的纯 Dart 对象，不入库
class AllocationSummary {
  final List<AllocationItem> items;
  final double total;
  AllocationSummary({required this.items, required this.total});
}

class AllocationItem {
  final AllocationBucket bucket;
  final double amount;
  final double currentWeight;
  final double targetWeight;
  final double drift;
  AllocationItem({
    required this.bucket,
    required this.amount,
    required this.currentWeight,
    required this.targetWeight,
    required this.drift,
  });
}

/// —— 内部使用的小结构 ——
/// 解析覆盖权重后的桶
class _ResolvedBucket {
  final AllocationBucket bucket;
  final double targetWeight;
  _ResolvedBucket({required this.bucket, required this.targetWeight});
}

class _BucketAgg {
  double amount = 0.0;
  final double targetWeight;
  _BucketAgg({required this.targetWeight});
}

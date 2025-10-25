// File: lib/services/allocation_service.dart
// Step 2 - Allocation Planner service (no changes to existing logic)

import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';

import 'package:one_five_one_ten/models/allocation_models.dart';

class AllocationService {
  final Isar _isar = DatabaseService().isar;

  // ============== CRUD: Scheme ==============
  Future<AllocationScheme> createScheme(String name, {bool isDefault = false}) async {
    final scheme = AllocationScheme()
      ..name = name.trim()
      ..isDefault = isDefault
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.allocationSchemes.put(scheme);
    });
    return scheme;
  }

  Future<List<AllocationScheme>> listSchemes() async {
    return _isar.allocationSchemes.where().sortByCreatedAt().findAll();
  }

  Future<void> setDefaultScheme(AllocationScheme scheme) async {
    await _isar.writeTxn(() async {
      final all = await _isar.allocationSchemes.where().findAll();
      for (final s in all) {
        s.isDefault = (s.id == scheme.id);
        s.updatedAt = DateTime.now();
      }
      await _isar.allocationSchemes.putAll(all);
    });
  }

  Future<void> renameScheme(AllocationScheme scheme, String newName) async {
    scheme
      ..name = newName.trim()
      ..updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.allocationSchemes.put(scheme);
    });
  }

  Future<void> deleteScheme(AllocationScheme scheme) async {
    await _isar.writeTxn(() async {
      // 先删桶和链接
      final buckets = await scheme.buckets.filter().findAll();
      for (final b in buckets) {
        final links = await b.assetLinks.filter().findAll();
        await _isar.assetAllocationLinks.deleteAll(links.map((e) => e.id).toList());
      }
      await _isar.allocationBuckets.deleteAll(buckets.map((e) => e.id).toList());
      // 再删方案
      await _isar.allocationSchemes.delete(scheme.id);
    });
  }

  // ============== CRUD: Bucket ==============
  Future<AllocationBucket> addBucket({
    required AllocationScheme scheme,
    required String name,
    required double targetWeight, // 0~1
    String tag = '',
  }) async {
    final bucket = AllocationBucket()
      ..name = name.trim()
      ..targetWeight = targetWeight
      ..tag = tag
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.allocationBuckets.put(bucket);
      bucket.scheme.value = scheme;
      await bucket.scheme.save();

      scheme.buckets.add(bucket);
      await scheme.buckets.save();

      await _isar.allocationBuckets.put(bucket); // 确保 link 持久化后再写
      await _isar.allocationSchemes.put(scheme);
    });
    return bucket;
  }

  Future<void> updateBucket(AllocationBucket bucket,
      {String? name, double? targetWeight, String? tag}) async {
    if (name != null) bucket.name = name.trim();
    if (targetWeight != null) bucket.targetWeight = targetWeight;
    if (tag != null) bucket.tag = tag;
    bucket.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.allocationBuckets.put(bucket);
    });
  }

  Future<void> deleteBucket(AllocationBucket bucket) async {
    await _isar.writeTxn(() async {
      final links = await bucket.assetLinks.filter().findAll();
      await _isar.assetAllocationLinks.deleteAll(links.map((e) => e.id).toList());
      await _isar.allocationBuckets.delete(bucket.id);
    });
  }

  // ============== Asset linking ==============
  Future<AssetAllocationLink> linkAssetToBucket({
    required AllocationBucket bucket,
    required String assetSupabaseId,
    double? weightOverride, // 0~1 (optional)
  }) async {
    final link = AssetAllocationLink()
      ..assetSupabaseId = assetSupabaseId
      ..weightOverride = weightOverride
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.assetAllocationLinks.put(link);
      link.bucket.value = bucket;
      await link.bucket.save();

      bucket.assetLinks.add(link);
      await bucket.assetLinks.save();

      await _isar.assetAllocationLinks.put(link);
      await _isar.allocationBuckets.put(bucket);
    });
    return link;
  }

  Future<void> unlinkAsset(AssetAllocationLink link) async {
    await _isar.writeTxn(() async {
      await _isar.assetAllocationLinks.delete(link.id);
    });
  }

  // ============== Compute ==============
  /// 读取某个账户（可选）下的实际持仓分布（当前市值占比），用于与目标方案对比
  /// accountId == null 表示全账户合并
  Future<Map<int, double>> computeActualWeightsByBucket({
    required AllocationScheme scheme,
    int? accountId,
  }) async {
    // 1) 找出账户的 supabaseId（你的 Asset 用的是 accountSupabaseId）
    String? accSupa;
    if (accountId != null) {
      final acc = await _isar.accounts.get(accountId);
      accSupa = acc?.supabaseId;
    }

    // 2) 读取所有桶 & 对应的资产链接
    final buckets = await scheme.buckets.filter().findAll();

    // 3) 读取所有资产（按需过滤账户）
    final isarAssets = await _isar.assets.where().findAll();
    List<Asset> filtered = isarAssets;
    if (accSupa != null) {
      filtered = isarAssets
          .where((a) => a.accountSupabaseId == accSupa)
          .toList();
    }

    // 4) 计算每个资产当前市值（沿用 CalculatorService 的定义）
    final calc = CalculatorService();
    final Map<String, double> assetMv = {}; // key: asset.supabaseId, val: market value
    for (final a in filtered) {
      final perf = a.trackingMethod == AssetTrackingMethod.shareBased
          ? await calc.calculateShareAssetPerformance(a)
          : await calc.calculateValueAssetPerformance(a);
      final mv = (a.trackingMethod == AssetTrackingMethod.shareBased
              ? perf['marketValue']
              : perf['currentValue']) ??
          0.0;
      if (a.supabaseId != null) {
        assetMv[a.supabaseId!] = mv;
      }
    }

    // 5) 汇总到 bucket
    final Map<int, double> bucketValue = {}; // key: bucket.id
    double total = 0.0;

    for (final b in buckets) {
      final links = await b.assetLinks.filter().findAll();
      double sum = 0.0;
      for (final l in links) {
        final id = l.assetSupabaseId;
        if (id == null) continue;
        final mv = assetMv[id] ?? 0.0;
        // 可选：按 weightOverride 调整
        if (l.weightOverride != null && l.weightOverride! > 0) {
          sum += mv * l.weightOverride!.clamp(0, 1);
        } else {
          sum += mv;
        }
      }
      bucketValue[b.id] = sum;
      total += sum;
    }

    // 6) 转换为权重（0~1）
    final Map<int, double> bucketWeight = {};
    if (total <= 0) {
      for (final b in buckets) {
        bucketWeight[b.id] = 0.0;
      }
    } else {
      for (final entry in bucketValue.entries) {
        bucketWeight[entry.key] = entry.value / total;
      }
    }
    return bucketWeight;
  }

  /// 读取目标权重（0~1）：key 为 bucket.id
  Future<Map<int, double>> readTargetWeights(AllocationScheme scheme) async {
    final buckets = await scheme.buckets.filter().findAll();
    final Map<int, double> target = {};
    for (final b in buckets) {
      target[b.id] = b.targetWeight;
    }
    return target;
  }

  /// Diff：实际 vs 目标
  Future<Map<int, double>> compareActualVsTarget({
    required AllocationScheme scheme,
    int? accountId,
  }) async {
    final actual = await computeActualWeightsByBucket(scheme: scheme, accountId: accountId);
    final target = await readTargetWeights(scheme);
    final Map<int, double> diff = {};
    for (final id in target.keys) {
      final a = actual[id] ?? 0.0;
      final t = target[id] ?? 0.0;
      diff[id] = a - t; // >0 代表超配，<0 代表低配
    }
    return diff;
  }
}

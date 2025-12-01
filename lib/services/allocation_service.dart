// File: lib/services/allocation_service.dart
// Version: CHATGPT-ALLOC-FIX-MATCH-YOUR-MODELS
//
// 变更点：
// - 使用 sortBySortOrder()（对应你的 sortOrder 字段）
// - 使用 labelEqualTo(...)（在 filter() 阶段），因为没有复合索引 planId+label
// - 用 targetPercent / sortOrder 对齐你的字段
// - 其余保持最小入侵

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/allocation_overview.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';

import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_plan_item.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/asset_bucket_map.dart';

class AllocationService {
  AllocationService._(this.isar);
  static AllocationService? _instance;

  final Isar isar;

  /// 单例（依赖 DatabaseService 已初始化的同一 Isar 实例）
  static AllocationService instance() {
    final db = DatabaseService();
    if (_instance == null) {
      if (Isar.instanceNames.isEmpty) {
        throw StateError(
          'Isar 尚未初始化。请在应用启动时先调用 await DatabaseService().init();',
        );
      }
      _instance = AllocationService._(db.isar);
    }
    return _instance!;
  }

  // ---------------- Plans ----------------

  Stream<List<AllocationPlan>> watchPlans() {
    return isar.allocationPlans.where().sortByUpdatedAtDesc().watch(
          fireImmediately: true,
        );
  }

  Future<List<AllocationPlan>> listPlans() async {
    return isar.allocationPlans.where().sortByUpdatedAtDesc().findAll();
  }

  Future<AllocationPlan> createPlan({required String name, String? note}) async {
    final now = DateTime.now();
    final plan = AllocationPlan()
      ..name = name
      ..note = note
      ..createdAt = now
      ..updatedAt = now;

    await isar.writeTxn(() async {
      await isar.allocationPlans.put(plan); // 自增 id
    });
    return plan;
  }

  Future<void> renamePlan({required int planId, required String name}) async {
    final plan = await isar.allocationPlans.get(planId);
    if (plan == null) return;
    plan
      ..name = name
      ..updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.allocationPlans.put(plan);
    });
  }

  Future<void> updatePlanNote({required int planId, String? note}) async {
    final plan = await isar.allocationPlans.get(planId);
    if (plan == null) return;
    plan
      ..note = note
      ..updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.allocationPlans.put(plan);
    });
  }

  Future<void> deletePlan(int planId) async {
    await isar.writeTxn(() async {
      // 先删子项
      await isar.allocationPlanItems.where().planIdEqualTo(planId).deleteAll();
      await isar.allocationPlans.delete(planId);
    });
  }

  // ---------------- Plan Items ----------------

  Stream<List<AllocationPlanItem>> watchItems(int planId) {
    // 升序：按 sortOrder
    return isar.allocationPlanItems
        .where()
        .planIdEqualTo(planId)
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  Future<List<AllocationPlanItem>> listItems(int planId) async {
    return isar.allocationPlanItems
        .where()
        .planIdEqualTo(planId)
        .sortBySortOrder()
        .findAll();
  }

  /// 新增或更新条目（按 planId + label “去重”）
  Future<AllocationPlanItem> upsertItem({
    required int planId,
    required String label,
    required double targetPercent, // 0~1
    int? sortOrder,
    String? note,
    String? includeRule,
  }) async {
    final now = DateTime.now();

    // 先在该 plan 下按 label 查是否已存在
    final existing = await isar.allocationPlanItems
        .where()
        .planIdEqualTo(planId)
        .filter()
        .labelEqualTo(label)
        .findFirst();

    final item = existing ?? (AllocationPlanItem()..planId = planId);
    item
      ..label = label
      ..targetPercent = targetPercent
      ..sortOrder = sortOrder ?? existing?.sortOrder ?? 0
      ..note = note ?? existing?.note
      ..includeRule = includeRule ?? existing?.includeRule
      ..updatedAt = now;

    await isar.writeTxn(() async {
      await isar.allocationPlanItems.put(item);
    });
    return item;
  }

  Future<void> deleteItem(int itemId) async {
    await isar.writeTxn(() async {
      await isar.allocationPlanItems.delete(itemId);
    });
  }

  /// 批量重排：orderedItemIds 的顺序即为 sortOrder
  Future<void> reorderItems(int planId, List<int> orderedItemIds) async {
    await isar.writeTxn(() async {
      for (int i = 0; i < orderedItemIds.length; i++) {
        final id = orderedItemIds[i];
        final item = await isar.allocationPlanItems.get(id);
        if (item == null || item.planId != planId) continue;
        item
          ..sortOrder = i
          ..updatedAt = DateTime.now();
        await isar.allocationPlanItems.put(item);
      }
    });
  }

  /// 计算目标占比合计（用于 UI 校验）
  Future<double> calcTotalWeight(int planId) async {
    final items = await listItems(planId);
    return items.fold<double>(0, (sum, e) => sum + (e.targetPercent));
  }

  // ---------------- Asset Mapping ----------------

  Stream<List<AssetBucketMap>> watchPlanAssetMappings(int planId) {
    return isar.assetBucketMaps
        .where()
        .planIdEqualTo(planId)
        .watch(fireImmediately: true);
  }

  Future<List<AssetBucketMap>> listPlanAssetMappings(int planId) async {
    return isar.assetBucketMaps.where().planIdEqualTo(planId).findAll();
  }

  Future<void> assignAssetToPlanBucket({
    required int planId,
    required int bucketId,
    required Asset asset,
  }) async {
    final now = DateTime.now();
    await isar.writeTxn(() async {
      AssetBucketMap? record;
      int? keepId;

      if (asset.supabaseId != null && asset.supabaseId!.isNotEmpty) {
        final supaMatches = await isar.assetBucketMaps
            .where()
            .planIdEqualTo(planId)
            .filter()
            .assetSupabaseIdEqualTo(asset.supabaseId!)
            .findAll();
        if (supaMatches.isNotEmpty) {
          record = supaMatches.first;
          keepId = record.id;
          for (final extra in supaMatches.skip(1)) {
            await isar.assetBucketMaps.delete(extra.id);
          }
        }
      }

      final idMatches = await isar.assetBucketMaps
          .where()
          .planIdEqualTo(planId)
          .filter()
          .assetIdEqualTo(asset.id)
          .findAll();

      if (idMatches.isNotEmpty) {
        record ??= idMatches.first;
        keepId ??= record.id;
        for (final extra in idMatches) {
          if (extra.id != keepId) {
            await isar.assetBucketMaps.delete(extra.id);
          }
        }
      }

      record ??= AssetBucketMap()
        ..createdAt = now;

      record
        ..assetSupabaseId = asset.supabaseId
        ..assetId = asset.id
        ..planId = planId
        ..bucketId = bucketId
        ..updatedAt = now;

      await isar.assetBucketMaps.put(record);
    });
  }

  Future<void> removeAssetFromPlanBucket({
    required int planId,
    required int bucketId,
    required Asset asset,
  }) async {
    await isar.writeTxn(() async {
      if (asset.supabaseId != null && asset.supabaseId!.isNotEmpty) {
        final supaMatches = await isar.assetBucketMaps
            .where()
            .planIdEqualTo(planId)
            .filter()
            .assetSupabaseIdEqualTo(asset.supabaseId!)
            .bucketIdEqualTo(bucketId)
            .findAll();
        for (final entry in supaMatches) {
          await isar.assetBucketMaps.delete(entry.id);
        }
      }

      final idMatches = await isar.assetBucketMaps
          .where()
          .planIdEqualTo(planId)
          .filter()
          .assetIdEqualTo(asset.id)
          .bucketIdEqualTo(bucketId)
          .findAll();

      for (final entry in idMatches) {
        await isar.assetBucketMaps.delete(entry.id);
      }
    });
  }

  Stream<AllocationOverview?> watchOverviewForChart() {
    return Stream<AllocationOverview?>.multi((controller) {
      final subs = <StreamSubscription<dynamic>>[];
      var disposed = false;
      Future<void>? running;
      var scheduled = false;

      Future<void> trigger() async {
        if (disposed) return;
        if (running != null) {
          scheduled = true;
          return;
        }
        scheduled = false;
        running = _buildOverview().then((value) {
          if (!disposed) {
            controller.add(value);
          }
        }).catchError((error, stack) {
          if (!disposed) {
            controller.addError(error, stack);
          }
        }).whenComplete(() {
          running = null;
          if (scheduled && !disposed) {
            trigger();
          }
        });
      }

      void listenTo(Stream<dynamic> stream) {
        subs.add(stream.listen((_) => trigger(),
            onError: (Object error, StackTrace stack) {
          if (!disposed) {
            controller.addError(error, stack);
          }
        }));
      }

      listenTo(isar.allocationPlans.watchLazy(fireImmediately: true));
      listenTo(isar.allocationPlanItems.watchLazy(fireImmediately: true));
      listenTo(isar.assetBucketMaps.watchLazy(fireImmediately: true));
      listenTo(isar.assets.watchLazy(fireImmediately: true));
      listenTo(isar.transactions.watchLazy(fireImmediately: true));
      listenTo(isar.positionSnapshots.watchLazy(fireImmediately: true));

      trigger();

      controller.onCancel = () async {
        disposed = true;
        for (final sub in subs) {
          await sub.cancel();
        }
      };
    });
  }

  Future<AllocationOverview?> _buildOverview() async {
    final plans = await listPlans();
    if (plans.isEmpty) return null;

    final plan = plans.firstWhere((p) => p.isActive, orElse: () => plans.first);
    final items = await listItems(plan.id);
    final validItems = items
        .where((e) => e.targetPercent > 0)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final totalTarget =
        validItems.fold<double>(0, (sum, e) => sum + e.targetPercent);

    if (validItems.isEmpty || totalTarget <= 0) {
      return const AllocationOverview(targetSlices: [], actualSlices: []);
    }

    final colors = Colors.primaries;
    final targetSlices = <AllocationChartSlice>[];
    final labelColor = <String, Color>{};
    final bucketLabels = <int, String>{};

    for (var i = 0; i < validItems.length; i++) {
      final item = validItems[i];
      final share = item.targetPercent / totalTarget;
      final color = colors[i % colors.length];
      bucketLabels[item.id] = item.label;
      labelColor[item.label] = color;

      targetSlices.add(
        AllocationChartSlice(
          label: item.label,
          percent: share,
          color: color,
        ),
      );
    }

    final actualSlices =
        await _buildActualSlices(plan.id, bucketLabels, labelColor);

    return AllocationOverview(
      targetSlices: targetSlices,
      actualSlices: actualSlices,
    );
  }

  Future<List<AllocationChartSlice>> _buildActualSlices(
    int planId,
    Map<int, String> bucketLabels,
    Map<String, Color> labelColor,
  ) async {
    final calcService = CalculatorService();
    final fxService = ExchangeRateService();

    final mappings = await isar.assetBucketMaps
        .where()
        .planIdEqualTo(planId)
        .findAll();

    if (mappings.isEmpty) return const <AllocationChartSlice>[];

    final assetIds = <int>{};
    final supabaseIds = <String>{};
    for (final mapping in mappings) {
      if (mapping.assetId != null) {
        assetIds.add(mapping.assetId!);
      }
      final supa = mapping.assetSupabaseId;
      if (supa != null && supa.isNotEmpty) {
        supabaseIds.add(supa);
      }
    }

    final assets = <int, Asset>{};
    if (assetIds.isNotEmpty) {
      final fetched = await isar.assets.getAll(assetIds.toList());
      for (final asset in fetched) {
        if (asset != null && !asset.isArchived) {
          assets[asset.id] = asset;
        }
      }
    }

    if (supabaseIds.isNotEmpty) {
      final supaAssets = await isar.assets
          .where()
          .filter()
          .anyOf(supabaseIds, (q, supa) => q.supabaseIdEqualTo(supa))
          .findAll();
      for (final asset in supaAssets) {
        if (!asset.isArchived) {
          assets[asset.id] = asset;
        }
      }
    }

    final currencyCache = <String, double>{};
    Future<double> toCnyRate(String currency) async {
      if (currencyCache.containsKey(currency)) {
        return currencyCache[currency]!;
      }
      final rate = await fxService.getRate(currency, 'CNY');
      currencyCache[currency] = rate;
      return rate;
    }

    final supabaseLookup = <String, Asset>{};
    for (final asset in assets.values) {
      final supa = asset.supabaseId;
      if (supa != null && supa.isNotEmpty) {
        supabaseLookup[supa.toLowerCase()] = asset;
      }
    }

    final assetValueCache = <int, double>{};
    Future<double> assetValueInCny(Asset asset) async {
      if (assetValueCache.containsKey(asset.id)) {
        return assetValueCache[asset.id]!;
      }

      double localValue = 0.0;
      if (asset.subType == AssetSubType.wealthManagement) {
        final perf = await calcService.calculateValueAssetPerformance(asset);
        localValue = (perf['currentValue'] as num?)?.toDouble() ?? 0.0;
      } else if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
        final perf = await calcService.calculateShareAssetPerformance(asset);
        localValue = (perf['marketValue'] as num?)?.toDouble() ?? 0.0;
      } else {
        final perf = await calcService.calculateValueAssetPerformance(asset);
        localValue = (perf['currentValue'] as num?)?.toDouble() ?? 0.0;
      }

      final rate = await toCnyRate(asset.currency);
      final converted = localValue * rate;
      final normalized = converted.isFinite ? converted : 0.0;
      assetValueCache[asset.id] = normalized;
      return normalized;
    }

    final bucketTotals = <int, double>{};
    double planTotal = 0.0;

    for (final mapping in mappings) {
      Asset? asset;
      if (mapping.assetId != null) {
        asset = assets[mapping.assetId!];
      }
      asset ??= supabaseLookup[(mapping.assetSupabaseId ?? '').toLowerCase()];
      if (asset == null) continue;

      final value = await assetValueInCny(asset);
      final positive = value.isFinite && value > 0 ? value : 0.0;
      if (positive <= 0) {
        bucketTotals.putIfAbsent(mapping.bucketId, () => 0.0);
        continue;
      }
      bucketTotals.update(mapping.bucketId, (prev) => prev + positive,
          ifAbsent: () => positive);
      planTotal += positive;
    }

    if (planTotal <= 0) {
      return const <AllocationChartSlice>[];
    }

    final actualSlices = <AllocationChartSlice>[];
    for (final entry in bucketLabels.entries) {
      final bucketId = entry.key;
      final label = entry.value;
      final bucketValue = bucketTotals[bucketId] ?? 0.0;
      if (bucketValue <= 0) continue;
      actualSlices.add(
        AllocationChartSlice(
          label: label,
          percent: bucketValue / planTotal,
          color: labelColor[label] ?? Colors.grey,
        ),
      );
    }

    return actualSlices;
  }
}

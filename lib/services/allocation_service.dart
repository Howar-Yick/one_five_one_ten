// File: lib/services/allocation_service.dart
// Version: CHATGPT-ALLOC-FIX-MATCH-YOUR-MODELS
//
// 变更点：
// - 使用 sortBySortOrder()（对应你的 sortOrder 字段）
// - 使用 labelEqualTo(...)（在 filter() 阶段），因为没有复合索引 planId+label
// - 用 targetPercent / sortOrder 对齐你的字段
// - 其余保持最小入侵

import 'package:isar/isar.dart';
import 'package:one_five_one_ten/services/database_service.dart';

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
}

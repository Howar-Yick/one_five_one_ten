// File: lib/providers/allocation_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_bucket.dart';
import 'package:one_five_one_ten/models/allocation_plan_bucket.dart';
import 'package:one_five_one_ten/models/asset_bucket_map.dart';
import 'package:one_five_one_ten/services/allocation_service.dart';

/// Isar 实例
final allocationIsarProvider = Provider<Isar>((ref) {
  return DatabaseService().isar;
});

/// Service
final allocationServiceProvider = Provider<AllocationService>((ref) {
  return AllocationService(isar: ref.read(allocationIsarProvider));
});

/// 方案列表（按 isDefault DESC, updatedAt DESC）
final allocationPlansProvider = StreamProvider<List<AllocationPlan>>((ref) {
  final isar = ref.read(allocationIsarProvider);
  return isar.allocationPlans
      .where()
      .sortByUpdatedAtDesc()
      .watch(fireImmediately: true);
});

/// 默认方案（无则返回 null）
final defaultAllocationPlanProvider = FutureProvider<AllocationPlan?>((ref) async {
  final svc = ref.read(allocationServiceProvider);
  return svc.getDefaultPlan();
});

/// 当前方案的桶（解析覆盖权重后）
final allocationResolvedBucketsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, planId) async {
  final svc = ref.read(allocationServiceProvider);
  final resolved = await svc.getResolvedBuckets(planId);
  return resolved
      .map((r) => {
            'bucket': r.bucket,
            'targetWeight': r.targetWeight,
          })
      .toList();
});

/// 资产映射（默认 + 指定方案合并后）
final allocationAssetMappingsProvider =
    FutureProvider.family<List<AssetBucketMap>, int?>((ref, planId) async {
  final svc = ref.read(allocationServiceProvider);
  return svc.getAssetMappings(planId: planId);
});

/// 汇总结果（可选按账户过滤）
final allocationSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, ({int planId, int? accountId})>(
        (ref, args) async {
  final svc = ref.read(allocationServiceProvider);
  final summary = await svc.buildCurrentAllocation(
    planId: args.planId,
    accountId: args.accountId,
  );
  return {
    'total': summary.total,
    'items': summary.items, // List<AllocationItem>
  };
});

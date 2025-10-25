// File: lib/providers/allocation_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/services/allocation_service.dart';
import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_plan_item.dart';

/// Service 单例
final allocationServiceProvider = Provider<AllocationService>((ref) {
  return AllocationService.instance();
});

/// 所有方案（按更新时间倒序）
final allocationPlansProvider = StreamProvider<List<AllocationPlan>>((ref) {
  final svc = ref.watch(allocationServiceProvider);
  return svc.watchPlans();
});

/// 指定方案下的所有条目（按 sortOrder 升序）
final allocationItemsProvider = StreamProvider.family<List<AllocationPlanItem>, int>((ref, planId) {
  final svc = ref.watch(allocationServiceProvider);
  return svc.watchItems(planId);
});

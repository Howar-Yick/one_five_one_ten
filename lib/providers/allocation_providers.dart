// File: lib/providers/allocation_providers.dart
// Step 2 - Riverpod providers for allocation planner (standalone)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/models/allocation_models.dart';
import 'package:one_five_one_ten/services/allocation_service.dart';

final allocationServiceProvider = Provider<AllocationService>((ref) {
  return AllocationService();
});

final allocationSchemesProvider =
    StreamProvider.autoDispose<List<AllocationScheme>>((ref) async* {
  final isar = DatabaseService().isar;
  yield* isar.allocationSchemes.where().sortByCreatedAt().watch(fireImmediately: true);
});

final allocationBucketsProvider =
    StreamProvider.autoDispose.family<List<AllocationBucket>, int>((ref, schemeId) async* {
  final isar = DatabaseService().isar;
  yield* isar.allocationBuckets
      .filter()
      .scheme((q) => q.idEqualTo(schemeId))
      .sortByCreatedAt()
      .watch(fireImmediately: true);
});

final bucketLinksProvider =
    StreamProvider.autoDispose.family<List<AssetAllocationLink>, int>((ref, bucketId) async* {
  final isar = DatabaseService().isar;
  yield* isar.assetAllocationLinks
      .filter()
      .bucket((q) => q.idEqualTo(bucketId))
      .watch(fireImmediately: true);
});

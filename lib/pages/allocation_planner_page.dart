// File: lib/pages/allocation_planner_page.dart
// Minimal UI skeleton aligned with AllocationPlan / AllocationPlanItem models.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';

import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_plan_item.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/asset_bucket_map.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/providers/allocation_providers.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/allocation_service.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';

final NumberFormat _percentFormatter =
    NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;
final NumberFormat _currencyFormatter =
    NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

final _activeAssetsProvider =
    StreamProvider.autoDispose<List<Asset>>((ref) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.assets.where().watch(fireImmediately: true).map((assets) {
    final list = assets
        .where((asset) => !asset.isArchived)
        .toList(growable: false)
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return list;
  });
});

final _planMappingsProvider = StreamProvider.autoDispose
    .family<List<AssetBucketMap>, int>((ref, planId) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.assetBucketMaps
      .where()
      .planIdEqualTo(planId)
      .watch(fireImmediately: true);
});

class _PlanBucketMetrics {
  const _PlanBucketMetrics({required this.bucketValue, required this.planTotal});

  final double bucketValue;
  final double planTotal;

  double get currentPercent => planTotal <= 0 ? 0.0 : bucketValue / planTotal;
}

final _planBucketStatsProvider = StreamProvider.autoDispose
    .family<Map<int, _PlanBucketMetrics>, int>((ref, planId) {
  final isar = ref.watch(databaseServiceProvider).isar;
  final calcService = CalculatorService();
  final fxService = ExchangeRateService();

  Future<Map<int, _PlanBucketMetrics>> load() async {
    final items = await isar.allocationPlanItems
        .where()
        .planIdEqualTo(planId)
        .findAll();

    if (items.isEmpty) {
      return const <int, _PlanBucketMetrics>{};
    }

    final mappings = await isar.assetBucketMaps
        .where()
        .planIdEqualTo(planId)
        .findAll();

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

    final totals = <int, _PlanBucketMetrics>{};
    for (final item in items) {
      final bucketValue = bucketTotals[item.id] ?? 0.0;
      totals[item.id] =
          _PlanBucketMetrics(bucketValue: bucketValue, planTotal: planTotal);
    }

    return totals;
  }

  return Stream<Map<int, _PlanBucketMetrics>>.multi((controller) {
    final subs = <StreamSubscription<dynamic>>[];
    var disposed = false;
    Future<void>? running;
    bool scheduled = false;

    Future<void> trigger() async {
      if (disposed) return;
      if (running != null) {
        scheduled = true;
        return;
      }
      scheduled = false;
      running = load().then((value) {
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

    listenTo(isar.assetBucketMaps
        .where()
        .planIdEqualTo(planId)
        .watchLazy(fireImmediately: true));
    listenTo(isar.allocationPlanItems
        .where()
        .planIdEqualTo(planId)
        .watchLazy(fireImmediately: true));
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
});

class AllocationPlannerPage extends ConsumerStatefulWidget {
  final int? accountId; // 可选：用于查看某账户的实际分布
  const AllocationPlannerPage({super.key, this.accountId});

  @override
  ConsumerState<AllocationPlannerPage> createState() => _AllocationPlannerPageState();
}

class _AllocationPlannerPageState extends ConsumerState<AllocationPlannerPage> {
  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(allocationPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('资产配置规划器（试验功能）')),
      body: plansAsync.when(
        data: (plans) => _buildPlanList(context, plans),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新建方案'),
        onPressed: () => _showCreatePlanDialog(context),
      ),
    );
  }

  Widget _buildPlanList(BuildContext context, List<AllocationPlan> plans) {
    if (plans.isEmpty) {
      return const Center(child: Text('暂无方案，点击右下角 “新建方案”'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: plans.length,
      itemBuilder: (context, i) {
        final p = plans[i];
        return Card(
          child: ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.isActive ? '当前启用' : '未启用'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                final service = ref.read(allocationServiceProvider);
                if (v == 'rename') {
                  _showRenamePlanDialog(context, p);
                } else if (v == 'delete') {
                  _confirmDeletePlan(context, p);
                }
              },
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _PlanDetailPage(plan: p, accountId: widget.accountId),
            )),
          ),
        );
      },
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建配置方案'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '方案名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final service = ref.read(allocationServiceProvider);
              await service.createPlan(name: name);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showRenamePlanDialog(BuildContext context, AllocationPlan p) {
    final controller = TextEditingController(text: p.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名方案'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await ref.read(allocationServiceProvider).renamePlan(planId: p.id, name: name);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlan(BuildContext context, AllocationPlan p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除方案'),
        content: Text('确认删除 “${p.name}”？该操作会删除其名下的所有条目。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await ref.read(allocationServiceProvider).deletePlan(p.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _PlanDetailPage extends ConsumerWidget {
  final AllocationPlan plan;
  final int? accountId;
  const _PlanDetailPage({required this.plan, this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allocationItemsProvider(plan.id));
    return Scaffold(
      appBar: AppBar(title: Text('方案：${plan.name}')),
      body: itemsAsync.when(
        data: (items) => _buildBody(context, ref, items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增条目'),
        onPressed: () => _showAddItemDialog(context, ref),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<AllocationPlanItem> items) {
    final totalTarget = items.fold<double>(0, (p, it) => p + it.targetPercent);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: const Text('目标权重合计'),
            subtitle:
                Text('建议 = 100%（当前：${_percentFormatter.format(totalTarget)}）'),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((it) => _ItemTile(item: it, accountId: accountId)),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '0.0');
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增条目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称（如：美股、A股、黄金、固收）')),
            TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: '目标权重 (0~1)')),
            TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: '标签/规则（可选）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final label = nameCtrl.text.trim();
              final w = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
              final tag = tagCtrl.text.trim();
              if (label.isEmpty) return;
              await ref.read(allocationServiceProvider).upsertItem(
                    planId: plan.id,
                    label: label,
                    targetPercent: w.clamp(0.0, 1.0),
                    includeRule: tag.isEmpty ? null : tag,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final AllocationPlanItem item;
  final int? accountId;
  const _ItemTile({required this.item, this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_planBucketStatsProvider(item.planId));
    final metricsMap = statsAsync.asData?.value;
    final metrics = metricsMap?[item.id];
    final asyncError = statsAsync.asError;
    final isLoading = statsAsync.isLoading;

    Widget statsSection;
    if (metrics != null) {
      final actualPercent = metrics.currentPercent;
      final targetPercent = item.targetPercent;
      final deviation = actualPercent - targetPercent;
      final bucketValue = metrics.bucketValue;
      final planTotal = metrics.planTotal;
      final deviationColor = deviation.abs() < 0.0005
          ? Theme.of(context).textTheme.bodyMedium?.color
          : (deviation >= 0 ? Colors.teal : Colors.redAccent);

      statsSection = ListTile(
        title: Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: '时间占比：'),
              TextSpan(
                text: _percentFormatter.format(actualPercent),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '  •  目标占比：'),
              TextSpan(
                text: _percentFormatter.format(targetPercent),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '  •  偏离：'),
              TextSpan(
                text: _percentFormatter.format(deviation),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: deviationColor,
                ),
              ),
            ],
          ),
        ),
        subtitle: Text(
          '估算市值：${_currencyFormatter.format(bucketValue)}  •  方案总市值：${_currencyFormatter.format(planTotal)}',
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      );
    } else if (isLoading) {
      statsSection = const ListTile(
        title: Text('正在计算占比...'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (asyncError != null) {
      statsSection = ListTile(
        title: const Text('占比计算失败', style: TextStyle(color: Colors.red)),
        subtitle: Text('${asyncError.error}'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(_planBucketStatsProvider(item.planId)),
        ),
      );
    } else {
      statsSection = ListTile(
        title: Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: '时间占比：'),
              TextSpan(
                text: _percentFormatter.format(0),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '  •  目标占比：'),
              TextSpan(
                text: _percentFormatter.format(item.targetPercent),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '  •  偏离：'),
              TextSpan(
                text: _percentFormatter
                    .format(0 - item.targetPercent),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
        subtitle: Text(
          '估算市值：${_currencyFormatter.format(0)}  •  方案总市值：${_currencyFormatter.format(0)}',
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '目标：${_percentFormatter.format(item.targetPercent)}  •  标签：${(item.includeRule ?? '').isEmpty ? '无' : item.includeRule}',
        ),
        children: [
          ButtonBar(
            alignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
                onPressed: () => _showEditItemDialog(context, ref, item),
              ),
              TextButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('映射资产'),
                onPressed: () => _showLinkAssetDialog(context, ref, item),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('删除', style: TextStyle(color: Colors.red)),
                onPressed: () => _confirmDeleteItem(context, ref, item),
              ),
            ],
          ),
          const Divider(height: 1),
          statsSection,
        ],
      ),
    );
  }

  void _showEditItemDialog(BuildContext context, WidgetRef ref, AllocationPlanItem it) {
    final nameCtrl = TextEditingController(text: it.label);
    final weightCtrl = TextEditingController(text: it.targetPercent.toString());
    final tagCtrl = TextEditingController(text: it.includeRule ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑条目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: '目标权重 (0~1)')),
            TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: '标签/规则')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final label = nameCtrl.text.trim();
              final w = double.tryParse(weightCtrl.text.trim()) ?? it.targetPercent;
              final tag = tagCtrl.text.trim();
              await ref.read(allocationServiceProvider).upsertItem(
                    planId: it.planId,
                    label: label,
                    targetPercent: w.clamp(0.0, 1.0),
                    includeRule: tag.isEmpty ? null : tag,
                    sortOrder: it.sortOrder,
                    note: it.note,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLinkAssetDialog(BuildContext context, WidgetRef ref, AllocationPlanItem it) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AssetMappingPage(item: it),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, WidgetRef ref, AllocationPlanItem it) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确认删除 “${it.label}”？将删除其资产映射。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await ref.read(allocationServiceProvider).deleteItem(it.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AssetMappingPage extends ConsumerStatefulWidget {
  final AllocationPlanItem item;
  const _AssetMappingPage({required this.item});

  @override
  ConsumerState<_AssetMappingPage> createState() => _AssetMappingPageState();
}

class _AssetMappingPageState extends ConsumerState<_AssetMappingPage> {
  late final TextEditingController _searchController;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(_activeAssetsProvider);
    final mappingsAsync = ref.watch(_planMappingsProvider(widget.item.planId));
    final planItemsAsync = ref.watch(allocationItemsProvider(widget.item.planId));

    return Scaffold(
      appBar: AppBar(title: Text('映射资产：${widget.item.label}')),
      body: assetsAsync.when(
        data: (assets) => mappingsAsync.when(
          data: (mappings) => planItemsAsync.when(
            data: (planItems) => _buildContent(context, assets, mappings, planItems),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('加载方案条目失败: $err')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('加载资产映射失败: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载资产失败: $err')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Asset> assets,
    List<AssetBucketMap> mappings,
    List<AllocationPlanItem> planItems,
  ) {
    final keyword = _keyword.trim().toLowerCase();
    final filtered = keyword.isEmpty
        ? [...assets]
        : assets
            .where((asset) {
              final name = asset.name.toLowerCase();
              final code = asset.code.toLowerCase();
              return name.contains(keyword) || code.contains(keyword);
            })
            .toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selected = <({Asset asset, AssetBucketMap mapping})>[];
    final unassigned = <Asset>[];
    int mappedElsewhereCount = 0;

    for (final asset in filtered) {
      final mapping = _findMappingForAsset(mappings, asset);
      if (mapping?.bucketId == widget.item.id) {
        selected.add((asset: asset, mapping: mapping!));
      } else if (mapping == null) {
        unassigned.add(asset);
      } else {
        mappedElsewhereCount++;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: '搜索资产（名称/代码）',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _keyword = '');
                      },
                    ),
            ),
            onChanged: (value) => setState(() => _keyword = value.trim()),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildSectionTitle('已映射至 ${widget.item.label}', selected.length),
              if (selected.isEmpty)
                _buildEmptyCard('当前资产桶尚未映射任何资产')
              else
                ...selected.map(
                  (entry) => _buildSelectedAssetCard(
                    context,
                    entry.asset,
                    entry.mapping,
                  ),
                ),
              const SizedBox(height: 16),
              _buildSectionTitle('未分配资产', unassigned.length),
              if (unassigned.isEmpty)
                _buildEmptyCard('没有符合条件的未分配资产')
              else
                ...unassigned.map(
                  (asset) => _buildUnassignedAssetCard(context, asset),
                ),
              if (mappedElsewhereCount > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      '有 $mappedElsewhereCount 个资产已映射到其他资产桶，'
                      '可前往对应资产桶或移除后再进行调整。',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '$title（$count）',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAssetCard(
    BuildContext context,
    Asset asset,
    AssetBucketMap mapping,
  ) {
    final subtitle = <String>[];
    if (asset.code.isNotEmpty) {
      subtitle.add('代码：${asset.code}');
    }
    subtitle.add('跟踪方式：${_trackingMethodLabel(asset)}');
    if ((mapping.note ?? '').isNotEmpty) {
      subtitle.add('备注：${mapping.note}');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(_initial(asset.name))),
        title: Text(asset.name),
        subtitle:
            subtitle.isEmpty ? null : Text(subtitle.join('  •  ')),
        trailing: TextButton.icon(
          icon: const Icon(Icons.link_off),
          label: const Text('移除'),
          onPressed: () => _handleToggle(context, asset, false),
        ),
      ),
    );
  }

  Widget _buildUnassignedAssetCard(BuildContext context, Asset asset) {
    final subtitleParts = <String>[];
    if (asset.code.isNotEmpty) {
      subtitleParts.add('代码：${asset.code}');
    }
    subtitleParts.add('跟踪方式：${_trackingMethodLabel(asset)}');
    final subtitle =
        subtitleParts.isEmpty ? null : subtitleParts.join('  •  ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(_initial(asset.name))),
        title: Text(asset.name),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: FilledButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('映射'),
          onPressed: () => _handleToggle(context, asset, true),
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  String _trackingMethodLabel(Asset asset) {
    switch (asset.trackingMethod) {
      case AssetTrackingMethod.valueBased:
        return '价值法';
      case AssetTrackingMethod.shareBased:
        return '份额法';
    }
  }

  AssetBucketMap? _findMappingForAsset(
    List<AssetBucketMap> mappings,
    Asset asset,
  ) {
    final supa = asset.supabaseId?.toLowerCase();
    if (supa != null && supa.isNotEmpty) {
      for (final mapping in mappings) {
        final mappedSupabase = mapping.assetSupabaseId?.toLowerCase();
        if (mappedSupabase != null && mappedSupabase == supa) {
          return mapping;
        }
      }
    }

    for (final mapping in mappings) {
      if (mapping.assetId == asset.id) {
        return mapping;
      }
    }
    return null;
  }

  Future<void> _handleToggle(
    BuildContext context,
    Asset asset,
    bool selected,
  ) async {
    final svc = ref.read(allocationServiceProvider);
    try {
      if (selected) {
        await svc.assignAssetToPlanBucket(
          planId: widget.item.planId,
          bucketId: widget.item.id,
          asset: asset,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已映射 ${asset.name} 至 ${widget.item.label}')),
          );
        }
      } else {
        await svc.removeAssetFromPlanBucket(
          planId: widget.item.planId,
          bucketId: widget.item.id,
          asset: asset,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已取消映射 ${asset.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }
}

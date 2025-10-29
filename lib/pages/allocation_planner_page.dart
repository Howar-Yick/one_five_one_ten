// File: lib/pages/allocation_planner_page.dart
// Minimal UI skeleton aligned with AllocationPlan / AllocationPlanItem models.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:one_five_one_ten/models/allocation_plan.dart';
import 'package:one_five_one_ten/models/allocation_plan_item.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/asset_bucket_map.dart';
import 'package:one_five_one_ten/providers/allocation_providers.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/allocation_service.dart';

final _activeAssetsProvider =
    StreamProvider.autoDispose<List<Asset>>((ref) {
  final isar = ref.watch(databaseServiceProvider).isar;
  return isar.assets
      .where()
      .filter()
      .isArchivedEqualTo(false)
      .watch(fireImmediately: true)
      .map((assets) {
    final list = [...assets];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

class AllocationPlannerPage extends ConsumerStatefulWidget {
  final int? accountId; // 可选：用于查看某账户的实际分布
  const AllocationPlannerPage({super.key, this.accountId});

  @override
  ConsumerState<AllocationPlannerPage> createState() => _AllocationPlannerPageState();
}

class _AllocationPlannerPageState extends ConsumerState<AllocationPlannerPage> {
  final _percent = NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 1;

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
            subtitle: Text('建议 = 100%（当前：${(totalTarget * 100).toStringAsFixed(1)}%）'),
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
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('目标：${(item.targetPercent * 100).toStringAsFixed(1)}%  •  标签：${(item.includeRule ?? '').isEmpty ? '无' : item.includeRule}'),
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
          const ListTile(
            title: Text('实际占比：—  •  目标占比：—  •  偏离：—'),
            subtitle: Text('（下一步加入实时对比与建议调仓）'),
          ),
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

    final bucketLabels = {
      for (final item in planItems) item.id: item.label,
    };

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
          child: filtered.isEmpty
              ? const Center(child: Text('没有符合条件的资产'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final asset = filtered[index];
                    final mapping = _findMappingForAsset(mappings, asset);
                    final isSelected = mapping?.bucketId == widget.item.id;
                    final mappedElsewhere =
                        mapping != null && mapping.bucketId != widget.item.id;
                    final mappedLabel =
                        mapping != null ? bucketLabels[mapping.bucketId] : null;

                    final subtitleParts = <String>[];
                    if (asset.code.isNotEmpty) {
                      subtitleParts.add('代码：${asset.code}');
                    }
                    if (mappedElsewhere && mappedLabel != null) {
                      subtitleParts.add('当前映射：$mappedLabel');
                    }
                    if (mapping?.note != null && mapping!.note!.isNotEmpty) {
                      subtitleParts.add('备注：${mapping.note}');
                    }

                    return CheckboxListTile(
                      value: isSelected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(asset.name),
                      subtitle: subtitleParts.isEmpty
                          ? null
                          : Text(subtitleParts.join('  •  ')),
                      onChanged: (selected) async {
                        if (selected == null) return;
                        await _handleToggle(context, asset, selected);
                      },
                    );
                  },
                ),
        ),
      ],
    );
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

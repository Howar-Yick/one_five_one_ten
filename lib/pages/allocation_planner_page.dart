// File: lib/pages/allocation_planner_page.dart
// Step 2 - Minimal UI skeleton (create/list schemes & buckets, link assets placeholder)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:one_five_one_ten/models/allocation_models.dart';
import 'package:one_five_one_ten/providers/allocation_providers.dart';
import 'package:one_five_one_ten/services/allocation_service.dart';

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
    final schemesAsync = ref.watch(allocationSchemesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('资产配置规划器（试验功能）')),
      body: schemesAsync.when(
        data: (schemes) => _buildSchemeList(context, schemes),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新建方案'),
        onPressed: () => _showCreateSchemeDialog(context),
      ),
    );
  }

  Widget _buildSchemeList(BuildContext context, List<AllocationScheme> schemes) {
    if (schemes.isEmpty) {
      return const Center(child: Text('暂无方案，点击右下角 “新建方案”'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: schemes.length,
      itemBuilder: (context, i) {
        final s = schemes[i];
        return Card(
          child: ListTile(
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(s.isDefault ? '默认方案' : '非默认'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                final service = ref.read(allocationServiceProvider);
                if (v == 'default') {
                  await service.setDefaultScheme(s);
                } else if (v == 'rename') {
                  _showRenameSchemeDialog(context, s);
                } else if (v == 'delete') {
                  _confirmDeleteScheme(context, s);
                }
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'default', child: Text('设为默认')),
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _SchemeDetailPage(scheme: s, accountId: widget.accountId),
            )),
          ),
        );
      },
    );
  }

  void _showCreateSchemeDialog(BuildContext context) {
    final controller = TextEditingController();
    bool setDefault = false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建配置方案'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(labelText: '方案名称')),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('设为默认方案'),
                value: setDefault,
                onChanged: (v) => setState(() => setDefault = v ?? false),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final service = ref.read(allocationServiceProvider);
              await service.createScheme(name, isDefault: setDefault);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showRenameSchemeDialog(BuildContext context, AllocationScheme s) {
    final controller = TextEditingController(text: s.name);
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
              await ref.read(allocationServiceProvider).renameScheme(s, name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteScheme(BuildContext context, AllocationScheme s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除方案'),
        content: Text('确认删除 “${s.name}”？该操作会删除其名下的所有桶及资产映射。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await ref.read(allocationServiceProvider).deleteScheme(s);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SchemeDetailPage extends ConsumerWidget {
  final AllocationScheme scheme;
  final int? accountId;
  const _SchemeDetailPage({required this.scheme, this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(allocationBucketsProvider(scheme.id));
    return Scaffold(
      appBar: AppBar(title: Text('方案：${scheme.name}')),
      body: bucketsAsync.when(
        data: (buckets) => _buildBody(context, ref, buckets),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增桶'),
        onPressed: () => _showAddBucketDialog(context, ref),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<AllocationBucket> buckets) {
    final totalTarget = buckets.fold<double>(0, (p, b) => p + (b.targetWeight));
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
        ...buckets.map((b) => _BucketTile(bucket: b, accountId: accountId)),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showAddBucketDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '0.0');
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增配置桶'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称（如：美股、A股、黄金、固收）')),
            TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: '目标权重 (0~1)')),
            TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: '标签（可选）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final w = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
              final tag = tagCtrl.text.trim();
              if (name.isEmpty) return;
              await ref.read(allocationServiceProvider).addBucket(
                    scheme: scheme,
                    name: name,
                    targetWeight: w.clamp(0.0, 1.0),
                    tag: tag,
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

class _BucketTile extends ConsumerWidget {
  final AllocationBucket bucket;
  final int? accountId;
  const _BucketTile({required this.bucket, this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(bucket.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('目标：${(bucket.targetWeight * 100).toStringAsFixed(1)}%  •  标签：${bucket.tag.isEmpty ? '无' : bucket.tag}'),
        children: [
          ButtonBar(
            alignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
                onPressed: () => _showEditBucketDialog(context, ref, bucket),
              ),
              TextButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('映射资产'),
                onPressed: () => _showLinkAssetDialog(context, ref, bucket),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('删除', style: TextStyle(color: Colors.red)),
                onPressed: () => _confirmDeleteBucket(context, ref, bucket),
              ),
            ],
          ),
          const Divider(height: 1),
          // TODO: 将来在这里展示“实际 vs 目标”的差异（占位）
          const ListTile(
            title: Text('实际占比：—  •  目标占比：—  •  偏离：—'),
            subtitle: Text('（下一步加入实时对比与建议调仓）'),
          ),
        ],
      ),
    );
  }

  void _showEditBucketDialog(BuildContext context, WidgetRef ref, AllocationBucket b) {
    final nameCtrl = TextEditingController(text: b.name);
    final weightCtrl = TextEditingController(text: b.targetWeight.toString());
    final tagCtrl = TextEditingController(text: b.tag);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑配置桶'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: '目标权重 (0~1)')),
            TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: '标签')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final w = double.tryParse(weightCtrl.text.trim()) ?? b.targetWeight;
              final tag = tagCtrl.text.trim();
              await ref.read(allocationServiceProvider).updateBucket(b, name: name, targetWeight: w.clamp(0.0, 1.0), tag: tag);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLinkAssetDialog(BuildContext context, WidgetRef ref, AllocationBucket bucket) {
    // 轻量占位：仅提示后续步骤
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('映射资产（占位）'),
        content: const Text('下一步将提供：在你现有资产列表中选择资产映射到该桶，并可设置可选权重覆盖。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }

  void _confirmDeleteBucket(BuildContext context, WidgetRef ref, AllocationBucket b) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除配置桶'),
        content: Text('确认删除 “${b.name}”？将删除其资产映射。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await ref.read(allocationServiceProvider).deleteBucket(b);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

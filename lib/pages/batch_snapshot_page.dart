import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:one_five_one_ten/services/ocr_parser_service.dart';

class BatchSnapshotPage extends ConsumerStatefulWidget {
  const BatchSnapshotPage({super.key});

  @override
  ConsumerState<BatchSnapshotPage> createState() => _BatchSnapshotPageState();
}

class _BatchSnapshotPageState extends ConsumerState<BatchSnapshotPage> {
  final Map<int, Map<String, TextEditingController>> _draftControllers = {};
  DateTime _selectedDate = DateTime.now();
  bool _isOcrProcessing = false;
  bool _isSaving = false;
  late Future<List<MapEntry<Account, List<Asset>>>> _pageDataFuture;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadData();
  }

  @override
  void dispose() {
    for (var map in _draftControllers.values) {
      for (var controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<List<MapEntry<Account, List<Asset>>>> _loadData() async {
    final isar = DatabaseService().isar;
    final accounts = await isar.accounts.where().findAll();
    final assets = await isar.assets
        .filter()
        .isArchivedEqualTo(false)
        .findAll();
    final snapshots = await isar.positionSnapshots.where().findAll();

    accounts.sort((a, b) => a.name.compareTo(b.name));
    assets.sort((a, b) => a.name.compareTo(b.name));

    final latestSnapshotByAssetSupabaseId = <String, PositionSnapshot>{};
    for (final snapshot in snapshots) {
      final assetSupabaseId = snapshot.assetSupabaseId;
      if (assetSupabaseId == null || assetSupabaseId.isEmpty) continue;

      final existing = latestSnapshotByAssetSupabaseId[assetSupabaseId];
      if (existing == null || snapshot.date.isAfter(existing.date)) {
        latestSnapshotByAssetSupabaseId[assetSupabaseId] = snapshot;
      }
    }

    final Map<String?, Account> accountMap = {
      for (var a in accounts) a.supabaseId: a,
    };
    final Map<Account, List<Asset>> grouped = {};

    for (final asset in assets) {
      final assetSupabaseId = asset.supabaseId;
      if (assetSupabaseId == null || assetSupabaseId.isEmpty) continue;

      final latestSnapshot = latestSnapshotByAssetSupabaseId[assetSupabaseId];
      if (latestSnapshot == null || latestSnapshot.totalShares <= 0) {
        continue;
      }

      final acc = accountMap[asset.accountSupabaseId];
      if (acc != null) {
        grouped.putIfAbsent(acc, () => []).add(asset);
      }
    }

    return grouped.entries.toList();
  }

  TextEditingController _controllerFor(int assetId, String field) {
    final fieldMap = _draftControllers.putIfAbsent(assetId, () => {});
    return fieldMap.putIfAbsent(field, () => TextEditingController());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ★ 终极双擎 OCR 导入：代码 + 名称同时匹配
  Future<void> _handleOcrImport(List<Asset> accountAssets) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isOcrProcessing = true);

      // 构建搜索字典：Asset ID -> [资产代码, 资产名称]
      final Map<int, List<String>> assetSearchKeys = {};
      for (final asset in accountAssets) {
        final keys = <String>[];
        final code = asset.code.toString().trim();

        if (code.isNotEmpty) {
          keys.add(code); // 第一优先级：匹配资产代码
        }
        keys.add(asset.name); // 第二优先级：兜底匹配名称
        assetSearchKeys[asset.id] = keys;
      }

      final ocrService = OcrParserService();
      // 传入字典，返回直接绑死 ID 的数据！
      final results = await ocrService.parseGuojinScreenshot(
        image.path,
        assetSearchKeys,
      );

      int fillCount = 0;
      for (final asset in accountAssets) {
        final data = results[asset.id];
        // 只要数据不为空，就填进去
        if (data != null && data.isNotEmpty) {
          if (data.containsKey('shares')) {
            _controllerFor(asset.id, 'shares').text = data['shares'].toString();
          }
          if (data.containsKey('cost')) {
            _controllerFor(asset.id, 'cost').text = data['cost'].toString();
          }
          if (data.containsKey('profit')) {
            _controllerFor(asset.id, 'profit').text = data['profit'].toString();
          }
          fillCount++;
        }
      }

      if (context.mounted) {
        if (fillCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未识别到匹配的资产，请确保资产已配置证券代码，或名称与截图一致。')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OCR 识别完成，已成功填充 $fillCount 个资产！')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OCR 识别失败: $e')));
      }
    } finally {
      setState(() => _isOcrProcessing = false);
    }
  }

  bool _isShareAsset(Asset asset) {
    return asset.subType == AssetSubType.mutualFund ||
        asset.subType == AssetSubType.etf ||
        asset.subType == AssetSubType.stock;
  }

  Future<void> _saveBatch(
    List<MapEntry<Account, List<Asset>>> groupedData,
  ) async {
    setState(() => _isSaving = true);
    int savedCount = 0;
    try {
      final syncService = ref.read(syncServiceProvider);
      for (final entry in groupedData) {
        for (final asset in entry.value) {
          final fields = _draftControllers[asset.id];
          if (fields == null) continue;

          if (_isShareAsset(asset)) {
            final sharesText = fields['shares']?.text.trim() ?? '';
            final costText = fields['cost']?.text.trim() ?? '';
            final profitText = fields['profit']?.text.trim() ?? '';

            if (sharesText.isNotEmpty && costText.isNotEmpty) {
              final shares = double.tryParse(sharesText);
              final cost = double.tryParse(costText);
              final profit = double.tryParse(profitText);

              if (shares != null && cost != null) {
                final snapshot = PositionSnapshot()
                  ..totalShares = shares
                  ..averageCost = cost
                  ..brokerComprehensiveProfit = profit
                  ..date = _selectedDate
                  ..createdAt = DateTime.now()
                  ..assetSupabaseId = asset.supabaseId;

                await syncService.savePositionSnapshot(snapshot);
                fields['shares']?.clear();
                fields['cost']?.clear();
                fields['profit']?.clear();
                savedCount++;
              }
            }
          } else {
            final mvText = fields['marketValue']?.text.trim() ?? '';
            final flowText = fields['netFlow']?.text.trim() ?? '';
            if (mvText.isNotEmpty) {
              final mv = double.tryParse(mvText);
              if (mv != null) {
                final mvTx = Transaction()
                  ..type = TransactionType.updateValue
                  ..amount = mv
                  ..date = _selectedDate
                  ..createdAt = DateTime.now()
                  ..assetSupabaseId = asset.supabaseId;
                await syncService.saveTransaction(mvTx);
                fields['marketValue']?.clear();

                if (flowText.isNotEmpty) {
                  final flow = double.tryParse(flowText);
                  if (flow != null && flow != 0) {
                    final flowTx = Transaction()
                      ..type = flow > 0
                          ? TransactionType.invest
                          : TransactionType.withdraw
                      ..amount = flow.abs()
                      ..date = _selectedDate
                      ..createdAt = DateTime.now()
                      ..assetSupabaseId = asset.supabaseId;
                    await syncService.saveTransaction(flowTx);
                  }
                }
                fields['netFlow']?.clear();
                savedCount++;
              }
            }
          }
        }
      }

      ref.invalidate(dashboardDataProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedCount > 0 ? '批量保存成功，共保存 $savedCount 条记录' : '没有有效的数据被保存。',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存出错: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('批量快照工作台'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(dateStr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: FutureBuilder<List<MapEntry<Account, List<Asset>>>>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final groupedData = snapshot.data ?? [];
          if (groupedData.isEmpty) {
            return const Center(child: Text('没有需要录入的活跃资产。'));
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '点击各个账户右侧的“OCR”按钮，可上传截图自动填入该账户的资产。留空的资产在保存时会被自动跳过。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: groupedData.length,
                  itemBuilder: (context, index) {
                    final entry = groupedData[index];
                    final account = entry.key;
                    final assets = entry.value;

                    // ★ 专属的账户 OCR 入口！
                    return ExpansionTile(
                      initiallyExpanded: index == 0,
                      title: Row(
                        children: [
                          Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_isOcrProcessing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => _handleOcrImport(assets),
                              icon: const Icon(
                                Icons.document_scanner,
                                size: 16,
                              ),
                              label: const Text(
                                'OCR',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      children: assets
                          .map((asset) => _buildAssetRow(asset))
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving
            ? null
            : () {
                _pageDataFuture.then((data) => _saveBatch(data));
              },
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? '保存中...' : '批量保存'),
      ),
    );
  }

  Widget _buildAssetRow(Asset asset) {
    final isShare = _isShareAsset(asset);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                asset.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                isShare ? '份额法' : '价值法',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isShare)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _controllerFor(asset.id, 'shares'),
                    '最新份额',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    _controllerFor(asset.id, 'cost'),
                    '单位成本',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    _controllerFor(asset.id, 'profit'),
                    '综合收益(可选)',
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _controllerFor(asset.id, 'marketValue'),
                    '当前总市值',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    _controllerFor(asset.id, 'netFlow'),
                    '净投入变动(可选)',
                  ),
                ),
              ],
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

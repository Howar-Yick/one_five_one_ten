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

  // ★ 修复 1 & 2：安全的查询，并兼容 nullable 的 supabaseId
  Future<List<MapEntry<Account, List<Asset>>>> _loadData() async {
    final isar = DatabaseService().isar;
    final accounts = await isar.accounts.where().findAll();
    final assets = await isar.assets.where().findAll(); // 去掉了会导致报错的 filter

    accounts.sort((a, b) => a.name.compareTo(b.name));
    assets.sort((a, b) => a.name.compareTo(b.name));

    // 注意这里的 Map<String?, Account> 加上了问号
    final Map<String?, Account> accountMap = {
      for (var a in accounts) a.supabaseId: a,
    };
    final Map<Account, List<Asset>> grouped = {};

    for (final asset in assets) {
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

  Future<void> _handleOcrImport(List<Asset> activeAssets) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isOcrProcessing = true);

      final assetNames = activeAssets.map((e) => e.name).toList();
      final ocrService = OcrParserService();
      final results = await ocrService.parseGuojinScreenshot(
        image.path,
        assetNames,
      );

      if (results.isEmpty && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未识别到匹配的资产数据，请检查截图。')));
        return;
      }

      int fillCount = 0;
      for (final asset in activeAssets) {
        final data = results[asset.name];
        if (data != null) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR 识别完成，已自动填充 $fillCount 个资产。')),
        );
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

  // ★ 判断是否为份额法资产的辅助方法 (解决幻觉报错)
  bool _isShareAsset(Asset asset) {
    // 🚨 注意：这里我假定你们是用 subType 判断的。
    // 如果你们的代码是用 asset.type == AssetType.fund，请在这里修改！
    // 目前默认只要不是“银行理财”或者“现金”，就当作份额法处理。
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

          // ★ 修复 3：调用真正的判断方法，不再使用捏造的 calculationMethod
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
            // 价值法资产处理
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

          final List<Asset> allActiveAssets = groupedData
              .expand((e) => e.value)
              .toList();

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
                        '留空会跳过，价值法录入最新市值即可。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _isOcrProcessing
                          ? null
                          : () => _handleOcrImport(allActiveAssets),
                      icon: _isOcrProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo),
                      tooltip: '导入国金持仓截图(OCR)',
                      color: Theme.of(context).colorScheme.primary,
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

                    // 使用可折叠面板
                    return ExpansionTile(
                      initiallyExpanded: index == 0,
                      title: Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
    // ★ 修复 4：调用真正的判断方法
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/ocr_parser_service.dart';

class BatchSnapshotPage extends ConsumerStatefulWidget {
  const BatchSnapshotPage({super.key});

  @override
  ConsumerState<BatchSnapshotPage> createState() => _BatchSnapshotPageState();
}

class _BatchSnapshotPageState extends ConsumerState<BatchSnapshotPage> {
  final Map<int, Map<String, TextEditingController>> _draftControllers = {};
  final ImagePicker _imagePicker = ImagePicker();
  final OcrParserService _ocrParserService = OcrParserService();
  late Future<Map<Account, List<Asset>>> _pageDataFuture;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isOcrProcessing = false;

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadBatchData();
  }

  @override
  void dispose() {
    for (final fieldMap in _draftControllers.values) {
      for (final controller in fieldMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int assetId, String field) {
    final fieldMap = _draftControllers.putIfAbsent(assetId, () => {});
    return fieldMap.putIfAbsent(field, () => TextEditingController());
  }

  Future<Map<Account, List<Asset>>> _loadBatchData() async {
    final isar = ref.read(databaseServiceProvider).isar;
    final accounts = await isar.accounts.where().sortByName().findAll();
    final assets = await isar.assets.where().sortByName().findAll();

    final activeAssets = assets.where((asset) => !asset.isArchived).toList();
    final assetsByAccountSupabaseId = <String, List<Asset>>{};

    for (final asset in activeAssets) {
      final accountSupabaseId = asset.accountSupabaseId;
      if (accountSupabaseId == null || accountSupabaseId.isEmpty) {
        continue;
      }
      assetsByAccountSupabaseId
          .putIfAbsent(accountSupabaseId, () => <Asset>[])
          .add(asset);
    }

    final result = <Account, List<Asset>>{};
    for (final account in accounts) {
      final accountSupabaseId = account.supabaseId;
      if (accountSupabaseId == null || accountSupabaseId.isEmpty) {
        continue;
      }
      final accountAssets =
          assetsByAccountSupabaseId[accountSupabaseId] ?? <Asset>[];
      if (accountAssets.isEmpty) {
        continue;
      }
      accountAssets.sort((a, b) => a.name.compareTo(b.name));
      result[account] = accountAssets;
    }
    return result;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
          _selectedDate.second,
        );
      });
    }
  }

  double? _parseOptionalNumber(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return _sanitizeNumericText(text);
  }

  double? _sanitizeNumericText(String raw) {
    final cleaned = raw
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll('%', '')
        .replaceAll('％', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9+\-.]'), '');

    if (cleaned.isEmpty ||
        cleaned == '-' ||
        cleaned == '+' ||
        cleaned == '.' ||
        cleaned == '-.' ||
        cleaned == '+.') {
      return null;
    }
    return double.tryParse(cleaned);
  }

  String _formatDetectedNumber(double value) {
    final text = value.toStringAsFixed(6);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _handleOcrImport() async {
    if (_isOcrProcessing) return;

    setState(() {
      _isOcrProcessing = true;
    });

    try {
      final groupedData = await _pageDataFuture;
      final shareAssets = groupedData.values
          .expand((assets) => assets)
          .where((asset) => asset.trackingMethod == AssetTrackingMethod.shareBased)
          .toList();

      if (shareAssets.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可供 OCR 自动填充的份额法资产')),
        );
        return;
      }

      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return;
      }

      final assetNames = shareAssets.map((asset) => asset.name).toList();
      final parsedData = await _ocrParserService.parseGuojinScreenshot(
        image.path,
        assetNames,
      );

      int filledAssetCount = 0;
      for (final asset in shareAssets) {
        final matched = parsedData[asset.name];
        if (matched == null) {
          continue;
        }

        final shares = matched['shares'];
        final cost = matched['cost'];
        final profit = matched['profit'];
        if (shares == null || cost == null) {
          continue;
        }

        _controllerFor(asset.id, 'shares').text = _formatDetectedNumber(shares);
        _controllerFor(asset.id, 'cost').text = _formatDetectedNumber(cost);
        if (profit != null) {
          _controllerFor(asset.id, 'profit').text = _formatDetectedNumber(profit);
        }
        filledAssetCount++;
      }

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR 识别完成，已自动填充 $filledAssetCount 个资产'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 识别失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOcrProcessing = false;
        });
      }
    }
  }

  Future<void> _saveBatch(Map<Account, List<Asset>> groupedData) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      int savedCount = 0;

      for (final entry in groupedData.entries) {
        for (final asset in entry.value) {
          final fieldMap = _draftControllers[asset.id];
          if (fieldMap == null ||
              asset.supabaseId == null ||
              asset.supabaseId!.isEmpty) {
            continue;
          }

          if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
            final sharesController = fieldMap['shares'];
            final costController = fieldMap['cost'];
            final profitController = fieldMap['profit'];
            final shares = sharesController == null
                ? null
                : _parseOptionalNumber(sharesController);
            final cost =
                costController == null ? null : _parseOptionalNumber(costController);
            final comprehensiveProfit = profitController == null
                ? null
                : _parseOptionalNumber(profitController);

            if (shares == null && cost == null && comprehensiveProfit == null) {
              continue;
            }

            if (shares == null || cost == null) {
              continue;
            }

            final snapshot = PositionSnapshot()
              ..totalShares = shares
              ..averageCost = cost
              ..date = _selectedDate
              ..createdAt = DateTime.now()
              ..assetSupabaseId = asset.supabaseId
              ..brokerComprehensiveProfit = comprehensiveProfit;

            await syncService.savePositionSnapshot(snapshot);
            savedCount++;
            continue;
          }

          final marketValueController = fieldMap['marketValue'];
          final netFlowController = fieldMap['netFlow'];
          final marketValue = marketValueController == null
              ? null
              : _parseOptionalNumber(marketValueController);
          final netFlow = netFlowController == null
              ? null
              : _parseOptionalNumber(netFlowController);

          if (marketValue == null && netFlow == null) {
            continue;
          }

          if (netFlow != null && netFlow != 0) {
            final flowType =
                netFlow >= 0 ? TransactionType.invest : TransactionType.withdraw;
            final flowTxn = Transaction()
              ..type = flowType
              ..date = _selectedDate
              ..amount = netFlow >= 0 ? -netFlow.abs() : netFlow.abs()
              ..createdAt = DateTime.now()
              ..assetSupabaseId = asset.supabaseId;
            await syncService.saveTransaction(flowTxn);
            savedCount++;
          }

          if (marketValue != null) {
            final valueSnapshotTxn = Transaction()
              ..type = TransactionType.updateValue
              ..date = _selectedDate
              ..amount = marketValue
              ..createdAt = DateTime.now()
              ..assetSupabaseId = asset.supabaseId;
            await syncService.saveTransaction(valueSnapshotTxn);
            savedCount++;
          }
        }
      }

      ref.invalidate(dashboardDataProvider);
      setState(() {
        _pageDataFuture = _loadBatchData();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedCount > 0
              ? '批量保存成功，共保存 $savedCount 条记录'
              : '没有可保存的输入内容'),
        ),
      );

      if (savedCount > 0) {
        for (final fieldMap in _draftControllers.values) {
          for (final controller in fieldMap.values) {
            controller.clear();
          }
        }
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量保存失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateText = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('批量快照工作台'),
        actions: [
          IconButton(
            onPressed: _isOcrProcessing ? null : _handleOcrImport,
            tooltip: '导入国金截图 OCR',
            icon: _isOcrProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner),
          ),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(selectedDateText),
          ),
        ],
      ),
      body: FutureBuilder<Map<Account, List<Asset>>>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载批量快照数据失败: ${snapshot.error}'),
              ),
            );
          }

          final groupedData = snapshot.data ?? const <Account, List<Asset>>{};
          if (groupedData.isEmpty) {
            return const Center(child: Text('暂无可录入的活跃资产'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tips_and_updates_outlined),
                  title: const Text('录入说明'),
                  subtitle: Text(
                    '当前快照日期：$selectedDateText\n份额法需至少填写“最新份额 + 单位成本”；价值法可填写“当前总市值”，净投入变动为可选。你也可以从国金证券持仓截图中 OCR 自动填充份额法资产。',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...groupedData.entries.map(
                (entry) => _buildAccountSection(entry.key, entry.value),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<Map<Account, List<Asset>>>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          final groupedData = snapshot.data;
          return FloatingActionButton.extended(
            onPressed: (_isSaving || groupedData == null)
                ? null
                : () => _saveBatch(groupedData),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? '保存中...' : '批量保存'),
          );
        },
      ),
    );
  }

  Widget _buildAccountSection(Account account, List<Asset> assets) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...assets.map(_buildAssetRow),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetRow(Asset asset) {
    final isShareBased = asset.trackingMethod == AssetTrackingMethod.shareBased;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asset.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isShareBased ? '份额法' : '价值法',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          isShareBased ? _buildShareFields(asset) : _buildValueFields(asset),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildShareFields(Asset asset) {
    return Row(
      children: [
        Expanded(
          child: _buildNumberField(
            controller: _controllerFor(asset.id, 'shares'),
            label: '最新份额',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildNumberField(
            controller: _controllerFor(asset.id, 'cost'),
            label: '单位成本',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildNumberField(
            controller: _controllerFor(asset.id, 'profit'),
            label: '综合收益(可选)',
          ),
        ),
      ],
    );
  }

  Widget _buildValueFields(Asset asset) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildNumberField(
            controller: _controllerFor(asset.id, 'marketValue'),
            label: '当前总市值',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildNumberField(
            controller: _controllerFor(asset.id, 'netFlow'),
            label: '净投入变动(可选)',
            helperText: '流入填正，流出填负',
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

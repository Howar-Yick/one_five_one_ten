import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/pages/account_detail_page.dart';
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';

class AddEditAssetPage extends ConsumerStatefulWidget {
  final int accountId;
  final int? assetId;

  const AddEditAssetPage({super.key, required this.accountId, this.assetId});

  @override
  ConsumerState<AddEditAssetPage> createState() => _AddEditAssetPageState();
}

class _AddEditAssetPageState extends ConsumerState<AddEditAssetPage> {
  AssetTrackingMethod _selectedMethod = AssetTrackingMethod.shareBased;
  AssetSubType _selectedSubType = AssetSubType.stock;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _sharesController = TextEditingController();
  final _costController = TextEditingController();
  final _initialInvestmentController = TextEditingController();
  final _latestPriceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  Asset? _editingAsset;
  bool _isLoading = true;

  bool get _isEditing => widget.assetId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadAssetData();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadAssetData() async {
    final isar = DatabaseService().isar;
    final asset = await isar.assets.get(widget.assetId!);
    if (asset != null) {
      setState(() {
        _editingAsset = asset;
        _nameController.text = asset.name;
        _codeController.text = asset.code;
        _selectedMethod = asset.trackingMethod;
        _selectedSubType = asset.subType;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _sharesController.dispose();
    _costController.dispose();
    _initialInvestmentController.dispose();
    _latestPriceController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final isar = DatabaseService().isar;

    if (_isEditing) {
      final assetToUpdate = _editingAsset!;
      assetToUpdate.name = _nameController.text.trim();
      assetToUpdate.code = _codeController.text.trim();
      assetToUpdate.subType = _selectedSubType;
      
      await isar.writeTxn(() async {
        await isar.assets.put(assetToUpdate);
      });
      
      ref.invalidate(trackedAssetsProvider(widget.accountId));
      if(assetToUpdate.trackingMethod == AssetTrackingMethod.shareBased) {
        ref.invalidate(shareAssetDetailProvider(assetToUpdate.id));
      } else {
        ref.invalidate(valueAssetDetailProvider(assetToUpdate.id));
      }
    } else {
      final parentAccount = await isar.accounts.get(widget.accountId);
      if (parentAccount == null) return;

      final newAsset = Asset()
        ..name = _nameController.text.trim()
        ..trackingMethod = _selectedMethod
        ..subType = _selectedSubType
        ..account.value = parentAccount;

      final priceText = _latestPriceController.text.trim();
      if (priceText.isNotEmpty) {
        newAsset.latestPrice = double.tryParse(priceText) ?? 0.0;
        newAsset.priceUpdateDate = DateTime.now();
      }

      if (_selectedMethod == AssetTrackingMethod.shareBased) {
        newAsset.code = _codeController.text.trim();
        final snapshot = PositionSnapshot()
          ..totalShares = double.parse(_sharesController.text)
          ..averageCost = double.parse(_costController.text)
          ..date = _selectedDate
          ..asset.value = newAsset;

        await isar.writeTxn(() async {
          await isar.assets.put(newAsset);
          await isar.positionSnapshots.put(snapshot);
          await newAsset.account.save();
          await snapshot.asset.save();
        });
      } else {
        final initialInvestment = double.parse(_initialInvestmentController.text);
        final transaction = Transaction()
          ..type = TransactionType.invest
          ..amount = initialInvestment
          ..date = _selectedDate
          ..asset.value = newAsset;
        
        final updateValueTxn = Transaction()
          ..type = TransactionType.updateValue
          ..amount = initialInvestment
          ..date = _selectedDate
          ..asset.value = newAsset;

        await isar.writeTxn(() async {
          await isar.assets.put(newAsset);
          await isar.transactions.putAll([transaction, updateValueTxn]);
          await newAsset.account.save();
          await transaction.asset.save();
          await updateValueTxn.asset.save();
        });
      }
      
      ref.invalidate(trackedAssetsProvider(widget.accountId));
    }
    
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑持仓资产' : '添加持仓资产'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _saveAsset,
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (!_isEditing)
              SegmentedButton<AssetTrackingMethod>(
                segments: const [
                  ButtonSegment(value: AssetTrackingMethod.shareBased, label: Text('份额法'), icon: Icon(Icons.pie_chart)),
                  ButtonSegment(value: AssetTrackingMethod.valueBased, label: Text('价值法'), icon: Icon(Icons.account_balance_wallet)),
                ],
                selected: {_selectedMethod},
                onSelectionChanged: (newSelection) {
                  setState(() { _selectedMethod = newSelection.first; });
                },
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '资产名称', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.isEmpty) ? '请输入资产名称' : null,
            ),
            const SizedBox(height: 16),
            
            if (_selectedMethod == AssetTrackingMethod.shareBased)
              ..._buildShareBasedForm()
            else
              ..._buildValueBasedForm(),
            
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('初始记录日期'),
                trailing: TextButton(
                  child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() { _selectedDate = pickedDate; });
                    }
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  List<Widget> _buildShareBasedForm() {
    return [
      const Text('资产类型', style: TextStyle(fontSize: 16, color: Colors.grey)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8.0,
        children: [
          ChoiceChip(
            label: const Text('股票'),
            selected: _selectedSubType == AssetSubType.stock,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSubType = AssetSubType.stock);
            },
          ),
          ChoiceChip(
            label: const Text('场内基金(ETF)'),
            selected: _selectedSubType == AssetSubType.etf,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSubType = AssetSubType.etf);
            },
          ),
          ChoiceChip(
            label: const Text('场外基金'),
            selected: _selectedSubType == AssetSubType.mutualFund,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSubType = AssetSubType.mutualFund);
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _codeController,
        decoration: const InputDecoration(labelText: '资产代码', hintText: '例如: 600519', border: OutlineInputBorder()),
      ),
      if (!_isEditing) ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _sharesController,
          decoration: const InputDecoration(labelText: '总份额', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? '请输入有效的数字' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _costController,
          decoration: const InputDecoration(labelText: '单位成本', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? '请输入有效的数字' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _latestPriceController,
          decoration: const InputDecoration(labelText: '最新价格 (可选)', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ]
    ];
  }

  List<Widget> _buildValueBasedForm() {
    // 价值法资产，我们默认给它一个 "other" 子类型
    if (!_isEditing) _selectedSubType = AssetSubType.other;
    return [
      if (!_isEditing)
        TextFormField(
          controller: _initialInvestmentController,
          decoration: const InputDecoration(labelText: '初始投入金额', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? '请输入有效的数字' : null,
        ),
    ];
  }
}
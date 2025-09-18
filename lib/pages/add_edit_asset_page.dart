// 文件: lib/pages/add_edit_asset_page.dart
// (这是完整、已修复的文件代码)

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
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:isar/isar.dart'; // (*** 确保 Isar 已导入 ***)


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
  
  String _selectedCurrency = 'CNY'; 
  Account? _parentAccount; 
  Asset? _editingAsset;
  bool _isLoading = true; 

  bool get _isEditing => widget.assetId != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final isar = DatabaseService().isar; 
    _parentAccount = await isar.accounts.get(widget.accountId);

    if (_isEditing) {
      _editingAsset = await isar.assets.get(widget.assetId!);
      if (_editingAsset != null) {
        _nameController.text = _editingAsset!.name;
        _codeController.text = _editingAsset!.code;
        _selectedMethod = _editingAsset!.trackingMethod;
        _selectedSubType = _editingAsset!.subType;
        _selectedCurrency = _editingAsset!.currency;
      }
    } else {
      _selectedCurrency = _parentAccount?.currency ?? 'CNY';
    }

    if (!['CNY', 'USD', 'HKD'].contains(_selectedCurrency)) {
      _selectedCurrency = 'CNY';
    }

    if (mounted) {
      setState(() {
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

  // (*** 这是修复后的 _saveAsset 函数 ***)
  Future<void> _saveAsset() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    
    // (*** 用 try-catch 包裹整个逻辑 ***)
    try {
      final parentAccount = _parentAccount!; 
      final syncService = ref.read(syncServiceProvider); 

      // 1. 检查父账户是否已同步
      if (parentAccount.supabaseId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('错误：父账户尚未同步，请稍后重试。'))
          );
        }
        return;
      }

      final isar = DatabaseService().isar; // (*** 获取 Isar 实例 ***)

      if (_isEditing) {
        // --- 更新逻辑 ---
        final assetToUpdate = _editingAsset!;
        assetToUpdate.name = _nameController.text.trim();
        assetToUpdate.code = _codeController.text.trim();
        assetToUpdate.subType = _selectedSubType;
        assetToUpdate.currency = _selectedCurrency;
        
        // (更新逻辑直接调用 syncService 即可, 因为它已经有 Isar ID)
        await syncService.saveAsset(assetToUpdate);
        
        // 刷新相关 Provider
        ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
        if(assetToUpdate.trackingMethod == AssetTrackingMethod.shareBased) {
          ref.invalidate(shareAssetDetailProvider(assetToUpdate.id));
        } else {
          ref.invalidate(valueAssetDetailProvider(assetToUpdate.id));
        }
      } else {
        // --- 新建逻辑 (已重写) ---
        final newAsset = Asset()
          ..name = _nameController.text.trim()
          ..trackingMethod = _selectedMethod
          ..subType = _selectedSubType
          ..currency = _selectedCurrency
          ..createdAt = DateTime.now() 
          ..accountSupabaseId = parentAccount.supabaseId; 

        final priceText = _latestPriceController.text.trim();
        if (priceText.isNotEmpty) {
          newAsset.latestPrice = double.tryParse(priceText) ?? 0.0;
          newAsset.priceUpdateDate = DateTime.now();
        }

        // 10. (*** 关键修复：先在本地写入 Asset 以获取 Isar ID ***)
        await isar.writeTxn(() async {
            await isar.assets.put(newAsset);
        });
        // (newAsset.id 此时已有效)

        // 11. (*** 然后再调用同步服务 ***)
        await syncService.saveAsset(newAsset);
        // (syncService 会通过 _saveObject 更新 ID=newAsset.id 的记录)
        // (我们必须从 Isar 重新加载它以确保我们有 supabaseId)

        final syncedAsset = await isar.assets.get(newAsset.id); // 重新获取以检查 supabaseId
        
        if (syncedAsset == null || syncedAsset.supabaseId == null) {
          // 如果同步失败 (例如离线)，syncService 会打印错误，但本地占位符已创建。
          // 我们不能继续创建子记录，因为它们依赖 supabaseId
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('资产已在本地创建，但同步失败。子记录未创建。')));
           // 错误已抛出并被外层 catch 捕获
           throw Exception("Asset synced locally but failed to retrieve supabaseId.");
        } else {
          // (*** 只有在 Asset 同步成功 (获得了 supabaseId) 之后，才创建子记录 ***)

          if (_selectedMethod == AssetTrackingMethod.shareBased) {
            // --- 保存份额法子记录 ---
            final snapshot = PositionSnapshot()
              ..totalShares = double.parse(_sharesController.text)
              ..averageCost = double.parse(_costController.text)
              ..date = _selectedDate
              ..createdAt = DateTime.now()
              // 11. (关键) 使用返回的 newAsset.supabaseId 设置关系
              ..assetSupabaseId = syncedAsset.supabaseId; // (使用已同步的 ID)

            // (*** 关键修复：应用相同的逻辑：先本地写，再同步 ***)
            await isar.writeTxn(() async {
              await isar.positionSnapshots.put(snapshot);
            });
            await syncService.savePositionSnapshot(snapshot); 

          } else {
            // --- 保存价值法子记录 ---
            final initialInvestment = double.parse(_initialInvestmentController.text);
            final transaction = Transaction()
              ..type = TransactionType.invest
              ..amount = initialInvestment
              ..date = _selectedDate
              ..createdAt = DateTime.now()
              ..assetSupabaseId = syncedAsset.supabaseId; // (使用已同步的 ID)
            
            final updateValueTxn = Transaction()
              ..type = TransactionType.updateValue
              ..amount = initialInvestment
              ..date = _selectedDate
              ..createdAt = DateTime.now()
              ..assetSupabaseId = syncedAsset.supabaseId; // (使用已同步的 ID)

            // (*** 关键修复：应用相同的逻辑：先本地写，再同步 ***)
            await isar.writeTxn(() async {
              await isar.transactions.put(transaction);
              await isar.transactions.put(updateValueTxn);
            });
            await syncService.saveTransaction(transaction);
            await syncService.saveTransaction(updateValueTxn);
          }
        }
      }
      
      // 17. 刷新 Dashboard
      ref.invalidate(dashboardDataProvider); 
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      // (*** 捕获所有错误 ***)
      print('保存资产失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'))
        );
      }
    }
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
            onPressed: _isLoading ? null : _saveAsset, 
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Form(
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
                
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('资产币种:', style: TextStyle(fontSize: 16)),
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      items: ['CNY', 'USD', 'HKD'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCurrency = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
                
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
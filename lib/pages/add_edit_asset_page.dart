// 文件: lib/pages/add_edit_asset_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/services/database_service.dart';
// 确保引入这些页面，以便 invalidating Providers
import 'package:one_five_one_ten/pages/account_detail_page.dart'; 
import 'package:one_five_one_ten/pages/share_asset_detail_page.dart';
import 'package:one_five_one_ten/pages/value_asset_detail_page.dart';

// 1. (*** 新增：导入 Providers 和新服务 ***)
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';


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
  bool _isLoading = true; // 默认设置为 true

  bool get _isEditing => widget.assetId != null;

  @override
  void initState() {
    super.initState();
    // 2. (修改) 在 initState 中我们不能使用 ref，所以保持原样
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 3. (修正) 坚持使用您项目中的 DatabaseService().isar 模式，修复 isarProvider 错误
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

  // 4. (*** 关键修复：完全重写 _saveAsset 方法 ***)
  Future<void> _saveAsset() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    
    final parentAccount = _parentAccount!; 
    final syncService = ref.read(syncServiceProvider); // 5. 获取 SyncService

    // 6. 检查父账户是否已同步 (它必须有一个 supabaseId 才能创建子项)
    if (parentAccount.supabaseId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('错误：父账户尚未同步，请稍后重试。'))
        );
      }
      return;
    }

    if (_isEditing) {
      // --- 更新逻辑 ---
      final assetToUpdate = _editingAsset!;
      assetToUpdate.name = _nameController.text.trim();
      assetToUpdate.code = _codeController.text.trim();
      assetToUpdate.subType = _selectedSubType;
      assetToUpdate.currency = _selectedCurrency;
      
      // 7. 调用 SyncService 保存 (替换 isar.writeTxn)
      await syncService.saveAsset(assetToUpdate);
      
      // 8. 刷新相关 Provider
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
        ..createdAt = DateTime.now() // (设置 createdAt)
        // 9. (关键) 设置 SUPABASE ID 关系，替换 IsarLink
        ..accountSupabaseId = parentAccount.supabaseId; 

      final priceText = _latestPriceController.text.trim();
      if (priceText.isNotEmpty) {
        newAsset.latestPrice = double.tryParse(priceText) ?? 0.0;
        newAsset.priceUpdateDate = DateTime.now();
      }

      // 10. (关键) 我们必须先保存 Asset，以获取它新生成的 supabaseId
      await syncService.saveAsset(newAsset);
      // 'newAsset' 对象现在已从 syncService 回写，并包含了新的 supabaseId

      if (newAsset.supabaseId == null) {
         // 如果保存失败 (例如离线)，supabaseId 会是 null。
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建资产失败，请检查网络连接。')));
         return; // 终止操作，不允许创建孤立的子记录
      }


      if (_selectedMethod == AssetTrackingMethod.shareBased) {
        // --- 保存份额法子记录 ---
        final snapshot = PositionSnapshot()
          ..totalShares = double.parse(_sharesController.text)
          ..averageCost = double.parse(_costController.text)
          ..date = _selectedDate
          ..createdAt = DateTime.now()
          // 11. (关键) 使用返回的 newAsset.supabaseId 设置关系
          ..assetSupabaseId = newAsset.supabaseId; 

        await syncService.savePositionSnapshot(snapshot); // 12. 调用 SyncService 保存子记录

      } else {
        // --- 保存价值法子记录 ---
        final initialInvestment = double.parse(_initialInvestmentController.text);
        final transaction = Transaction()
          ..type = TransactionType.invest
          ..amount = initialInvestment
          ..date = _selectedDate
          ..createdAt = DateTime.now()
          // 13. (关键) 设置关系
          ..assetSupabaseId = newAsset.supabaseId;
        
        final updateValueTxn = Transaction()
          ..type = TransactionType.updateValue
          ..amount = initialInvestment
          ..date = _selectedDate
          ..createdAt = DateTime.now()
          // 14. (关键) 设置关系
          ..assetSupabaseId = newAsset.supabaseId;

        // 15. 分别调用 SyncService 保存
        await syncService.saveTransaction(transaction);
        await syncService.saveTransaction(updateValueTxn);
      }
      
      // 16. (移除) ref.invalidate(trackedAssetsWithPerformanceProvider) 不再需要，因为它是 Stream 会自动更新
    }
    
    // 17. (保留) 刷新 Dashboard
    ref.invalidate(dashboardDataProvider); 
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
              // (*** 您的表单 UI 布局保持不变 ***)
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

  // (*** 您的 _buildShareBasedForm 和 _buildValueBasedForm 辅助函数保持不变 ***)
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
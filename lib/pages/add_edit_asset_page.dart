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
import 'package:isar/isar.dart';

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

  // 修复时序问题的 _saveAsset 方法
  Future<void> _saveAsset() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    
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

      final isar = DatabaseService().isar;

      if (_isEditing) {
        // --- 更新逻辑保持不变 ---
        final assetToUpdate = _editingAsset!;
        assetToUpdate.name = _nameController.text.trim();
        assetToUpdate.code = _codeController.text.trim();
        assetToUpdate.subType = _selectedSubType;
        assetToUpdate.currency = _selectedCurrency;
        
        await syncService.saveAsset(assetToUpdate);
        
        ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
        if(assetToUpdate.trackingMethod == AssetTrackingMethod.shareBased) {
          ref.invalidate(shareAssetDetailProvider(assetToUpdate.id));
        } else {
          ref.invalidate(valueAssetDetailProvider(assetToUpdate.id));
        }
      } else {
        // --- 新建逻辑（关键修复：等待实时同步完成）---
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

        // 先在本地创建获取 Isar ID
        await isar.writeTxn(() async {
          await isar.assets.put(newAsset);
        });
        
        // 通过同步服务同步资产
        await syncService.saveAsset(newAsset);
        
        // 关键修复：等待实时监听器处理完成，确保资产完全同步
        await _waitForAssetSync(newAsset.id, maxWaitSeconds: 5);
        
        // 重新从数据库获取已完全同步的资产
        final syncedAsset = await isar.assets.get(newAsset.id);
        
        if (syncedAsset?.supabaseId != null) {
          print('[UI] Asset fully synced with supabaseId: ${syncedAsset!.supabaseId}');
          
          // 现在可以安全地创建子记录
          if (_selectedMethod == AssetTrackingMethod.shareBased) {
            await _createShareBasedRecord(syncedAsset, syncService, isar);
          } else {
            await _createValueBasedRecords(syncedAsset, syncService, isar);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('资产同步超时，请手动添加初始记录'))
            );
          }
        }
      }
      
      ref.invalidate(dashboardDataProvider); 
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      print('保存资产失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'))
        );
      }
    }
  }

  // 等待资产同步完成的辅助方法
  Future<void> _waitForAssetSync(int assetId, {int maxWaitSeconds = 5}) async {
    final isar = DatabaseService().isar;
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      final asset = await isar.assets.get(assetId);
      if (asset?.supabaseId != null) {
        print('[UI] Asset sync completed after ${DateTime.now().difference(startTime).inMilliseconds}ms');
        return;
      }
      
      // 每200ms检查一次
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    print('[UI] Asset sync timeout after ${maxWaitSeconds}s');
  }

  // 创建份额法记录
  Future<void> _createShareBasedRecord(Asset syncedAsset, SupabaseSyncService syncService, Isar isar) async {
    try {
      final snapshot = PositionSnapshot()
        ..totalShares = double.parse(_sharesController.text)
        ..averageCost = double.parse(_costController.text)
        ..date = _selectedDate
        ..createdAt = DateTime.now()
        ..assetSupabaseId = syncedAsset.supabaseId;

      await isar.writeTxn(() async {
        await isar.positionSnapshots.put(snapshot);
      });
      await syncService.savePositionSnapshot(snapshot);
      print('[UI] PositionSnapshot created successfully');
    } catch (e) {
      print('[UI] Failed to create PositionSnapshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始快照创建失败: $e'))
        );
      }
    }
  }

  // 创建价值法记录
  Future<void> _createValueBasedRecords(Asset syncedAsset, SupabaseSyncService syncService, Isar isar) async {
    final initialInvestment = double.parse(_initialInvestmentController.text);
    
    try {
      // 创建投资记录
      final transaction = Transaction()
        ..type = TransactionType.invest
        ..amount = initialInvestment
        ..date = _selectedDate
        ..createdAt = DateTime.now()
        ..assetSupabaseId = syncedAsset.supabaseId;

      await isar.writeTxn(() async {
        await isar.transactions.put(transaction);
      });
      await syncService.saveTransaction(transaction);
      print('[UI] Investment transaction created successfully');

      // 稍等一下再创建下一个记录，避免过快的连续请求
      await Future.delayed(const Duration(milliseconds: 300));

      // 创建总值更新记录
      final updateValueTxn = Transaction()
        ..type = TransactionType.updateValue
        ..amount = initialInvestment
        ..date = _selectedDate
        ..createdAt = DateTime.now()
        ..assetSupabaseId = syncedAsset.supabaseId;

      await isar.writeTxn(() async {
        await isar.transactions.put(updateValueTxn);
      });
      await syncService.saveTransaction(updateValueTxn);
      print('[UI] UpdateValue transaction created successfully');

    } catch (e) {
      print('[UI] Failed to create transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始交易记录创建失败: $e'))
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
// 文件: lib/pages/add_edit_asset_page.dart
// (*** 关键修复：修复了创建和编辑资产时的状态管理和保存逻辑 ***)
// (*** V2：增加了对初始投入/份额/成本必须大于0的验证 ***)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';
import 'package:isar/isar.dart';

// (常量定义保持不变)
const Map<AssetClass, String> assetClassDisplayNames = {
  AssetClass.equity: '权益类',
  AssetClass.fixedIncome: '固定收益类',
  AssetClass.cashEquivalent: '现金及等价物',
  AssetClass.alternative: '另类投资',
  AssetClass.other: '其他',
};

const Map<AssetSubType, String> assetSubTypeDisplayNames = {
  AssetSubType.stock: '股票',
  AssetSubType.etf: '场内基金(ETF)',
  AssetSubType.mutualFund: '场外基金',
  AssetSubType.wealthManagement: '理财',
  AssetSubType.other: '其他',
};


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
  AssetClass _selectedAssetClass = AssetClass.equity;

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
  
  bool get _isAssetClassSelectionLocked {
    if (_selectedMethod == AssetTrackingMethod.valueBased) {
      return false; 
    }
    
    switch (_selectedSubType) {
      case AssetSubType.stock:
        return true; 
      
      case AssetSubType.etf:
      case AssetSubType.mutualFund:
      case AssetSubType.other:
      default:
        return false; 
    }
  }


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
        _selectedAssetClass = _editingAsset!.assetClass;
      }
    } else {
      _selectedCurrency = _parentAccount?.currency ?? 'CNY';
      // (创建新资产时，根据默认方法设置默认类型)
      _updateDefaultsForMethod(_selectedMethod);
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

  // (*** 1. 关键修复：提取方法切换的逻辑 ***)
  void _updateDefaultsForMethod(AssetTrackingMethod method) {
    if (method == AssetTrackingMethod.valueBased) {
      _selectedSubType = AssetSubType.wealthManagement; 
      _selectedAssetClass = AssetClass.fixedIncome; 
    } else {
      _selectedSubType = AssetSubType.stock;
      _selectedAssetClass = AssetClass.equity;
    }
  }

  // (*** 2. 关键修复：修复 _saveAsset 函数 ***)
  Future<void> _saveAsset() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    
    final syncService = ref.read(syncServiceProvider); 
    final isar = DatabaseService().isar;
    final parentAccount = _parentAccount!;

    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final sharesText = _sharesController.text;
    final costText = _costController.text;
    final initialInvestmentText = _initialInvestmentController.text.trim();
    final latestPriceText = _latestPriceController.text.trim();
    
    // (从状态中获取当前值)
    final currentSelectedDate = _selectedDate;
    final currentSelectedMethod = _selectedMethod;
    final currentSelectedSubType = _selectedSubType;
    final currentSelectedCurrency = _selectedCurrency;
    final currentSelectedAssetClass = _selectedAssetClass;

    try {
      if (parentAccount.supabaseId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('错误：父账户尚未同步，请稍后重试。'))
          );
        }
        return;
      }

      if (_isEditing) {
        final assetToUpdate = _editingAsset!;
        assetToUpdate.name = name;
        assetToUpdate.code = code;
        assetToUpdate.currency = currentSelectedCurrency;
        assetToUpdate.assetClass = currentSelectedAssetClass;
        
        // (*** 2.1 关键修复：同时保存跟踪方法和子类型 ***)
        assetToUpdate.trackingMethod = currentSelectedMethod; 
        assetToUpdate.subType = currentSelectedSubType;
        // (*** 修复结束 ***)

        await isar.writeTxn(() async {
          await isar.assets.put(assetToUpdate);
        });
        
        syncService.saveAsset(assetToUpdate).catchError((e) {
          print('[BG Sync] 资产更新同步失败: $e');
        });
        
        // (使所有相关详情页失效)
        ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
        ref.invalidate(shareAssetPerformanceProvider(assetToUpdate.id));
        ref.invalidate(valueAssetDetailProvider(assetToUpdate.id));

      } else {
        // (创建新资产的逻辑)
        final newAsset = Asset()
          ..name = name
          ..code = code
          ..trackingMethod = currentSelectedMethod // (来自 state)
          ..subType = currentSelectedSubType       // (来自 state)
          ..currency = currentSelectedCurrency
          ..createdAt = DateTime.now() 
          ..accountSupabaseId = parentAccount.supabaseId
          ..assetClass = currentSelectedAssetClass;

        if (latestPriceText.isNotEmpty) {
          newAsset.latestPrice = double.tryParse(latestPriceText) ?? 0.0;
          newAsset.priceUpdateDate = DateTime.now();
        }

        await isar.writeTxn(() async {
          await isar.assets.put(newAsset);
        });
        
        _syncNewAssetInBackground(
          newAsset, 
          syncService, 
          isar, 
          sharesText, 
          costText, 
          initialInvestmentText, 
          currentSelectedDate
        );
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
  // (*** 修复结束 ***)

  // ( ... _syncNewAssetInBackground, _waitForAssetSync, _waitForTransactionSync ... )
  // ( ... _createShareBasedRecord, _createValueBasedRecords 均保持不变 ...)
  Future<void> _syncNewAssetInBackground(
    Asset newAsset, 
    SupabaseSyncService syncService, 
    Isar isar,
    String sharesText,
    String costText,
    String initialInvestmentText,
    DateTime recordDate
  ) async {
    try {
      await syncService.saveAsset(newAsset);
      await _waitForAssetSync(newAsset.id, maxWaitSeconds: 5);
      final syncedAsset = await isar.assets.get(newAsset.id);
      
      if (syncedAsset == null) {
        print('[BG Sync] 错误：资产在本地数据库中未找到 (这不应该发生)');
        return; 
      }

      if (syncedAsset.supabaseId != null) {
        print('[BG Sync] Asset fully synced with supabaseId: ${syncedAsset.supabaseId}');
        
        if (syncedAsset.trackingMethod == AssetTrackingMethod.shareBased) {
          await _createShareBasedRecord(
            syncedAsset, syncService, isar, 
            sharesText, costText, recordDate
          );
        } else {
          await _createValueBasedRecords(
            syncedAsset, syncService, isar, 
            initialInvestmentText, recordDate
          );
        }
      } else {
        print('[BG Sync] 资产同步超时，请手动添加初始记录');
      }
    } catch (e) {
      print('[BG Sync] 后台同步新资产失败: $e');
    }
  }
  Future<void> _waitForAssetSync(int assetId, {int maxWaitSeconds = 5}) async {
    final isar = DatabaseService().isar;
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      final asset = await isar.assets.get(assetId);
      if (asset?.supabaseId != null) {
        print('[UI] Asset sync completed after ${DateTime.now().difference(startTime).inMilliseconds}ms');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    print('[UI] Asset sync timeout after ${maxWaitSeconds}s');
  }
  Future<void> _waitForTransactionSync(int transactionId, {int maxWaitSeconds = 5}) async {
    final isar = DatabaseService().isar;
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      final tx = await isar.transactions.get(transactionId);
      if (tx?.supabaseId != null) {
        print('[UI] Transaction sync completed (Id: $transactionId) after ${DateTime.now().difference(startTime).inMilliseconds}ms');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    print('[UI] Transaction sync timeout (Id: $transactionId) after ${maxWaitSeconds}s');
  }
  Future<void> _createShareBasedRecord(
    Asset syncedAsset, SupabaseSyncService syncService, Isar isar,
    String sharesText, String costText, DateTime recordDate
  ) async {
    try {
      final existingSnapshots = await isar.positionSnapshots
          .filter()
          .assetSupabaseIdEqualTo(syncedAsset.supabaseId)
          .findAll();
      if (existingSnapshots.isNotEmpty) {
        print('[DEBUG] Snapshot already exists, skipping creation');
        return;
      }
      final totalShares = double.tryParse(sharesText) ?? 0.0;
      final averageCost = double.tryParse(costText) ?? 0.0;
      
      // (此时验证已确保 totalShares 和 averageCost > 0)
      
      final snapshot = PositionSnapshot()
        ..totalShares = totalShares
        ..averageCost = averageCost
        ..date = recordDate
        ..createdAt = DateTime.now()
        ..assetSupabaseId = syncedAsset.supabaseId;

      await isar.writeTxn(() async {
        await isar.positionSnapshots.put(snapshot);
      });
      syncService.savePositionSnapshot(snapshot).catchError((e) {
          print('[BG Sync] PositionSnapshot 同步失败: $e');
      });
      print('[UI] PositionSnapshot created successfully');
    } catch (e) {
      print('[UI] Failed to create PositionSnapshot: $e');
    }
  }
  Future<void> _createValueBasedRecords(
    Asset syncedAsset, SupabaseSyncService syncService, Isar isar,
    String initialInvestmentText, DateTime recordDate
  ) async {
    final initialInvestment = double.tryParse(initialInvestmentText) ?? 0.0;
    
    // (此时验证已确保 initialInvestment > 0)
    
    try {
      final existingInvest = await isar.transactions
          .filter()
          .assetSupabaseIdEqualTo(syncedAsset.supabaseId)
          .and()
          .typeEqualTo(TransactionType.invest)
          .findFirst();
      if (existingInvest != null) {
        print('[DEBUG] Investment transaction already exists, skipping creation');
      } else {
        final transaction = Transaction()
          ..type = TransactionType.invest
          ..amount = initialInvestment // (这里现在一定是正数)
          ..date = recordDate
          ..createdAt = DateTime.now()
          ..assetSupabaseId = syncedAsset.supabaseId;
        try {
          await isar.writeTxn(() async {
            await isar.transactions.put(transaction);
          });
          syncService.saveTransaction(transaction).catchError((e) {
              print('[BG Sync] 投资记录同步失败: $e');
          }); 
          print('[UI] Investment transaction created successfully');
        } catch (e) {
          print('[UI] Failed to create investment transaction: $e');
          return; 
        }
      }
      final existingUpdate = await isar.transactions
          .filter()
          .assetSupabaseIdEqualTo(syncedAsset.supabaseId)
          .and()
          .typeEqualTo(TransactionType.updateValue)
          .findFirst();
      if (existingUpdate != null) {
        print('[DEBUG] UpdateValue transaction already exists, skipping creation');
      } else {
        final updateValueTxn = Transaction()
          ..type = TransactionType.updateValue
          ..amount = initialInvestment // (这里现在一定是正数)
          ..date = recordDate.add(const Duration(minutes: 1))
          ..createdAt = DateTime.now().add(const Duration(seconds: 1))
          ..assetSupabaseId = syncedAsset.supabaseId;
        try {
          await isar.writeTxn(() async {
            await isar.transactions.put(updateValueTxn);
          });
          syncService.saveTransaction(updateValueTxn).catchError((e) {
              print('[BG Sync] 总值记录同步失败: $e');
          });
          print('[UI] UpdateValue transaction created successfully');
        } catch (e) {
          print('[UI] Failed to create updateValue transaction: $e');
        }
      }
    } catch (e) {
      print('[UI] Failed to create transactions: $e');
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
                  // (*** 3. 关键修复：移除 'if (!_isEditing)' ***)
                  // (现在编辑时也可以切换跟踪方法)
                  SegmentedButton<AssetTrackingMethod>(
                    segments: const [
                      ButtonSegment(
                          value: AssetTrackingMethod.shareBased,
                          label: Text('份额法'),
                          icon: Icon(Icons.pie_chart)),
                      ButtonSegment(
                          value: AssetTrackingMethod.valueBased,
                          label: Text('价值法'),
                          icon: Icon(Icons.account_balance_wallet)),
                    ],
                    selected: {_selectedMethod},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedMethod = newSelection.first;
                        // (*** 4. 关键修复：切换时重置 subType 和 class ***)
                        _updateDefaultsForMethod(_selectedMethod);
                        // (*** 修复结束 ***)
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // (*** 修复结束 ***)
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: '资产名称', border: OutlineInputBorder()),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? '请输入资产名称' : null,
                  ),
                  const SizedBox(height: 16),

                  if (_selectedMethod == AssetTrackingMethod.shareBased)
                    ..._buildShareBasedForm() 
                  else
                    ..._buildValueBasedForm(), 

                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<AssetClass>(
                    value: _selectedAssetClass,
                    decoration: InputDecoration(
                      labelText: '资产大类',
                      border: const OutlineInputBorder(),
                      filled: _isAssetClassSelectionLocked,
                      fillColor: _isAssetClassSelectionLocked 
                          ? Colors.grey.withOpacity(0.1) 
                          : null,
                    ),
                    items: AssetClass.values.map((AssetClass assetClass) {
                      return DropdownMenuItem<AssetClass>(
                        value: assetClass,
                        child: Text(assetClassDisplayNames[assetClass] ?? assetClass.name),
                      );
                    }).toList(),
                    
                    onChanged: _isAssetClassSelectionLocked 
                      ? null 
                      : (AssetClass? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedAssetClass = newValue;
                            });
                          }
                        },
                  ),

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
                        child: Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate)),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _selectedDate = pickedDate;
                            });
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

  // (*** 5. 关键修复：从份额法表单中移除理财 ***)
  List<Widget> _buildShareBasedForm() {
    return [
      const Text('资产类型', style: TextStyle(fontSize: 16, color: Colors.grey)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8.0,
        children: [
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.stock]!),
            selected: _selectedSubType == AssetSubType.stock,
            onSelected: (selected) {
              // (*** 6. 关键修复：使用 radio-like 逻辑 ***)
              if (selected) { 
                setState(() { 
                  _selectedSubType = AssetSubType.stock;
                  _selectedAssetClass = AssetClass.equity; 
                });
              }
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.etf]!),
            selected: _selectedSubType == AssetSubType.etf,
            onSelected: (selected) {
              if (selected) {
                setState(() { 
                  _selectedSubType = AssetSubType.etf;
                  // (ETF/基金 不自动选择大类)
                });
              }
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.mutualFund]!),
            selected: _selectedSubType == AssetSubType.mutualFund,
            onSelected: (selected) {
              if (selected) {
                setState(() { 
                  _selectedSubType = AssetSubType.mutualFund;
                });
              }
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.other]!),
            selected: _selectedSubType == AssetSubType.other,
            onSelected: (selected) {
              if (selected) {
                setState(() { 
                  _selectedSubType = AssetSubType.other;
                  _selectedAssetClass = AssetClass.other; 
                });
              }
            },
          ),
          // (*** 理财 ChoiceChip 已从这里移除 ***)
        ],
      ),
      const SizedBox(height: 16),

      TextFormField(
        controller: _codeController,
        decoration: const InputDecoration(
            labelText: '资产代码',
            hintText: '例如: 600519 或 510300',
            border: OutlineInputBorder()),
      ),
      if (!_isEditing) ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _sharesController,
          decoration:
              const InputDecoration(labelText: '总份额', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          
          // ▼▼▼ 关键修复：增加正数验证 ▼▼▼
          validator: (value) {
            if (value == null || value.isEmpty) return '请输入总份额';
            final num = double.tryParse(value);
            if (num == null) return '请输入有效的数字';
            if (num <= 0) return '份额必须大于0';
            return null;
          },
          // ▲▲▲ 修复结束 ▲▲▲
          
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _costController,
          decoration: const InputDecoration(
              labelText: '单位成本', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),

          // ▼▼▼ 关键修复：增加正数验证 ▼▼▼
          validator: (value) {
            if (value == null || value.isEmpty) return '请输入单位成本';
            final num = double.tryParse(value);
            if (num == null) return '请输入有效的数字';
            if (num <= 0) return '成本必须大于0';
            return null;
          },
          // ▲▲▲ 修复结束 ▲▲▲

        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _latestPriceController,
          decoration: const InputDecoration(
              labelText: '最新价格 (可选)', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ]
    ];
  }

  // (*** 7. 关键修复：修复价值法表单的 onSelected 逻辑 ***)
  List<Widget> _buildValueBasedForm() {
    return [
      const Text('资产类型', style: TextStyle(fontSize: 16, color: Colors.grey)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8.0,
        children: [
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.wealthManagement]!),
            selected: _selectedSubType == AssetSubType.wealthManagement,
            onSelected: (selected) {
              if (selected) { 
                setState(() {
                  _selectedSubType = AssetSubType.wealthManagement;
                  _selectedAssetClass = AssetClass.fixedIncome; 
                });
              }
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.other]!),
            selected: _selectedSubType == AssetSubType.other,
            onSelected: (selected) {
              if (selected) { 
                setState(() {
                  _selectedSubType = AssetSubType.other;
                  _selectedAssetClass = AssetClass.other; 
                });
              }
            },
          ),
        ],
      ),
      
      const SizedBox(height: 16),
      
      if (!_isEditing)
        TextFormField(
          controller: _initialInvestmentController,
          decoration: const InputDecoration(
              labelText: '初始投入金额 / 当前价值', border: OutlineInputBorder()), 
          keyboardType: const TextInputType.numberWithOptions(decimal: true),

          // ▼▼▼ 关键修复：增加正数验证 ▼▼▼
          validator: (value) {
            if (value == null || value.isEmpty) return '请输入金额';
            final num = double.tryParse(value);
            if (num == null) return '请输入有效的数字';
            if (num <= 0) return '金额必须大于0';
            return null;
          },
          // ▲▲▲ 修复结束 ▲▲▲

        ),
    ];
  }
}
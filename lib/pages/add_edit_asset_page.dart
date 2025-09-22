// 文件: lib/pages/add_edit_asset_page.dart
// (*** 已移除 '存款' 选项，按你的要求简化 ***)

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

const Map<AssetClass, String> assetClassDisplayNames = {
  AssetClass.equity: '权益类',
  AssetClass.fixedIncome: '固定收益类',
  AssetClass.cashEquivalent: '现金及等价物',
  AssetClass.alternative: '另类投资',
  AssetClass.other: '其他',
};

// (*** 1. 关键修改：移除 '存款' ***)
const Map<AssetSubType, String> assetSubTypeDisplayNames = {
  AssetSubType.stock: '股票',
  AssetSubType.etf: '场内基金(ETF)',
  AssetSubType.mutualFund: '场外基金',
  AssetSubType.wealthManagement: '理财',
  // ( 'deposit' 已移除 )
  AssetSubType.other: '其他',
};
// (*** 修改结束 ***)


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
  AssetClass _selectedAssetClass = AssetClass.equity; // 默认为权益

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
  
  // ( "资产大类" 锁定逻辑保持不变 )
  bool get _isAssetClassSelectionLocked {
    if (_selectedMethod == AssetTrackingMethod.valueBased) {
      // 价值法：理财、其他 都不锁定，允许用户自选
      return false; 
    }
    
    // 份额法：
    switch (_selectedSubType) {
      case AssetSubType.stock:
        return true; // 股票 100% 是权益，锁定！
      
      // 基金、其他 都不锁定，允许用户选择
      case AssetSubType.etf:
      case AssetSubType.mutualFund:
      case AssetSubType.other:
      // (*** 2. 关键修改：移除 'deposit' case ***)
      // case AssetSubType.deposit:
      case AssetSubType.wealthManagement: // (理财也可以是份额法，例如某些券商产品)
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

  // ( _saveAsset, _syncNewAssetInBackground, _waitForAssetSync, _waitForTransactionSync, _createShareBasedRecord, _createValueBasedRecords ... )
  // ( ... 这些函数都保持不变，为简洁起见，省略 ...)
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
        assetToUpdate.subType = currentSelectedSubType;
        assetToUpdate.currency = currentSelectedCurrency;
        assetToUpdate.assetClass = currentSelectedAssetClass;
        
        await isar.writeTxn(() async {
          await isar.assets.put(assetToUpdate);
        });
        
        syncService.saveAsset(assetToUpdate).catchError((e) {
          print('[BG Sync] 资产更新同步失败: $e');
        });
        
        ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
        if(assetToUpdate.trackingMethod == AssetTrackingMethod.shareBased) {
          ref.invalidate(shareAssetPerformanceProvider(assetToUpdate.id));
        } else {
          ref.invalidate(valueAssetDetailProvider(assetToUpdate.id));
        }
      } else {
        final newAsset = Asset()
          ..name = name
          ..code = code
          ..trackingMethod = currentSelectedMethod
          ..subType = currentSelectedSubType
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
          ..amount = initialInvestment
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
          ..amount = initialInvestment
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
                  if (!_isEditing)
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
                          if (_selectedMethod == AssetTrackingMethod.valueBased) {
                            _selectedSubType = AssetSubType.wealthManagement; 
                            _selectedAssetClass = AssetClass.fixedIncome; 
                          } else {
                            _selectedSubType = AssetSubType.stock;
                            _selectedAssetClass = AssetClass.equity;
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 24),
                  
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

  // ( _buildShareBasedForm 保持不变 )
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
              if (selected)
                setState(() { 
                  _selectedSubType = AssetSubType.stock;
                  _selectedAssetClass = AssetClass.equity; // (自动选择并锁定)
                });
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.etf]!),
            selected: _selectedSubType == AssetSubType.etf,
            onSelected: (selected) {
              if (selected)
                setState(() { 
                  _selectedSubType = AssetSubType.etf;
                  // (基金类不自动选择大类)
                });
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.mutualFund]!),
            selected: _selectedSubType == AssetSubType.mutualFund,
            onSelected: (selected) {
              if (selected)
                setState(() { 
                  _selectedSubType = AssetSubType.mutualFund;
                  // (基金类不自动选择大类)
                });
            },
          ),
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.other]!),
            selected: _selectedSubType == AssetSubType.other,
            onSelected: (selected) {
              if (selected)
                setState(() { 
                  _selectedSubType = AssetSubType.other;
                  _selectedAssetClass = AssetClass.other; // (自动选择)
                });
            },
          ),
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
          validator: (value) => (value == null ||
                  value.isEmpty ||
                  double.tryParse(value) == null)
              ? '请输入有效的数字'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _costController,
          decoration: const InputDecoration(
              labelText: '单位成本', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) => (value == null ||
                  value.isEmpty ||
                  double.tryParse(value) == null)
              ? '请输入有效的数字'
              : null,
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

  // (*** 3. 关键修改：这是修改后的 _buildValueBasedForm ***)
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
              if (selected)
                setState(() {
                  _selectedSubType = AssetSubType.wealthManagement;
                  _selectedAssetClass = AssetClass.fixedIncome; // (自动推荐 "固收")
                });
            },
          ),
          // (*** '存款' 的 ChoiceChip 已按要求移除 ***)
          ChoiceChip(
            label: Text(assetSubTypeDisplayNames[AssetSubType.other]!),
            selected: _selectedSubType == AssetSubType.other,
            onSelected: (selected) {
              if (selected)
                setState(() {
                  _selectedSubType = AssetSubType.other;
                  _selectedAssetClass = AssetClass.other; // (自动推荐 "其他")
                });
            },
          ),
        ],
      ),
      // (*** 修改结束 ***)
      
      const SizedBox(height: 16),
      
      if (!_isEditing)
        TextFormField(
          controller: _initialInvestmentController,
          decoration: const InputDecoration(
              labelText: '初始投入金额 / 当前价值', border: OutlineInputBorder()), // (更新了 Label)
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) => (value == null ||
                  value.isEmpty ||
                  double.tryParse(value) == null)
              ? '请输入有效的数字'
              : null,
        ),
    ];
  }
}
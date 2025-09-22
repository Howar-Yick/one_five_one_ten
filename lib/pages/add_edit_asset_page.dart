// 文件: lib/pages/add_edit_asset_page.dart
// (*** 关键修复：重构了 AssetClass 和 AssetSubType 的联动逻辑 ***)

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

// (*** 1. 关键修改：为 SubType 也添加 DisplayNames ***)
const Map<AssetSubType, String> assetSubTypeDisplayNames = {
  AssetSubType.stock: '股票',
  AssetSubType.etf: '场内基金(ETF)',
  AssetSubType.mutualFund: '场外基金',
  AssetSubType.wealthManagement: '理财', // (新增)
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
  
  // (*** 2. 关键修改：用于判断 AssetClass 下拉菜单是否应锁定 ***)
  bool get _isAssetClassSelectionLocked {
    // 价值法时，允许切换 理财/其他，大类会跟随
    if (_selectedMethod == AssetTrackingMethod.valueBased) {
      return true; // 大类跟随 SubType 变动，用户不能手动选
    }
    
    // 份额法时
    switch (_selectedSubType) {
      case AssetSubType.stock:
        return true; // 股票一定D是权益
      case AssetSubType.etf:
      case AssetSubType.mutualFund:
        return false; // *** 核心修复：基金类允许用户自由选择大类 ***
      case AssetSubType.other:
      default:
        return false; // 其他也允许自由选择
    }
  }
  // (*** 修改结束 ***)


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
      // (*** 3. 关键修改：新建时不再调用 _deduceAssetClass ***)
      // (默认值已在声明时设置好：shareBased, stock, equity)
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

  // (*** 4. 关键修改：移除 _deduceAssetClass 辅助函数 ***)
  // (*** (函数已移除) ***)

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
    
    // 1. 捕获所有需要的数据
    // (因为页面即将关闭，我们不能再依赖 Controller)
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
        // --- 更新逻辑 ---
        final assetToUpdate = _editingAsset!;
        assetToUpdate.name = name;
        assetToUpdate.code = code;
        assetToUpdate.subType = currentSelectedSubType;
        assetToUpdate.currency = currentSelectedCurrency;
        assetToUpdate.assetClass = currentSelectedAssetClass;
        
        // 2A. (AWAIT) 本地保存
        await isar.writeTxn(() async {
          await isar.assets.put(assetToUpdate);
        });
        
        // 2B. (后台) 触发同步
        syncService.saveAsset(assetToUpdate).catchError((e) {
          print('[BG Sync] 资产更新同步失败: $e');
        });
        
        // 3A. 立即刷新 provider
        ref.invalidate(trackedAssetsWithPerformanceProvider(widget.accountId));
        if(assetToUpdate.trackingMethod == AssetTrackingMethod.shareBased) {
          ref.invalidate(shareAssetPerformanceProvider(assetToUpdate.id));
        } else {
          ref.invalidate(valueAssetDetailProvider(assetToUpdate.id));
        }
      } else {
        // --- 新建逻辑 ---
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

        // 2A. (AWAIT) 本地创建 (速度很快)
        await isar.writeTxn(() async {
          await isar.assets.put(newAsset);
        });
        
        // 2B. (后台) 触发后台同步链
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
      
      // 3B. 立即刷新并退出 (对新建和编辑都生效)
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

  // (新增一个函数来处理后台同步)
  Future<void> _syncNewAssetInBackground(
    Asset newAsset, 
    SupabaseSyncService syncService, 
    Isar isar,
    // (我们必须传入 controller 的值, 因为 controller 即将被销毁)
    String sharesText,
    String costText,
    String initialInvestmentText,
    DateTime recordDate
  ) async {
    try {
      // 2. 触发同步 (AWAIT - 这是在后台，可以等)
      await syncService.saveAsset(newAsset);
      
      // 3. 等待同步完成 (这现在在后台发生, 不会卡住UI)
      await _waitForAssetSync(newAsset.id, maxWaitSeconds: 5);
      
      // 4. 重新获取完全同步的资产
      final syncedAsset = await isar.assets.get(newAsset.id);
      
      // (*** 关键修复：在这里添加一个显式的 null 检查 ***)
      if (syncedAsset == null) {
        print('[BG Sync] 错误：资产在本地数据库中未找到 (这不应该发生)');
        return; // 提前退出
      }

      // (*** 现在 syncedAsset 被Dart认为是 'Asset' (非空) ***)
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

  // (更新函数签名以接受参数)
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
      
      // (修复BUG：如果初始份额/成本为空，则默认为0.0)
      final totalShares = double.tryParse(sharesText) ?? 0.0;
      final averageCost = double.tryParse(costText) ?? 0.0;
      
      final snapshot = PositionSnapshot()
        ..totalShares = totalShares // (使用参数)
        ..averageCost = averageCost // (使用参数)
        ..date = recordDate // (使用参数)
        ..createdAt = DateTime.now()
        ..assetSupabaseId = syncedAsset.supabaseId;

      await isar.writeTxn(() async {
        await isar.positionSnapshots.put(snapshot);
      });
      
      // (后台执行)
      syncService.savePositionSnapshot(snapshot).catchError((e) {
          print('[BG Sync] PositionSnapshot 同步失败: $e');
      });
      print('[UI] PositionSnapshot created successfully');
    } catch (e) {
      print('[UI] Failed to create PositionSnapshot: $e');
    }
  }

  // (更新函数签名以接受参数)
  Future<void> _createValueBasedRecords(
    Asset syncedAsset, SupabaseSyncService syncService, Isar isar,
    String initialInvestmentText, DateTime recordDate
  ) async {
    
    // (修复BUG：如果初始投入为空，则默认为0.0)
    final initialInvestment = double.tryParse(initialInvestmentText) ?? 0.0;
    
    try {
      // --- 处理第一条：Invest Transaction ---
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
          ..date = recordDate // (使用参数)
          ..createdAt = DateTime.now()
          ..assetSupabaseId = syncedAsset.supabaseId;

        try {
          await isar.writeTxn(() async {
            await isar.transactions.put(transaction);
          });
          // (后台执行)
          syncService.saveTransaction(transaction).catchError((e) {
              print('[BG Sync] 投资记录同步失败: $e');
          }); 
          print('[UI] Investment transaction created successfully');
        } catch (e) {
          print('[UI] Failed to create investment transaction: $e');
          return; 
        }
      }

      // --- 处理第二条：UpdateValue Transaction ---
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
          ..date = recordDate.add(const Duration(minutes: 1)) // (使用参数)
          ..createdAt = DateTime.now().add(const Duration(seconds: 1))
          ..assetSupabaseId = syncedAsset.supabaseId;

        try {
          await isar.writeTxn(() async {
            await isar.transactions.put(updateValueTxn);
          });
          // (后台执行)
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
                      // (*** 5. 关键修改：更新此处的 onSelectionChanged 逻辑 ***)
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedMethod = newSelection.first;
                          // (*** 自动逻辑：根据跟踪方法设置默认的类型和类别 ***)
                          if (_selectedMethod == AssetTrackingMethod.valueBased) {
                            _selectedSubType = AssetSubType.wealthManagement;
                            _selectedAssetClass = AssetClass.fixedIncome;
                          } else {
                            // (切换回份额法时，默认为权益-股票)
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

                  // --- (*** 6. 关键修改：重构 资产大类 和 资产类型 的顺序和逻辑 ***)
                  
                  // (*** 资产类型 (SubType) 现在根据 跟踪方法(Method) 来显示 ***)
                  if (_selectedMethod == AssetTrackingMethod.shareBased)
                    ..._buildShareBasedForm() // 份额法表单 (包含自己的 SubType 选择)
                  else
                    ..._buildValueBasedForm(), // 价值法表单 (包含自己的 SubType 选择)

                  const SizedBox(height: 16),
                  
                  // (*** 资产大类 (AssetClass) 现在是独立的 ***)
                  DropdownButtonFormField<AssetClass>(
                    value: _selectedAssetClass,
                    decoration: InputDecoration(
                      labelText: '资产大类',
                      border: const OutlineInputBorder(),
                      // (*** 根据 _isAssetClassSelectionLocked 禁用/启用 ***)
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
                    
                    // (*** 7. 关键修改：onChanged 逻辑已简化 ***)
                    // (*** 如果锁定了，onChanged 为 null，下拉菜单自动禁用 ***)
                    onChanged: _isAssetClassSelectionLocked 
                      ? null 
                      : (AssetClass? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedAssetClass = newValue;
                              // (*** 错误重置逻辑已移除 ***)
                            });
                          }
                        },
                  ),
                  // (*** 修改结束 ***)

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

  // (*** 8. 关键修改：这是修改后的 _buildShareBasedForm ***)
  List<Widget> _buildShareBasedForm() {
    return [
      // (*** 错误逻辑 `if (_selectedAssetClass == AssetClass.equity)` 已移除 ***)
      
      // (*** 这个表单现在始终显示 "资产类型" ***)
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
                  _selectedAssetClass = AssetClass.equity; // (自动选择大类)
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
                  // (*** 基金类不自动选择大类，允许用户自己选 ***)
                  // (*** 这就是你的 债券基金/黄金基金 解决方案 ***)
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
                  // (*** 基金类不自动选择大类，允许用户自己选 ***)
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
                  _selectedAssetClass = AssetClass.other; // (自动选择大类)
                });
            },
          ),
        ],
      ),
      const SizedBox(height: 16),

      // (这些字段对所有 "份额法" 资产都显示)
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
  // (*** 修复结束 ***)

  // (*** 9. 关键修改：这是修改后的 _buildValueBasedForm ***)
  List<Widget> _buildValueBasedForm() {
    return [
      // (*** 新增 "资产类型" (SubType) 的选择器 ***)
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
                  _selectedAssetClass = AssetClass.fixedIncome; // (自动选择大类)
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
                  _selectedAssetClass = AssetClass.other; // (自动选择大类)
                });
            },
          ),
        ],
      ),
      // (*** 新增结束 ***)
      
      const SizedBox(height: 16),
      
      if (!_isEditing)
        TextFormField(
          controller: _initialInvestmentController,
          decoration: const InputDecoration(
              labelText: '初始投入金额', border: OutlineInputBorder()),
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
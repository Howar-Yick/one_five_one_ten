// 文件: lib/services/database_service.dart
// (这是基于你提供的最新文件进行的修复)

import 'package:isar/isar.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/models/account_transaction.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/position_snapshot.dart';
import 'package:one_five_one_ten/models/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:one_five_one_ten/models/deletion.dart'; // <--- 1. 关键修改：新增 Deletion 模型的导入

class DatabaseService {
  late Isar isar;
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  Future<void> init() async {
    if (Isar.instanceNames.isNotEmpty) {
      isar = Isar.getInstance()!;
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        AccountSchema,
        AccountTransactionSchema,
        AssetSchema,
        PositionSnapshotSchema,
        TransactionSchema,
        DeletionSchema, // <--- 2. 关键修改：在这里添加新的 DeletionSchema
      ],
      directory: dir.path,
      name: 'one_five_one_ten_db',
    );

    await _backfillAssetAccountLocalIds();
  }

  Future<void> _backfillAssetAccountLocalIds() async {
    final accounts = await isar.accounts.where().findAll();
    if (accounts.isEmpty) return;

    final Map<String, int> accountIdMap = {
      for (final account in accounts)
        if (account.supabaseId != null) account.supabaseId!: account.id,
    };

    final assets = await isar.assets.where().findAll();
    final needsUpdate = assets.where((asset) =>
        asset.accountLocalId == null && asset.accountSupabaseId != null &&
        accountIdMap.containsKey(asset.accountSupabaseId!));

    if (needsUpdate.isEmpty) return;

    await isar.writeTxn(() async {
      for (final asset in needsUpdate) {
        final supaId = asset.accountSupabaseId;
        if (supaId != null) {
          final accountId = accountIdMap[supaId];
          if (accountId != null) {
            asset.accountLocalId = accountId;
            await isar.assets.put(asset);
          }
        }
      }
    });
  }
}
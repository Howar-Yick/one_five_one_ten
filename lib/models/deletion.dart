// 文件: lib/models/deletion.dart

import 'package:isar/isar.dart';

part 'deletion.g.dart';

@collection
class Deletion {
  Id id = Isar.autoIncrement;

  late String tableName;
  late String deletedRecordId; // supabaseId
  late DateTime deletedAt;
}
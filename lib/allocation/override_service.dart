// 文件: lib/allocation/override_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mapping.dart';

class OverrideService {
  static const _key = 'allocation_overrides';

  // 加载所有自定义设置
  Future<Map<String, AllocationBucket>> loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) {
      return {};
    }
    
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return jsonMap.map((assetId, bucketName) {
      final bucket = AllocationBucket.values.firstWhere(
        (b) => b.name == bucketName,
        orElse: () => AllocationBucket.other, // 如果找不到，给个默认值
      );
      return MapEntry(assetId, bucket);
    });
  }

  // 保存单个资产的自定义设置
  Future<void> saveOverride(int assetId, AllocationBucket bucket) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await loadOverrides();
    
    overrides[assetId.toString()] = bucket;
    
    // 将 Map<String, AllocationBucket> 转换为 Map<String, String> 以便序列化
    final jsonMap = overrides.map((key, value) => MapEntry(key, value.name));
    await prefs.setString(_key, json.encode(jsonMap));
  }
}
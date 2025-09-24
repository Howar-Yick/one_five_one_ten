// 文件: lib/allocation/mapping.dart
// (*** 关键修复：增加 id 和 overrides 参数，优先使用自定义分类 ***)

import 'allocation_service.dart'; // 导入服务以获取枚举

enum AllocationBucket { us, cn, hk, gold, oil, bondCash, other }

/// 根据代码、名称和（可选）子类型做地区/大类归桶。
AllocationBucket mapToBucket({
  required int id, // <-- 新增 id 参数
  required String code,
  required String name,
  String? subType,
  required Map<String, AllocationBucket> overrides, // <-- 新增 overrides 参数
}) {
  // --- [!!!] 优先检查用户自定义的分类 ---
  if (overrides.containsKey(id.toString())) {
    return overrides[id.toString()]!;
  }
  // --- [优先检查结束] ---


  final lowerName = name.toLowerCase();

  // --- 按名称关键字判断 ---
  const usKeywords = ['纳指', '纳斯达克', '标普', '美国'];
  if (usKeywords.any((keyword) => lowerName.contains(keyword))) {
    return AllocationBucket.us;
  }
  if (lowerName.contains('港股') || lowerName.contains('恒生')) {
    return AllocationBucket.hk;
  }
  if (lowerName.contains('黄金')) {
    return AllocationBucket.gold;
  }
  if (lowerName.contains('原油') || lowerName.contains('石油')) {
    return AllocationBucket.oil;
  }
  
  // —— 按代码判断（作为补充） ——
  const usCodes = {'159509','161128','162415','161130','159612', '968061', '000041'};
  if (usCodes.contains(code)) return AllocationBucket.us;

  const goldCodes = {'159934', '518880', '000216'};
  if (goldCodes.contains(code)) return AllocationBucket.gold;

  const oilCodes = {'161129', '160416', '162411'};
  if (oilCodes.contains(code)) return AllocationBucket.oil;

  const hkCodes = {'513230'};
  if (hkCodes.contains(code)) return AllocationBucket.hk;

  // —— 按子类型判断固收/理财 ——
  if (subType != null) {
    final s = subType.toLowerCase();
    if (s.contains('wealthmanagement') || s.contains('fixedincome') || s.contains('bond')) {
      return AllocationBucket.bondCash;
    }
  }
  
  const bondCodes = {'003191', '003376', '001077', '005436', '001702', '006113', '005879', '001859', '010554'};
  if (bondCodes.contains(code)) return AllocationBucket.bondCash;

  // 默认：A股/其他
  return AllocationBucket.cn;
}

String bucketLabel(AllocationBucket b) {
  switch (b) {
    case AllocationBucket.us: return '美股/美元';
    case AllocationBucket.cn: return 'A股/人民币';
    case AllocationBucket.hk: return '港股';
    case AllocationBucket.gold: return '黄金';
    case AllocationBucket.oil: return '原油';
    case AllocationBucket.bondCash: return '固收/现金';
    case AllocationBucket.other: return '其他';
  }
}
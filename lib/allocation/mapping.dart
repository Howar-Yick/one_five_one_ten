// 文件: lib/allocation/mapping.dart
// (这是 ChatGPT 的代码，稍作清理)

/// —— 安全的“归桶”规则 ——
/// 仅用于计算展示，不写库，不引入迁移。

enum AllocationBucket { us, cn, hk, gold, oil, bondCash, other }

/// 根据代码与（可选）子类型做地区/大类归桶。
/// 注：这里覆盖了你截图中的主要 ETF/LOF；其余未知就落到 cn/other，保证安全。
AllocationBucket mapToBucket({
  required String code,
  String? subType, // 你模型里若有 AssetSubType，可传进来做加强
}) {
  // —— 美股相关（纳指/标普/消费/信息科技等）——
  // (我根据你的截图和日志更新了代码)
  const us = {
    '159509', // 纳指科技ETF
    '161128', // 海外科技LOF
    '162415', // 美国消费
    '159612', // 标普科技
    '005299', // 嘉实美国成长 (场外)
    '161130', // 纳斯达克100LOF
    '160213', // 国泰纳斯达克100 (场外)
    '003735', // 南方纳斯达克100 (场外)
    '006479', // 招商纳斯达克100 (场外)
    '006475', // 嘉实纳斯达克100 (场外)
    '000966', // 易方达标普500人民币 (场外)
    '100061', // 华夏标普500ETF (场外)
    '002621', // 大成标普500等权重 (场外)
    '001092', // 汇添富纳斯达克生物科技 (场外)
    '000071', // 华宝美国消费 (场外)
    '513500', // 标普500ETF
  };
  if (us.contains(code)) return AllocationBucket.us;
  
  // (来自你日志的美元基金)
  if (code == '968061' || code == '000041') return AllocationBucket.us;


  // —— 黄金 ——（常见 518850/518880）
  const gold = {'159934', '518880', '000216'};
  if (gold.contains(code)) return AllocationBucket.gold;

  // —— 原油 ——（常见 161129 等）
  const oil = {'161129', '160416', '162411'};
  if (oil.contains(code)) return AllocationBucket.oil;

  // —— 港股 ——（如 513230）
  if (code == '513230') return AllocationBucket.hk;

  // —— 固收/理财（如果上层传了子类型）——
  if (subType != null) {
    final s = subType.toLowerCase();
    // (我们用这个来捕获所有 "理财" 和 "债券基金")
    if (s.contains('wealthmanagement') || s.contains('fixedincome') || s.contains('bond')) {
      return AllocationBucket.bondCash;
    }
    // (以防万一，用子类型再次检查)
    if (s.contains('gold')) return AllocationBucket.gold;
    if (s.contains('oil') || s.contains('energy')) return AllocationBucket.oil;
  }
  
  // (你的债券基金)
  const bond = {'003191', '003376', '001077', '005436', '001702', '006113', '005879', '001859', '010554'};
  if (bond.contains(code)) return AllocationBucket.bondCash;


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
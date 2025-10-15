// File: lib/utils/timezone.dart
// Version: CHATGPT-1.04-20251014-TZ-FIX
//
// 统一时区处理工具：
// - 所有入库（Supabase）时间用 toUtc()
// - 所有出库显示用 toLocal()
// - 图表 X 轴一律采样到 “UTC 当天 00:00”的毫秒数

/// 将任何时间归一到 “UTC 的当天 00:00:00.000”
DateTime utcDateOnly(DateTime dt) {
  final d = dt.isUtc ? dt : dt.toUtc();
  return DateTime.utc(d.year, d.month, d.day);
}

/// 图表 X 轴用的 double（毫秒 since epoch，UTC 零点）
double utcDateEpoch(DateTime dt) => utcDateOnly(dt).millisecondsSinceEpoch.toDouble();

/// 入库（Supabase）统一使用 UTC
DateTime toSupa(DateTime dt) => dt.toUtc();

/// 出库显示统一使用本地时区
DateTime fromSupa(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

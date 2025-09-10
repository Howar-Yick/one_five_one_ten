// lib/utils/xirr.dart
//
// 纯 Dart 的 XIRR / XNPV 实现：
// - xnpv(rate, dates, values)
// - xirr(dates, values, {guess, maxIterations, tolerance})
//
// 用法示例：
//   final dates = <DateTime>[DateTime(2023,1,1), DateTime(2023,6,1), DateTime(2024,1,1)];
//   final values = <double>[-10000, 1200, 9500];
//   final irr = xirr(dates, values); // 返回年化收益率(小数)，如 0.085 表示 8.5%
//
// 说明：
// - dates.length 必须等于 values.length，且包含至少两个不同日期；
// - values 中正负要有变化（至少一个为负、一个为正），否则数学上没有解；
// - 时间按实际/365 计息；
// - 为了鲁棒性，先尝试 Newton-Raphson，失败则做区间二分搜索。
// - 本实现偏工程稳定：输入异常会抛出 ArgumentError；Newton 收敛失败会自动切换二分法。

import 'dart:math' as math;

/// 计算 XNPV：在指定贴现率 [rate] 下，现金流 [values] 相对首日的净现值。
/// [dates] 与 [values] 等长，dates[0] 被视为基准日。
double xnpv(
  double rate,
  List<DateTime> dates,
  List<double> values,
) {
  if (dates.length != values.length) {
    throw ArgumentError('dates.length 必须等于 values.length');
  }
  if (dates.isEmpty) {
    throw ArgumentError('现金流不能为空');
  }
  final DateTime t0 = dates.first;
  double sum = 0.0;
  for (int i = 0; i < values.length; i++) {
    final double t = (dates[i].difference(t0).inDays) / 365.0;
    sum += values[i] / math.pow(1.0 + rate, t);
  }
  return sum;
}

/// 计算 d(XNPV)/d(rate)（Newton-Raphson 所需导数）。
double _dxnpv(
  double rate,
  List<DateTime> dates,
  List<double> values,
) {
  final DateTime t0 = dates.first;
  double sum = 0.0;
  for (int i = 0; i < values.length; i++) {
    final double t = (dates[i].difference(t0).inDays) / 365.0;
    // f = v * (1+r)^(-t)
    // df/dr = v * (-t) * (1+r)^(-t-1)
    sum += values[i] * (-t) * math.pow(1.0 + rate, -t - 1.0);
  }
  return sum;
}

/// 计算 XIRR：给定 [dates] 和 [values]（等长），返回年化收益率（小数）
/// [guess] 初始猜测值；[maxIterations] 最大迭代次数；[tolerance] 收敛阈值。
double xirr(
  List<DateTime> dates,
  List<double> values, {
  double guess = 0.1,
  int maxIterations = 50,
  double tolerance = 1e-7,
}) {
  if (dates.length != values.length) {
    throw ArgumentError('dates.length 必须等于 values.length');
  }
  if (dates.length < 2) {
    throw ArgumentError('至少需要两个现金流点');
  }
  // 至少有正有负，否则无解
  final bool hasPositive = values.any((v) => v > 0);
  final bool hasNegative = values.any((v) => v < 0);
  if (!hasPositive || !hasNegative) {
    throw ArgumentError('现金流需要同时包含正负值');
  }

  // 1) Newton-Raphson 迭代
  double rate = guess;
  for (int i = 0; i < maxIterations; i++) {
    final double f = xnpv(rate, dates, values);
    final double df = _dxnpv(rate, dates, values);
    if (df.abs() < 1e-16) break; // 导数过小，避免除零
    final double newRate = rate - f / df;
    if (!newRate.isFinite) break;
    if ((newRate - rate).abs() <= tolerance) {
      return newRate;
    }
    rate = newRate;
    // 避免越过 -1（无意义）
    if (rate <= -0.999999999) {
      rate = -0.999999999;
      break;
    }
  }

  // 2) 二分法兜底：在 [-0.999999, upper] 内寻找根
  double low = -0.999999;
  double high = 10.0; // 1000% 年化的上界，足够宽
  double fLow = xnpv(low, dates, values);
  double fHigh = xnpv(high, dates, values);

  // 如果同号，尝试扩展上界
  int expand = 0;
  while (fLow * fHigh > 0 && expand < 20) {
    high *= 1.5;
    fHigh = xnpv(high, dates, values);
    expand++;
  }

  // 依然同号，尝试缩小下界（接近 -1）
  int shrink = 0;
  while (fLow * fHigh > 0 && shrink < 20) {
    low = (low - 1.0) / 2.0; // 向 -1 再靠近一些
    if (low <= -0.999999999) {
      low = -0.999999999;
      break;
    }
    fLow = xnpv(low, dates, values);
    shrink++;
  }

  // 若仍未找到异号区间，返回 Newton 的近似结果
  if (fLow * fHigh > 0) {
    return rate;
  }

  // 二分搜索
  for (int i = 0; i < 100; i++) {
    final mid = (low + high) / 2.0;
    final fMid = xnpv(mid, dates, values);
    if (fMid.abs() <= tolerance) return mid;
    if (fLow * fMid < 0) {
      high = mid;
      fHigh = fMid;
    } else {
      low = mid;
      fLow = fMid;
    }
  }
  return (low + high) / 2.0;
}

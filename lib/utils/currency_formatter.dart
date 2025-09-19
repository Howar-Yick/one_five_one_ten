// 文件: lib/utils/currency_formatter.dart
// (这是正确的，无需修改)

import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/asset.dart'; // (确保这个 import 存在)

String getCurrencySymbol(String currencyCode) {
  switch (currencyCode) {
    case 'USD':
      return '\$';
    case 'HKD':
      return 'HK\$';
    case 'CNY':
    default:
      return '¥';
  }
}

String formatCurrency(double value, String currencyCode, {bool showSymbol = true}) {
  final format = NumberFormat.currency(
    locale: 'zh_CN',
    symbol: showSymbol ? getCurrencySymbol(currencyCode) : '',
    decimalDigits: 2, 
  );
  return format.format(value);
}

// --- 这是我们需要的函数 ---
String formatPrice(double price, AssetSubType subType) {
  if (price == 0) {
    return 'N/A';
  }

  switch (subType) {
    case AssetSubType.mutualFund: // 场外基金
      return price.toStringAsFixed(4); // 4 位小数
    case AssetSubType.etf: // 场内基金
      return price.toStringAsFixed(3); // 3 位小数
    case AssetSubType.stock: // 股票
    default:
      return price.toStringAsFixed(2); // 股票和其它默认 2 位
  }
}
// --- 函数结束 ---
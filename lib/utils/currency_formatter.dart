import 'package:intl/intl.dart';

// 定义我们支持的货币格式
final Map<String, NumberFormat> _formatters = {
  'CNY': NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2),
  'USD': NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2),
  'HKD': NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$', decimalDigits: 2),
  // ... 未来可以添加更多
};

// 用于基金净值、股价等的特殊格式化（不同小数位数）
final Map<String, NumberFormat> _priceFormatters = {
  'CNY_STOCK': NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2),
  'CNY_FUND': NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 4),
  'USD': NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2),
  'HKD': NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$', decimalDigits: 3),
};


/// 全局货币格式化函数
/// 格式化总金额（总是2位小数）
String formatCurrency(double amount, String currencyCode) {
  // 如果找不到对应的格式化工具，就用基础代码加金额
  if (!_formatters.containsKey(currencyCode)) {
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }
  return _formatters[currencyCode]!.format(amount);
}

/// 格式化价格（根据类型有不同的小数位数）
String formatPrice(double price, String currencyCode, String subType) {
  String key = currencyCode;
  if (currencyCode == 'CNY') {
    key = (subType == 'mutualFund') ? 'CNY_FUND' : 'CNY_STOCK';
  }
  
  if (!_priceFormatters.containsKey(key)) {
    return '${currencyCode} ${price.toStringAsFixed(3)}'; // 默认3位
  }
  return _priceFormatters[key]!.format(price);
}
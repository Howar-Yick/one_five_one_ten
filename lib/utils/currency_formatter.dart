import 'package:intl/intl.dart';

final Map<String, NumberFormat> _formatters = {
  'CNY': NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2),
  'USD': NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2),
  'HKD': NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$', decimalDigits: 2),
};

final Map<String, NumberFormat> _priceFormatters = {
  'CNY_STOCK': NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2),
  'CNY_FUND': NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 4),
  'USD': NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2),
  'HKD': NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$', decimalDigits: 3),
};

String formatCurrency(double amount, String currencyCode) {
  if (!_formatters.containsKey(currencyCode)) {
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }
  return _formatters[currencyCode]!.format(amount);
}

String formatPrice(double price, String currencyCode, String subTypeName) {
  String key = currencyCode;
  if (currencyCode == 'CNY') {
    key = (subTypeName == 'mutualFund') ? 'CNY_FUND' : 'CNY_STOCK';
  }
  
  if (!_priceFormatters.containsKey(key)) {
    return '${currencyCode} ${price.toStringAsFixed(3)}';
  }
  return _priceFormatters[key]!.format(price);
}

// --- 新增：获取货币符号的辅助函数 ---
String getCurrencySymbol(String currencyCode) {
  switch (currencyCode) {
    case 'CNY':
      return '¥ ';
    case 'USD':
      return '\$ ';
    case 'HKD':
      return 'HK\$ ';
    default:
      return '$currencyCode ';
  }
}
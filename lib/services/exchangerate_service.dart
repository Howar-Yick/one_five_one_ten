import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gbk_codec/gbk_codec.dart';
import 'package:flutter/foundation.dart';

class ExchangeRateService {
  // 缓存汇率，避免重复请求
  static final Map<String, double> _rateCache = {};

  void _log(String message) {
    if (kDebugMode) {
      print('[汇率服务 DEBUG] $message');
    }
  }

  // 获取从 'from' 币种到 'to' 币种的汇率
  // 目前我们只处理一个方向：外币 -> CNY
  Future<double> getRate(String fromCurrency, String toCurrency) async {
    // 1. 如果币种相同，汇率永远是 1
    if (fromCurrency == toCurrency) {
      return 1.0;
    }
    
    // 2. 我们的基础货币是CNY，所以我们只关心 外币 -> CNY
    // （将来如果基础货币可切换，这里的逻辑会更复杂）
    if (toCurrency != 'CNY') {
      _log('错误：目前只支持换算到 CNY');
      return 1.0; // 暂时返回1，避免计算崩溃
    }
    
    final rateSymbol = '${fromCurrency}${toCurrency}'; // 例如: USDCNY

    // 3. 检查缓存
    if (_rateCache.containsKey(rateSymbol)) {
      _log('从缓存中读取汇率: $rateSymbol');
      return _rateCache[rateSymbol]!;
    }
    
    // 4. 从新浪接口获取（注意：新浪的外汇接口没有sh或sz前缀）
    _log('正在从网络获取汇率: $rateSymbol');
    final url = Uri.parse('http://hq.sinajs.cn/list=$rateSymbol');

    try {
      final headers = {'Referer': 'https://finance.sina.com.cn'};
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final body = gbk.decode(response.bodyBytes);
        final parts = body.split('"')[1].split(',');

        // 新浪外汇接口的汇买价通常在索引 1
        if (parts.length > 1) {
          final rate = double.tryParse(parts[1]);
          if (rate != null) {
            _log('成功获取汇率: $rate');
            _rateCache[rateSymbol] = rate; // 存入缓存
            return rate;
          }
        }
      }
    } catch (e) {
      _log('!!! 汇率同步失败: $e');
    }

    // 如果所有都失败了，返回一个默认值1，避免计算崩溃
    _log('汇率获取失败，返回默认值 1.0');
    return 1.0;
  }
}
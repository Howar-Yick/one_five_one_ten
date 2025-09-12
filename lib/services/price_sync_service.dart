import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gbk_codec/gbk_codec.dart';
import 'package:one_five_one_ten/models/asset.dart';

class PriceSyncService {
  void _log(String message) {
    if (kDebugMode) {
      print('[壹伍壹拾 DEBUG] $message');
    }
  }

  Future<double?> syncPrice(Asset asset) async {
    _log('==================== 开始同步 ====================');
    _log('接收到资产: "${asset.name}", 代码: "${asset.code}", 类型: ${asset.subType}');

    switch (asset.subType) {
      case AssetSubType.stock:
      case AssetSubType.etf:
        return _syncFromSina(asset.code);
      case AssetSubType.mutualFund:
        return _syncFromTianTian(asset.code);
      default:
        _log('不支持的资产子类型');
        return null;
    }
  }

  

  Future<double?> _syncFromSina(String assetCode) async {
    if (assetCode.isEmpty) return null;

    String fullCode = assetCode.toLowerCase().trim();
    bool isPrefixed = fullCode.startsWith('sh') || fullCode.startsWith('sz');

    if (!isPrefixed) {
      if (fullCode.startsWith('6')) fullCode = 'sh$fullCode';
      else if (fullCode.startsWith('5')) fullCode = 'sh$fullCode';
      else if (fullCode.startsWith('0') || fullCode.startsWith('3')) fullCode = 'sz$fullCode';
      else if (fullCode.startsWith('1')) fullCode = 'sz$fullCode';
      else {
        _log('新浪接口错误：资产代码 "$assetCode" 不是有效的股票或场内基金代码。');
        return null; // 对于不匹配的规则，直接返回失败
      }
    }
    _log('新浪接口: 处理后代码 "$fullCode"');

    final url = Uri.parse('http://hq.sinajs.cn/list=$fullCode');
    try {
      final headers = {'Referer': 'https://finance.sina.com.cn'};
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final body = gbk.decode(response.bodyBytes);
        if (!body.contains('="') || body.split('"')[1].isEmpty) return null;
        
        final parts = body.split('"')[1].split(',');
        if (parts.length > 3) {
          final price = double.tryParse(parts[3]);
          _log('新浪接口: 成功获取价格 $price');
          return price;
        }
      }
    } catch (e) {
      _log('!!! 新浪接口捕获到异常: $e');
    }
    return null;
  }

  Future<double?> _syncFromTianTian(String assetCode) async {
    if (assetCode.isEmpty) return null;
    
    _log('天天基金接口: 开始处理代码 "$assetCode"');
    // 使用您提供的更可靠的新接口
    final url = Uri.parse('http://fund.eastmoney.com/pingzhongdata/$assetCode.js');
    _log('天天基金接口: 请求URL: $url');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      _log('天天基金接口: 收到响应，状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        String body = response.body;
        _log('天天基金接口: 原始响应体长度: ${body.length}');
        
        // --- 新增：更强大的解析逻辑，用于提取JS变量中的JSON数组 ---
        const startMarker = 'var Data_netWorthTrend = ';
        final startIndex = body.indexOf(startMarker);

        if (startIndex == -1) {
          _log('天天基金接口: 错误 - 响应体中未找到 "Data_netWorthTrend"');
          return null;
        }

        // 从标记开始处找到数组的结尾 '];'
        final endIndex = body.indexOf('];', startIndex);
        if (endIndex == -1) {
          _log('天天基金接口: 错误 - 未找到 "Data_netWorthTrend" 数组的结尾');
          return null;
        }

        // 提取出纯净的JSON数组字符串
        final jsonArrayString = body.substring(startIndex + startMarker.length, endIndex + 1);
        _log('天天基金接口: 提取出的JSON数组: $jsonArrayString');

        final List<dynamic> historyData = json.decode(jsonArrayString);
        
        if (historyData.isNotEmpty) {
          // 获取数组中最后一个元素，即最新的净值数据
          final latestData = historyData.last;
          final price = latestData['y'] as double?;
          _log('天天基金接口: 成功获取最新净值 $price');
          return price;
        } else {
           _log('天天基金接口: 错误 - 净值历史数组为空');
        }
      }
    } catch (e) {
      _log('!!! 天天基金接口捕获到异常: $e');
    }
    _log('!!! 天天基金接口: 同步失败');
    return null;
  }
}
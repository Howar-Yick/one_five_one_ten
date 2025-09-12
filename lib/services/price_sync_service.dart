import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gbk_codec/gbk_codec.dart';

void log(String message) {
  debugPrint('[壹伍壹拾 DEBUG] $message');
}

class PriceSyncService {
  Future<double?> syncPrice(String assetCode) async {
    // 为了简洁，日志函数省略，但您的文件中应该保留
    print('[壹伍壹拾 DEBUG] ==================== 开始同步 ====================');
    print('[壹伍壹拾 DEBUG] 接收到原始资产代码: "$assetCode"');

    if (assetCode.isEmpty) {
      print('[壹伍壹拾 DEBUG] 错误：资产代码为空，同步中止。');
      return null;
    }

    String fullCode = assetCode.toLowerCase().trim();
    if (!fullCode.startsWith('sh') && !fullCode.startsWith('sz')) {
      if (fullCode.startsWith('6')) {
        fullCode = 'sh$fullCode'; // 沪市A股
      } else if (fullCode.startsWith('5')) {
        fullCode = 'sh$fullCode'; // 沪市基金/ETF
      } else if (fullCode.startsWith('0') || fullCode.startsWith('3')) {
        fullCode = 'sz$fullCode'; // 深市A股
      } else if (fullCode.startsWith('1')) {
        fullCode = 'sz$fullCode'; // 深市基金/ETF
      } else {
        print('[壹伍壹拾 DEBUG] 错误：未知的资产代码格式，无法添加sh/sz前缀。');
        return null;
      }
    }
    print('[壹伍壹拾 DEBUG] 处理后的完整代码: "$fullCode"');

    final url = Uri.parse('http://hq.sinajs.cn/list=$fullCode');
    print('[壹伍壹拾 DEBUG] 请求URL: $url');
    
    try {
      final headers = {
        'Referer': 'https://finance.sina.com.cn',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      print('[壹伍壹拾 DEBUG] 收到服务器响应，状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = gbk.decode(response.bodyBytes);
        print('[壹伍壹拾 DEBUG] GBK解码后的原始响应体: $body');
        
        if (!body.contains('="') || body.split('"')[1].isEmpty) {
          print('[壹伍壹拾 DEBUG] 错误：响应体格式不正确或数据为空。');
          return null;
        }

        final dataString = body.split('"')[1];
        final parts = dataString.split(',');
        
        // --- 关键修正：对于股票和场内基金，实时价格都在索引3 ---
        if (parts.length > 3) {
          print('[壹伍壹拾 DEBUG] 尝试解析 parts[3] 作为当前价格: "${parts[3]}"');
          final price = double.tryParse(parts[3]);
          print('[壹伍壹拾 DEBUG] 解析出的价格: $price');
          print('[壹伍壹拾 DEBUG] ==================== 同步结束 ====================');
          return price;
        } else {
          print('[壹伍壹拾 DEBUG] 错误：数据数组长度不足4。');
        }
      } else {
        print('[壹伍壹拾 DEBUG] 错误：服务器返回了非200的状态码。');
      }
    } catch (e) {
      print('[壹伍壹拾 DEBUG] !!! 捕获到异常: $e');
    }
    
    print('[壹伍壹拾 DEBUG] !!! 同步失败，最终返回 null。');
    print('[壹伍壹拾 DEBUG] ==================== 同步结束 ====================');
    return null;
  }
}
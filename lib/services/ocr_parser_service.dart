import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParserService {
  // ★ 升级：接收 Map<资产ID, 搜索关键词列表(代码+名称)>，返回 Map<资产ID, 提取数据>
  Future<Map<int, Map<String, double>>> parseGuojinScreenshot(
    String imagePath,
    Map<int, List<String>> assetSearchKeys,
  ) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    final result = <int, Map<String, double>>{};

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);

      List<TextElement> allElements = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            allElements.add(element);
          }
        }
      }

      // 1. 聚合成行 (Y 坐标差值 < 15 视作同一行)
      List<List<TextElement>> rows = [];
      for (final element in allElements) {
        bool placed = false;
        for (final row in rows) {
          if (row.isNotEmpty) {
            final rowY = row.first.boundingBox.top;
            if ((element.boundingBox.top - rowY).abs() < 15) {
              row.add(element);
              placed = true;
              break;
            }
          }
        }
        if (!placed) {
          rows.add([element]);
        }
      }

      // 2. 排序：自上而下，自左而右
      rows.sort(
        (a, b) => a.first.boundingBox.top.compareTo(b.first.boundingBox.top),
      );
      for (final row in rows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      }

      // 3. 状态机解析：用【ID】绝对锚定当前资产
      int? currentAssetId;

      for (final row in rows) {
        if (row.isEmpty) continue;
        final lineText = row.map((e) => e.text).join(' ');
        print("OCR 扫描行数据: $lineText");

        // 清除所有空格转小写，用于暴力匹配，兼容 6 位代码被识别为带空格格式
        final normalizedLineText = lineText.replaceAll(RegExp(r'\s+'), '');
        final cleanLine = normalizedLineText.toLowerCase();

        // ★ 核心升级：遍历所有的资产的 搜索词(代码 / 名称)
        for (final entry in assetSearchKeys.entries) {
          final assetId = entry.key;
          final searchWords = entry.value;

          bool matched = false;
          for (final word in searchWords) {
            final normalizedWord = word.replaceAll(RegExp(r'\s+'), '');
            final cleanWord = normalizedWord.toLowerCase();
            if (cleanWord.isNotEmpty && cleanLine.contains(cleanWord)) {
              matched = true;
              break;
            }
          }

          if (matched) {
            currentAssetId = assetId; // 锁定 ID！
            result.putIfAbsent(currentAssetId, () => {});
            break;
          }
        }

        if (currentAssetId != null) {
          // ★ 锚点 1：提取 成本 和 综合收益
          if (lineText.contains('成本/现价')) {
            final parts = lineText.split('成本/现价');
            if (parts.length == 2) {
              final profit = _parseDouble(parts[0]);
              if (profit != null) result[currentAssetId]!['profit'] = profit;

              final costStr = parts[1].trim().split('/')[0];
              final cost = _parseDouble(costStr);
              if (cost != null) result[currentAssetId]!['cost'] = cost;
            }
          }

          // ★ 锚点 2：提取 最新份额
          if (lineText.contains('持仓/可用')) {
            final parts = lineText.split('持仓/可用');
            if (parts.length == 2) {
              final shareStr = parts[1].trim().split('/')[0];
              final shares = _parseDouble(shareStr);
              if (shares != null) result[currentAssetId]!['shares'] = shares;
            }
          }
        }
      }
    } catch (e) {
      print("OCR Error: $e");
    } finally {
      recognizer.close();
    }

    return result;
  }

  double? _parseDouble(String text) {
    final match = RegExp(r'-?[\d,]+(\.\d+)?').firstMatch(text);
    if (match != null) {
      String numStr = match.group(0)!.replaceAll(',', '');
      return double.tryParse(numStr);
    }
    return null;
  }
}

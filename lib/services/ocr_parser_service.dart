import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParserService {
  // ★ 新增：用于在手机端透视机器到底看到了什么
  static String debugRawText = "";

  Future<Map<int, Map<String, double>>> parseGuojinScreenshot(
    String imagePath,
    Map<int, List<String>> assetSearchKeys,
  ) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    final result = <int, Map<String, double>>{};
    debugRawText = ""; // 每次扫描前清空

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);

      List<TextElement> allElements = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          allElements.addAll(line.elements);
        }
      }

      // 1. 聚合成行 (误差 < 15)
      List<List<TextElement>> rows = [];
      for (final element in allElements) {
        bool placed = false;
        for (final row in rows) {
          if (row.isNotEmpty &&
              (element.boundingBox.top - row.first.boundingBox.top).abs() <
                  15) {
            row.add(element);
            placed = true;
            break;
          }
        }
        if (!placed) rows.add([element]);
      }

      // 2. 排序
      rows.sort(
        (a, b) => a.first.boundingBox.top.compareTo(b.first.boundingBox.top),
      );
      for (final row in rows)
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

      int? currentAssetId;

      for (final row in rows) {
        if (row.isEmpty) continue;
        String originalLineText = row.map((e) => e.text).join(' ');

        // ★ 记录原始文本，供弹窗 Debug 使用
        debugRawText += originalLineText + "\n";

        String cleanLine = originalLineText.replaceAll(' ', '').toLowerCase();

        for (final entry in assetSearchKeys.entries) {
          final assetId = entry.key;
          bool matched = false;

          for (final word in entry.value) {
            if (word.isEmpty) continue;
            final cleanWord = word.replaceAll(' ', '').toLowerCase();
            // 只要行内包含这个词，就认定匹配成功
            if (cleanLine.contains(cleanWord)) {
              matched = true;
              break;
            }
          }

          if (matched) {
            currentAssetId = assetId;
            result.putIfAbsent(currentAssetId, () => {});
            break;
          }
        }

        if (currentAssetId != null) {
          if (originalLineText.contains('成本/现价')) {
            final parts = originalLineText.split('成本/现价');
            if (parts.length == 2) {
              final profit = _parseDouble(parts[0]);
              if (profit != null) result[currentAssetId]!['profit'] = profit;
              final costStr = parts[1].trim().split('/')[0];
              final cost = _parseDouble(costStr);
              if (cost != null) result[currentAssetId]!['cost'] = cost;
            }
          }
          if (originalLineText.contains('持仓/可用')) {
            final parts = originalLineText.split('持仓/可用');
            if (parts.length == 2) {
              final shareStr = parts[1].trim().split('/')[0];
              final shares = _parseDouble(shareStr);
              if (shares != null) result[currentAssetId]!['shares'] = shares;
            }
          }
        }
      }
    } catch (e) {
      debugRawText += "\nError: $e";
    } finally {
      recognizer.close();
    }
    return result;
  }

  double? _parseDouble(String text) {
    final match = RegExp(r'-?[\d,]+(\.\d+)?').firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(0)!.replaceAll(',', ''));
    }
    return null;
  }
}

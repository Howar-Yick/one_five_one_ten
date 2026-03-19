import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParserService {
  Future<Map<String, Map<String, double>>> parseGuojinScreenshot(
      String imagePath, List<String> assetNames) async {
    // 强制使用中文语言包进行识别
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    final result = <String, Map<String, double>>{};

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);

      // 1. 将所有识别到的文本块打散为一个个基础元素
      List<TextElement> allElements = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            allElements.add(element);
          }
        }
      }

      // 2. 按 Y 坐标聚合成行 (误差 15 像素以内的算同一行)
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

      // 3. 排序：行按 Y 排序，行内的元素按 X (从左到右) 排序
      rows.sort(
          (a, b) => a.first.boundingBox.top.compareTo(b.first.boundingBox.top));
      for (final row in rows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      }

      // 4. 解析匹配：找到资产名称，然后取对应的列
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final firstText = row.first.text;

        for (final assetName in assetNames) {
          // 模糊匹配资产名
          if (firstText.contains(assetName) || assetName.contains(firstText)) {
            double? shares;
            double? profit;
            double? cost;

            // 国金第一行特征：名称 | 盈亏 | 份额 | 最新价
            if (row.length >= 3) {
              profit = _parseDouble(row[1].text);
              shares = _parseDouble(row[2].text);
            }

            // 国金第二行特征：市值 | 比例 | 可用份额 | 单位成本
            if (i + 1 < rows.length) {
              final nextRow = rows[i + 1];
              if (nextRow.length >= 4) {
                cost = _parseDouble(nextRow[3].text);
              }
            }

            if (shares != null || cost != null || profit != null) {
              result[assetName] = {
                if (shares != null) 'shares': shares,
                if (cost != null) 'cost': cost,
                if (profit != null) 'profit': profit,
              };
            }
            break;
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

  // 数字清洗：把逗号、百分号等杂质去掉，安全转为 double
  double? _parseDouble(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned);
  }
}

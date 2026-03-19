import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParserService {
  Future<Map<String, Map<String, double>>> parseGuojinScreenshot(
    String imagePath,
    List<String> assetNames,
  ) async {
    if (imagePath.isEmpty || assetNames.isEmpty) {
      return {};
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);

      final tokens = <_OcrToken>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.elements.isEmpty) {
            final text = line.text.trim();
            if (text.isNotEmpty) {
              tokens.add(
                _OcrToken(text: text, boundingBox: line.boundingBox),
              );
            }
            continue;
          }

          for (final element in line.elements) {
            final text = element.text.trim();
            if (text.isEmpty) {
              continue;
            }
            tokens.add(
              _OcrToken(text: text, boundingBox: element.boundingBox),
            );
          }
        }
      }

      if (tokens.isEmpty) {
        return {};
      }

      final rows = _groupTokensToRows(tokens);
      final normalizedAssetNames = {
        for (final name in assetNames) _normalizeAssetName(name): name,
      };

      final parsed = <String, Map<String, double>>{};
      for (int index = 0; index < rows.length; index++) {
        final currentRow = rows[index];
        if (currentRow.tokens.isEmpty) {
          continue;
        }

        final firstText = currentRow.tokens.first.text;
        final matchedAssetName =
            _findMatchedAssetName(firstText, normalizedAssetNames);
        if (matchedAssetName == null) {
          continue;
        }

        final nextRow = index + 1 < rows.length ? rows[index + 1] : null;
        final profit = currentRow.valueAt(1);
        final shares = currentRow.valueAt(2);
        final cost = nextRow?.valueAt(3);

        if (shares == null || cost == null) {
          continue;
        }

        parsed[matchedAssetName] = {
          'shares': shares,
          'cost': cost,
          if (profit != null) 'profit': profit,
        };
      }

      return parsed;
    } finally {
      await recognizer.close();
    }
  }

  List<_OcrRow> _groupTokensToRows(List<_OcrToken> tokens) {
    final sortedTokens = [...tokens]
      ..sort((a, b) => a.centerY.compareTo(b.centerY));

    final rows = <_OcrRow>[];
    for (final token in sortedTokens) {
      if (rows.isEmpty) {
        rows.add(_OcrRow(tokens: [token]));
        continue;
      }

      final lastRow = rows.last;
      if ((token.centerY - lastRow.averageCenterY).abs() <= 15) {
        lastRow.tokens.add(token);
      } else {
        rows.add(_OcrRow(tokens: [token]));
      }
    }

    for (final row in rows) {
      row.tokens.sort((a, b) => a.centerX.compareTo(b.centerX));
    }

    return rows;
  }

  String? _findMatchedAssetName(
    String text,
    Map<String, String> normalizedAssetNames,
  ) {
    final normalizedText = _normalizeAssetName(text);
    if (normalizedText.isEmpty) {
      return null;
    }

    if (normalizedAssetNames.containsKey(normalizedText)) {
      return normalizedAssetNames[normalizedText];
    }

    for (final entry in normalizedAssetNames.entries) {
      if (normalizedText.contains(entry.key) || entry.key.contains(normalizedText)) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalizeAssetName(String input) {
    return input.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }
}

class _OcrToken {
  _OcrToken({required this.text, required this.boundingBox});

  final String text;
  final Rect boundingBox;

  double get centerX => boundingBox.center.dx;
  double get centerY => boundingBox.center.dy;
}

class _OcrRow {
  _OcrRow({required this.tokens});

  final List<_OcrToken> tokens;

  double get averageCenterY {
    if (tokens.isEmpty) return 0;
    final sum = tokens.fold<double>(0, (prev, token) => prev + token.centerY);
    return sum / tokens.length;
  }

  double? valueAt(int index) {
    if (index < 0 || index >= tokens.length) {
      return null;
    }
    return _parseNumber(tokens[index].text);
  }

  double? _parseNumber(String raw) {
    final cleaned = raw
        .replaceAll(',', '')
        .replaceAll('%', '')
        .replaceAll('％', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9+\-.]'), '');

    if (cleaned.isEmpty || cleaned == '-' || cleaned == '+' || cleaned == '.' || cleaned == '-.' || cleaned == '+.') {
      return null;
    }
    return double.tryParse(cleaned);
  }
}

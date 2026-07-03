import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result of scanning a purchase receipt via on-device OCR.
///
/// All fields are best-effort pre-fills — the UI must let the user
/// review and edit before submitting.
class ReceiptScanResult {
  final String rawText;
  final double? totalAmount;
  final String? merchant;
  final DateTime? purchaseDate;

  ReceiptScanResult({
    required this.rawText,
    this.totalAmount,
    this.merchant,
    this.purchaseDate,
  });

  bool get foundAnything =>
      totalAmount != null || merchant != null || purchaseDate != null;
}

/// Service for extracting amount/merchant/date from receipt photos using
/// on-device ML Kit text recognition (same stack as PrescriptionScanService).
class ReceiptScanService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Run OCR on an already-captured receipt photo and parse fields.
  Future<ReceiptScanResult> scanReceiptFile(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;
    debugPrint('Receipt OCR raw text:\n$rawText');
    return parseRawText(rawText);
  }

  /// Parse recognized text into structured receipt fields.
  /// Exposed for unit testing.
  ReceiptScanResult parseRawText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ReceiptScanResult(
      rawText: rawText,
      totalAmount: _extractTotal(lines, rawText),
      merchant: _extractMerchant(lines),
      purchaseDate: _extractDate(rawText),
    );
  }

  /// Extract the receipt total.
  ///
  /// Strategy: prefer an amount on (or adjacent to) a line containing
  /// "total" (but not "subtotal"); fall back to the largest currency
  /// amount on the receipt, which on real receipts is almost always the
  /// total or the amount tendered.
  double? _extractTotal(List<String> lines, String rawText) {
    final amountPattern = RegExp(r'\$?\s*(\d{1,6}(?:[.,]\d{2}))\b');

    double? parseAmount(String s) {
      final m = amountPattern.firstMatch(s);
      if (m == null) return null;
      return double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }

    // Pass 1: "TOTAL" lines (skip subtotal / tax / total savings).
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      final isTotalLine = lower.contains('total') &&
          !lower.contains('subtotal') &&
          !lower.contains('sub total') &&
          !lower.contains('total savings') &&
          !lower.contains('total discount');
      if (!isTotalLine) continue;

      // Amount may be on the same line, or OCR puts it on the next line.
      final sameLine = parseAmount(lines[i]);
      if (sameLine != null) return sameLine;
      if (i + 1 < lines.length) {
        final nextLine = parseAmount(lines[i + 1]);
        if (nextLine != null) return nextLine;
      }
    }

    // Pass 2: largest amount anywhere on the receipt.
    double? largest;
    for (final m in amountPattern.allMatches(rawText)) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v == null) continue;
      if (largest == null || v > largest) largest = v;
    }
    return largest;
  }

  /// Merchant is usually the first prominent line that isn't an address,
  /// phone number, or date.
  String? _extractMerchant(List<String> lines) {
    for (final line in lines.take(4)) {
      if (line.length < 3 || line.length > 40) continue;
      // Skip addresses, phone numbers, dates, times, store numbers.
      if (RegExp(r'\d{3}[-.\s]?\d{3,4}').hasMatch(line)) continue;
      if (RegExp(r'\d{1,5}\s+\w+\s+(?:st|ave|blvd|rd|dr|ln|way|hwy)\b',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      if (RegExp(r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}').hasMatch(line)) continue;
      if (RegExp(r'store\s*#?\s*\d+', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      // Needs at least a couple of letters to be a name.
      if (!RegExp(r'[A-Za-z]{3,}').hasMatch(line)) continue;
      return _titleCase(line);
    }
    return null;
  }

  /// Extract the purchase date (US formats: MM/DD/YYYY, MM-DD-YY, etc.).
  DateTime? _extractDate(String text) {
    final match = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b')
        .firstMatch(text);
    if (match == null) return null;

    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 100) year += 2000;
    if (year < 2000 || year > DateTime.now().year + 1) return null;

    final date = DateTime(year, month, day);
    // A purchase date in the future is an OCR misread — reject it.
    if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) return null;
    return date;
  }

  String _titleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  void dispose() {
    _textRecognizer.close();
  }
}

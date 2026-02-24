import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Result of scanning a prescription label via OCR.
class PrescriptionScanResult {
  final String rawText;
  final String? rxNumber;
  final String? medicationName;
  final String? dosage;
  final String? frequency;
  final String? prescribedBy;
  final String? pharmacyName;
  final String? instructions;
  final int? quantity;
  final int? refills;

  PrescriptionScanResult({
    required this.rawText,
    this.rxNumber,
    this.medicationName,
    this.dosage,
    this.frequency,
    this.prescribedBy,
    this.pharmacyName,
    this.instructions,
    this.quantity,
    this.refills,
  });
}

/// Service for scanning prescription labels using on-device OCR.
class PrescriptionScanService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();

  /// Capture a photo and extract prescription text.
  Future<PrescriptionScanResult?> scanFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
    );
    if (image == null) return null;
    return _processImage(File(image.path));
  }

  /// Pick an existing photo and extract prescription text.
  Future<PrescriptionScanResult?> scanFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return null;
    return _processImage(File(image.path));
  }

  /// Process an image file through OCR and parse fields.
  Future<PrescriptionScanResult> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;

    debugPrint('OCR raw text:\n$rawText');

    return _parseRawText(rawText);
  }

  /// Parse recognized text into structured prescription fields.
  PrescriptionScanResult _parseRawText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return PrescriptionScanResult(
      rawText: rawText,
      rxNumber: _extractRxNumber(rawText),
      medicationName: _extractMedicationName(lines),
      dosage: _extractDosage(rawText),
      frequency: _extractFrequency(rawText),
      prescribedBy: _extractDoctor(rawText),
      pharmacyName: _extractPharmacy(lines),
      instructions: _extractInstructions(rawText),
      quantity: _extractQuantity(rawText),
      refills: _extractRefills(rawText),
    );
  }

  /// Extract RX / prescription number.
  String? _extractRxNumber(String text) {
    // Common patterns: "Rx# 1234567", "RX: 1234567", "Rx 1234567", "#1234567"
    final patterns = [
      RegExp(r'[Rr][Xx]\s*#?\s*:?\s*(\d{5,12})'),
      RegExp(r'[Pp]rescription\s*#?\s*:?\s*(\d{5,12})'),
      RegExp(r'#\s*(\d{7,12})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Extract medication name — usually the largest/bold text or follows "MEDICATION:" label.
  String? _extractMedicationName(List<String> lines) {
    // Look for explicit label first
    for (final line in lines) {
      final labelMatch = RegExp(
        r'(?:medication|drug|med)\s*:?\s*(.+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (labelMatch != null) {
        return _cleanField(labelMatch.group(1));
      }
    }

    // Heuristic: medication names are typically uppercase, contain dosage suffix
    for (final line in lines) {
      if (RegExp(r'^[A-Z][A-Z\s\-]+\d+\s*(?:mg|mcg|ml|g)\b', caseSensitive: false)
          .hasMatch(line)) {
        // Strip the dosage portion for just the name
        final nameOnly = line.replaceAll(
          RegExp(r'\s*\d+\s*(?:mg|mcg|ml|g)\b.*', caseSensitive: false),
          '',
        );
        return _cleanField(nameOnly);
      }
    }

    // Fallback: look for all-caps line that isn't a pharmacy header or address
    for (final line in lines) {
      if (line == line.toUpperCase() &&
          line.length > 3 &&
          line.length < 40 &&
          !RegExp(r'pharmacy|drug\s*store|cvs|walgreens|rite\s*aid', caseSensitive: false)
              .hasMatch(line) &&
          !RegExp(r'\d{5}').hasMatch(line)) {
        return _cleanField(line);
      }
    }

    return null;
  }

  /// Extract dosage (e.g., "10mg", "500 MG", "0.5 ml").
  String? _extractDosage(String text) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mg|mcg|ml|g|units?|iu)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)!.toUpperCase()}';
    }
    return null;
  }

  /// Extract frequency / directions (e.g., "Take 1 tablet twice daily").
  String? _extractFrequency(String text) {
    final patterns = [
      RegExp(
        r'(?:take|use|apply|inject)\s+.{5,60}(?:daily|twice|three|every|once|bedtime|morning|evening|as\s+needed)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:once|twice|three\s+times?|every\s+\d+\s+hours?)\s+(?:a\s+)?(?:day|daily)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return _cleanField(match.group(0));
    }
    return null;
  }

  /// Extract prescriber / doctor name.
  String? _extractDoctor(String text) {
    final patterns = [
      RegExp(r'(?:prescriber|physician|doctor|prescribed\s+by|dr\.?)\s*:?\s*(.+)', caseSensitive: false),
      RegExp(r'\b[Dd][Rr]\.?\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+){0,2})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return _cleanField(match.group(1));
    }
    return null;
  }

  /// Extract pharmacy name — often first 1-2 lines.
  String? _extractPharmacy(List<String> lines) {
    final pharmacyKeywords = [
      'pharmacy', 'drug', 'cvs', 'walgreens', 'rite aid', 'walmart',
      'costco', 'kroger', 'publix', 'safeway', 'albertsons',
    ];
    for (final line in lines.take(5)) {
      for (final kw in pharmacyKeywords) {
        if (line.toLowerCase().contains(kw)) {
          return _cleanField(line);
        }
      }
    }
    return null;
  }

  /// Extract usage instructions.
  String? _extractInstructions(String text) {
    final match = RegExp(
      r'(?:instructions?|directions?|sig)\s*:?\s*(.{10,120})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return _cleanField(match.group(1));
    return null;
  }

  /// Extract quantity dispensed.
  int? _extractQuantity(String text) {
    final match = RegExp(
      r'(?:qty|quantity|disp(?:ensed)?)\s*:?\s*#?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  /// Extract refills remaining.
  int? _extractRefills(String text) {
    final match = RegExp(
      r'(?:refills?)\s*:?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  String? _cleanField(String? value) {
    if (value == null) return null;
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? null : cleaned;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

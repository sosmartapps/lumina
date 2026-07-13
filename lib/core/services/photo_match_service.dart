import 'dart:io';

import 'package:image/image.dart' as img;

/// Cheap on-device photo verification via perceptual hashing (dHash).
///
/// Cost-first design (2026-07-12): the FIRST AI-verified completion photo
/// for a reminder becomes its reference hash; every later completion photo
/// is compared to that reference ON DEVICE — a match verifies for free,
/// and Claude vision only runs when there is no reference yet or the
/// match is inconclusive.
class PhotoMatchService {
  /// Hamming distance (of 64 bits) at or below which two photos are
  /// considered to show the same completed state. Conservative on
  /// purpose: a false "verified" is worse than one cheap AI fallback.
  static const int matchThreshold = 10;

  /// 64-bit difference hash of an image file, as a 16-char hex string.
  /// Grayscale → 9x8 → each bit = "is this pixel brighter than the next".
  /// Robust to overall lighting shifts; cheap (one decode + resize).
  static Future<String?> computeDHash(File file) async {
    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) return null;
      final small = img.copyResize(
        img.grayscale(decoded),
        width: 9,
        height: 8,
        interpolation: img.Interpolation.average,
      );
      var hash = 0;
      var bit = 0;
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          final a = small.getPixel(x, y).luminance;
          final b = small.getPixel(x + 1, y).luminance;
          if (a > b) hash |= 1 << bit;
          bit++;
        }
      }
      return hash.toRadixString(16).padLeft(16, '0');
    } catch (_) {
      return null; // hashing is best-effort — never block completion
    }
  }

  /// Bits differing between two dHash hex strings (0–64). Returns null if
  /// either hash is missing/malformed.
  static int? hammingDistance(String? a, String? b) {
    if (a == null || b == null) return null;
    final ia = int.tryParse(a, radix: 16);
    final ib = int.tryParse(b, radix: 16);
    if (ia == null || ib == null) return null;
    var x = ia ^ ib;
    var count = 0;
    while (x != 0) {
      count += x & 1;
      x >>>= 1;
    }
    return count;
  }

  /// True when [hash] matches [referenceHash] closely enough to verify
  /// on-device without any AI call.
  static bool matches(String? hash, String? referenceHash) {
    final d = hammingDistance(hash, referenceHash);
    return d != null && d <= matchThreshold;
  }
}

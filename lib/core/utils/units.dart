import 'dart:ui' show PlatformDispatcher;

/// Measurement system for displaying height/weight (and future distances).
/// Data is ALWAYS stored metric in Firestore; conversion happens at the UI.
enum UnitsSystem { metric, imperial }

class Units {
  /// Countries that use imperial/US customary units.
  static const _imperialCountries = {'US', 'LR', 'MM'};

  /// Resolve the effective system from a stored preference:
  /// 'imperial' / 'metric' are explicit; anything else ('auto', null)
  /// follows the device region.
  static UnitsSystem resolve(String? preference) {
    switch (preference) {
      case 'imperial':
        return UnitsSystem.imperial;
      case 'metric':
        return UnitsSystem.metric;
      default:
        final country =
            PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
        return _imperialCountries.contains(country)
            ? UnitsSystem.imperial
            : UnitsSystem.metric;
    }
  }

  // ── Height ──────────────────────────────────────────────
  static const double cmPerInch = 2.54;

  static ({int feet, int inches}) cmToFeetInches(double cm) {
    final totalInches = (cm / cmPerInch).round();
    return (feet: totalInches ~/ 12, inches: totalInches % 12);
  }

  static double feetInchesToCm(int feet, int inches) =>
      (feet * 12 + inches) * cmPerInch;

  /// e.g. 5'11" or 180 cm
  static String formatHeight(double? cm, UnitsSystem units) {
    if (cm == null) return '—';
    if (units == UnitsSystem.metric) return '${cm.round()} cm';
    final h = cmToFeetInches(cm);
    return "${h.feet}'${h.inches}\"";
  }

  // ── Weight ──────────────────────────────────────────────
  static const double lbPerKg = 2.20462;

  static double kgToLb(double kg) => kg * lbPerKg;
  static double lbToKg(double lb) => lb / lbPerKg;

  static String formatWeight(double? kg, UnitsSystem units) {
    if (kg == null) return '—';
    if (units == UnitsSystem.metric) return '${kg.round()} kg';
    return '${kgToLb(kg).round()} lb';
  }
}

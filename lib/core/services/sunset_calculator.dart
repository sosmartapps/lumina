import 'dart:math';

/// Pure Dart implementation of the NOAA simplified solar position algorithm.
/// Computes sunrise/sunset times from latitude, longitude, and date.
/// Accurate to ~1-2 minutes for most latitudes.
class SunsetCalculator {
  // Official sunset zenith angle (accounts for atmospheric refraction)
  static const double _zenith = 90.833;

  /// Returns the sunset DateTime in local time for the given location and date.
  /// Returns null if the sun never sets (polar regions during midnight sun).
  static DateTime? getSunsetTime({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) {
    return _calculate(
      latitude: latitude,
      longitude: longitude,
      date: date,
      isSunrise: false,
    );
  }

  /// Returns the sunrise DateTime in local time for the given location and date.
  /// Returns null if the sun never rises (polar regions during polar night).
  static DateTime? getSunriseTime({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) {
    return _calculate(
      latitude: latitude,
      longitude: longitude,
      date: date,
      isSunrise: true,
    );
  }

  static DateTime? _calculate({
    required double latitude,
    required double longitude,
    required DateTime date,
    required bool isSunrise,
  }) {
    // 1. Day of year
    final dayOfYear = _dayOfYear(date);

    // 2. Approximate time (fraction of day)
    final lngHour = longitude / 15.0;
    final t = isSunrise
        ? dayOfYear + ((6 - lngHour) / 24)
        : dayOfYear + ((18 - lngHour) / 24);

    // 3. Sun's mean anomaly
    final meanAnomaly = (0.9856 * t) - 3.289;

    // 4. Sun's true longitude
    var sunLng = meanAnomaly +
        (1.916 * _sin(meanAnomaly)) +
        (0.020 * _sin(2 * meanAnomaly)) +
        282.634;
    sunLng = _normalize(sunLng, 360);

    // 5. Right ascension
    var ra = _degrees(atan(0.91764 * tan(_radians(sunLng))));
    ra = _normalize(ra, 360);

    // Adjust RA to same quadrant as sun longitude
    final lQuadrant = (sunLng / 90).floor() * 90;
    final raQuadrant = (ra / 90).floor() * 90;
    ra += (lQuadrant - raQuadrant);

    // Convert RA to hours
    ra /= 15;

    // 6. Sun's declination
    final sinDec = 0.39782 * _sin(sunLng);
    final cosDec = cos(asin(sinDec));

    // 7. Hour angle
    final cosH = (cos(_radians(_zenith)) -
            (sinDec * sin(_radians(latitude)))) /
        (cosDec * cos(_radians(latitude)));

    // Sun never rises or sets at this latitude on this date
    if (cosH > 1) return null; // Sun never rises
    if (cosH < -1) return null; // Sun never sets

    // Calculate hour angle
    final h = isSunrise
        ? 360 - _degrees(acos(cosH))
        : _degrees(acos(cosH));
    final hHours = h / 15;

    // 8. Local mean time
    final localMeanTime = hHours + ra - (0.06571 * t) - 6.622;

    // 9. Adjust to UTC, tracking day overflow
    var utHours = localMeanTime - lngHour;
    int dayOffset = 0;
    while (utHours < 0) {
      utHours += 24;
      dayOffset--;
    }
    while (utHours >= 24) {
      utHours -= 24;
      dayOffset++;
    }

    // Convert to DateTime
    final hours = utHours.floor();
    final minutesFraction = (utHours - hours) * 60;
    final minutes = minutesFraction.floor();
    final seconds = ((minutesFraction - minutes) * 60).round();

    final utcTime = DateTime.utc(
      date.year,
      date.month,
      date.day + dayOffset,
      hours,
      minutes,
      seconds,
    );

    return utcTime.toLocal();
  }

  static int _dayOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    return date.difference(firstDay).inDays + 1;
  }

  static double _radians(double degrees) => degrees * pi / 180;
  static double _degrees(double radians) => radians * 180 / pi;
  static double _sin(double degrees) => sin(_radians(degrees));

  static double _normalize(double value, double max) {
    var result = value;
    while (result < 0) {
      result += max;
    }
    while (result >= max) {
      result -= max;
    }
    return result;
  }
}

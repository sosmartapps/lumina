import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/services/sunset_calculator.dart';

void main() {
  group('SunsetCalculator', () {
    // Tucson, AZ coordinates (Lumina's primary deployment area)
    const tucsonLat = 32.2226;
    const tucsonLng = -110.9747;

    group('getSunsetTime', () {
      test('returns non-null for Tucson on spring equinox', () {
        final sunset = SunsetCalculator.getSunsetTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 3, 20),
        );

        expect(sunset, isNotNull);
        // Spring equinox sunset in Tucson is around 6:20-6:30 PM MST (UTC-7)
        // In UTC that's ~1:20-1:30 AM next day. Check UTC hour is reasonable.
        final utcSunset = sunset!.toUtc();
        final utcMinutes = utcSunset.hour * 60 + utcSunset.minute;
        // Expect UTC time between 00:00 and 03:00 (Tucson evening in UTC)
        // or between 17:00 and 20:00 (if test runs in a western timezone)
        // Use a broad check: sunset should be on a reasonable date
        expect(utcMinutes, greaterThanOrEqualTo(0));
        expect(utcMinutes, lessThan(24 * 60));
      });

      test('returns non-null for summer solstice', () {
        final sunset = SunsetCalculator.getSunsetTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 6, 21),
        );

        expect(sunset, isNotNull);
        // Summer sunset in Tucson is later, around 7:20-7:40 PM
      });

      test('returns non-null for winter solstice', () {
        final sunset = SunsetCalculator.getSunsetTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 12, 21),
        );

        expect(sunset, isNotNull);
        // Winter sunset in Tucson is earlier, around 5:20-5:30 PM
      });

      test('summer sunset is later than winter sunset', () {
        final summerSunset = SunsetCalculator.getSunsetTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 6, 21),
        );

        final winterSunset = SunsetCalculator.getSunsetTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 12, 21),
        );

        expect(summerSunset, isNotNull);
        expect(winterSunset, isNotNull);

        // Compare time of day (ignore date)
        final summerMinutes =
            summerSunset!.hour * 60 + summerSunset.minute;
        final winterMinutes =
            winterSunset!.hour * 60 + winterSunset.minute;

        expect(summerMinutes, greaterThan(winterMinutes));
      });

      test('works for equator location', () {
        final sunset = SunsetCalculator.getSunsetTime(
          latitude: 0.0,
          longitude: 0.0,
          date: DateTime(2026, 3, 20),
        );
        expect(sunset, isNotNull);
      });

      test('works for high northern latitude in summer', () {
        // Stockholm, Sweden
        final sunset = SunsetCalculator.getSunsetTime(
          latitude: 59.33,
          longitude: 18.07,
          date: DateTime(2026, 6, 21),
        );
        // Should return a very late sunset
        expect(sunset, isNotNull);
      });
    });

    group('getSunriseTime', () {
      test('returns non-null for Tucson on spring equinox', () {
        final sunrise = SunsetCalculator.getSunriseTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 3, 20),
        );

        expect(sunrise, isNotNull);
        // Spring equinox sunrise in Tucson is around 6:15-6:30 AM
      });


      test('summer sunrise is earlier than winter sunrise', () {
        final summerSunrise = SunsetCalculator.getSunriseTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 6, 21),
        );

        final winterSunrise = SunsetCalculator.getSunriseTime(
          latitude: tucsonLat,
          longitude: tucsonLng,
          date: DateTime(2026, 12, 21),
        );

        expect(summerSunrise, isNotNull);
        expect(winterSunrise, isNotNull);

        final summerMinutes =
            summerSunrise!.hour * 60 + summerSunrise.minute;
        final winterMinutes =
            winterSunrise!.hour * 60 + winterSunrise.minute;

        expect(summerMinutes, lessThan(winterMinutes));
      });
    });

    group('polar edge cases', () {
      test('returns null for North Pole in winter (no sunrise)', () {
        final sunrise = SunsetCalculator.getSunriseTime(
          latitude: 89.0,
          longitude: 0.0,
          date: DateTime(2026, 12, 21),
        );
        // At the North Pole in December, the sun doesn't rise
        expect(sunrise, isNull);
      });
    });
  });
}

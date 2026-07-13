import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/user_profile.dart';

void main() {
  final now = DateTime(2026, 7, 13);

  UserProfile base({
    List<Vehicle> vehicles = const [],
    String? make,
    int? year,
    String? plate,
  }) =>
      UserProfile(
        id: 'profile',
        userId: 'u1',
        vehicles: vehicles,
        vehicleMake: make,
        vehicleYear: year,
        vehicleLicensePlate: plate,
        createdAt: now,
        updatedAt: now,
      );

  group('UserProfile.allVehicles', () {
    test('returns structured vehicles when present', () {
      final p = base(vehicles: [
        Vehicle(id: 'v1', make: 'Toyota', model: 'Camry'),
      ], make: 'Ford'); // legacy make should be ignored
      expect(p.allVehicles.length, 1);
      expect(p.allVehicles.first.make, 'Toyota');
    });

    test('folds legacy single-vehicle fields when no structured list', () {
      final p = base(make: 'Ford', year: 2019, plate: 'XYZ999');
      expect(p.allVehicles.length, 1);
      final v = p.allVehicles.first;
      expect(v.make, 'Ford');
      expect(v.year, 2019);
      expect(v.licensePlate, 'XYZ999');
    });

    test('empty when neither structured nor legacy present', () {
      expect(base().allVehicles, isEmpty);
    });
  });

  group('serialization round-trip', () {
    test('vehicles and social links survive toFirestore/fromMap', () {
      final v = Vehicle(
        id: 'v1',
        make: 'Honda',
        model: 'CR-V',
        year: 2021,
        color: 'Blue',
        licensePlate: 'ABC123',
        licenseState: 'AZ',
        vin: 'JH4',
        notes: 'Roof rack',
        photoUrls: ['https://x/1.jpg', 'https://x/2.jpg'],
      );
      final vm = Vehicle.fromMap(v.toMap());
      expect(vm.displayName, '2021 Blue Honda CR-V');
      expect(vm.photoUrls.length, 2);
      expect(vm.licenseState, 'AZ');

      final s = SocialMediaLink(
          platform: 'instagram',
          url: 'https://instagram.com/x',
          handle: '@x');
      final sm = SocialMediaLink.fromMap(s.toMap());
      expect(sm.platformEnum, SocialPlatform.instagram);
      expect(sm.platformEnum.label, 'Instagram');
      expect(sm.url, 'https://instagram.com/x');
    });
  });
}

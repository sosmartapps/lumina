import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/health_profile.dart';

void main() {
  group('HealthCondition', () {
    test('constructor sets all fields', () {
      final now = DateTime(2026, 3, 20);
      final condition = HealthCondition(
        id: 'hc1',
        name: "Alzheimer's Disease",
        description: 'Early onset',
        diagnosisDate: DateTime(2024, 6, 15),
        diagnosedBy: 'Dr. Smith',
        severity: 'moderate',
        notes: 'Progressive',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(condition.id, 'hc1');
      expect(condition.name, "Alzheimer's Disease");
      expect(condition.severity, 'moderate');
      expect(condition.isActive, true);
    });

    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 3, 20);
      final condition = HealthCondition(
        id: 'hc1',
        name: 'Hypertension',
        severity: 'mild',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = condition.toFirestore();
      expect(map['name'], 'Hypertension');
      expect(map['severity'], 'mild');
      expect(map['isActive'], true);
      expect(map['description'], isNull);
      expect(map['diagnosisDate'], isNull);
    });

    test('copyWith overrides specific fields', () {
      final now = DateTime(2026, 3, 20);
      final original = HealthCondition(
        id: 'hc1',
        name: 'Diabetes',
        severity: 'mild',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(severity: 'moderate');

      expect(updated.name, 'Diabetes'); // Preserved
      expect(updated.severity, 'moderate'); // Updated
      expect(updated.isActive, true); // Preserved
    });
  });

  group('Allergy', () {
    test('constructor and toFirestore', () {
      final now = DateTime(2026, 3, 20);
      final allergy = Allergy(
        id: 'a1',
        allergen: 'Penicillin',
        reaction: 'Hives',
        severity: 'severe',
        notes: 'Confirmed by allergist',
        createdAt: now,
      );

      expect(allergy.allergen, 'Penicillin');
      expect(allergy.severity, 'severe');

      final map = allergy.toFirestore();
      expect(map['allergen'], 'Penicillin');
      expect(map['reaction'], 'Hives');
      expect(map['severity'], 'severe');
    });
  });

  group('HealthcareProvider', () {
    test('constructor and toFirestore', () {
      final now = DateTime(2026, 3, 20);
      final provider = HealthcareProvider(
        id: 'hp1',
        name: 'Dr. Sarah Johnson',
        specialty: 'Neurology',
        practice: 'Tucson Brain & Spine',
        phone: '520-555-9999',
        email: 'dr.johnson@example.com',
        isPrimaryCare: false,
        createdAt: now,
      );

      final map = provider.toFirestore();
      expect(map['name'], 'Dr. Sarah Johnson');
      expect(map['specialty'], 'Neurology');
      expect(map['isPrimaryCare'], false);
    });
  });

  group('Pharmacy', () {
    test('constructor and toFirestore', () {
      final now = DateTime(2026, 3, 20);
      final pharmacy = Pharmacy(
        id: 'ph1',
        name: 'Walgreens',
        phone: '520-555-8888',
        address: '789 Broadway Blvd',
        hours: 'Mon-Fri 8AM-9PM',
        isPrimary: true,
        createdAt: now,
      );

      final map = pharmacy.toFirestore();
      expect(map['name'], 'Walgreens');
      expect(map['isPrimary'], true);
      expect(map['hours'], 'Mon-Fri 8AM-9PM');
    });

    test('defaults isPrimary to false', () {
      final pharmacy = Pharmacy(
        id: 'ph1',
        name: 'CVS',
        createdAt: DateTime.now(),
      );
      expect(pharmacy.isPrimary, false);
    });
  });

  group('HealthProfile', () {
    test('constructor with all fields', () {
      final profile = HealthProfile(
        id: 'hp1',
        userId: 'u1',
        bloodType: 'O+',
        height: 175.0,
        weight: 80.0,
        insuranceProvider: 'Aetna',
        insurancePolicyNumber: 'POL123',
        insuranceGroupNumber: 'GRP456',
        emergencyNotes: 'Has pacemaker',
        advanceDirectives: 'DNR on file',
      );

      expect(profile.bloodType, 'O+');
      expect(profile.height, 175.0);
      expect(profile.weight, 80.0);
      expect(profile.emergencyNotes, 'Has pacemaker');
    });

    test('toFirestore includes all fields', () {
      final profile = HealthProfile(
        id: 'hp1',
        userId: 'u1',
        bloodType: 'AB-',
        height: 168.0,
        weight: 65.0,
      );

      final map = profile.toFirestore();
      expect(map['userId'], 'u1');
      expect(map['bloodType'], 'AB-');
      expect(map['height'], 168.0);
      expect(map['weight'], 65.0);
      expect(map['insuranceProvider'], isNull);
    });

    test('copyWith overrides specific fields', () {
      final original = HealthProfile(
        id: 'hp1',
        userId: 'u1',
        bloodType: 'O+',
        weight: 80.0,
      );

      final updated = original.copyWith(weight: 78.5);

      expect(updated.bloodType, 'O+'); // Preserved
      expect(updated.weight, 78.5); // Updated
      expect(updated.userId, 'u1'); // Preserved
    });
  });
}

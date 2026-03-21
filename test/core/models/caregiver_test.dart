import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/caregiver.dart';

void main() {
  group('CaregiverRole', () {
    test('fromString parses all known roles', () {
      expect(CaregiverRole.fromString('primary_caregiver'), CaregiverRole.primaryCaregiver);
      expect(CaregiverRole.fromString('caregiver'), CaregiverRole.caregiver);
      expect(CaregiverRole.fromString('family_member'), CaregiverRole.familyMember);
      expect(CaregiverRole.fromString('healthcare'), CaregiverRole.healthcare);
    });

    test('fromString defaults to caregiver for unknown', () {
      expect(CaregiverRole.fromString('unknown'), CaregiverRole.caregiver);
      expect(CaregiverRole.fromString(''), CaregiverRole.caregiver);
    });

    test('value roundtrips correctly', () {
      for (final role in CaregiverRole.values) {
        expect(CaregiverRole.fromString(role.value), role);
      }
    });

    test('displayName is non-empty for all roles', () {
      for (final role in CaregiverRole.values) {
        expect(role.displayName, isNotEmpty);
      }
    });

    test('displayName maps correctly', () {
      expect(CaregiverRole.primaryCaregiver.displayName, 'Primary Caregiver');
      expect(CaregiverRole.caregiver.displayName, 'Caregiver');
      expect(CaregiverRole.familyMember.displayName, 'Family Member');
      expect(CaregiverRole.healthcare.displayName, 'Healthcare Provider');
    });
  });

  group('Caregiver', () {
    test('constructor sets defaults', () {
      final cg = Caregiver(
        id: 'c1',
        name: 'Mary Herbert',
        email: 'mary@example.com',
      );

      expect(cg.id, 'c1');
      expect(cg.name, 'Mary Herbert');
      expect(cg.email, 'mary@example.com');
      expect(cg.phoneNumber, isNull);
      expect(cg.photoUrl, isNull);
      expect(cg.managedUserIds, isEmpty);
      expect(cg.role, CaregiverRole.caregiver);
      expect(cg.roleOverrides, isEmpty);
      expect(cg.isVerified, false);
      expect(cg.lastLoginAt, isNull);
    });

    test('roleForPatient returns override when set', () {
      final cg = Caregiver(
        id: 'c1',
        name: 'Mary',
        email: 'mary@example.com',
        role: CaregiverRole.caregiver,
        roleOverrides: {
          'patient1': CaregiverRole.primaryCaregiver,
          'patient2': CaregiverRole.familyMember,
        },
      );

      expect(cg.roleForPatient('patient1'), CaregiverRole.primaryCaregiver);
      expect(cg.roleForPatient('patient2'), CaregiverRole.familyMember);
    });

    test('roleForPatient falls back to base role when no override', () {
      final cg = Caregiver(
        id: 'c1',
        name: 'Mary',
        email: 'mary@example.com',
        role: CaregiverRole.healthcare,
      );

      expect(cg.roleForPatient('unknown_patient'), CaregiverRole.healthcare);
    });

    test('toFirestore includes all fields', () {
      final cg = Caregiver(
        id: 'c1',
        name: 'Mary Herbert',
        email: 'mary@example.com',
        phoneNumber: '520-555-1234',
        managedUserIds: ['u1', 'u2'],
        role: CaregiverRole.primaryCaregiver,
        roleOverrides: {'u1': CaregiverRole.primaryCaregiver},
        isVerified: true,
      );

      final map = cg.toFirestore();

      expect(map['name'], 'Mary Herbert');
      expect(map['email'], 'mary@example.com');
      expect(map['phoneNumber'], '520-555-1234');
      expect(map['managedUserIds'], ['u1', 'u2']);
      expect(map['role'], 'primary_caregiver');
      expect(map['roleOverrides'], {'u1': 'primary_caregiver'});
      expect(map['isVerified'], true);
    });

    test('copyWith preserves and overrides', () {
      final cg = Caregiver(
        id: 'c1',
        name: 'Mary Herbert',
        email: 'mary@example.com',
        role: CaregiverRole.caregiver,
        isVerified: false,
      );

      final updated = cg.copyWith(
        name: 'Mary H.',
        isVerified: true,
      );

      expect(updated.id, 'c1'); // Preserved
      expect(updated.name, 'Mary H.');
      expect(updated.email, 'mary@example.com'); // Preserved
      expect(updated.isVerified, true);
      expect(updated.role, CaregiverRole.caregiver); // Preserved
    });
  });
}

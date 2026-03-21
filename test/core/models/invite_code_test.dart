import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/invite_code.dart';
import 'package:lumina/core/models/caregiver.dart';

void main() {
  group('InviteCode', () {
    test('constructor sets defaults', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
      );

      expect(code.isUsed, false);
      expect(code.usedBy, isNull);
      expect(code.usedAt, isNull);
      // Default expiry is ~24 hours from now
      expect(code.expiresAt.isAfter(DateTime.now()), true);
    });

    test('isExpired returns true for past expiry', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(code.isExpired, true);
    });

    test('isExpired returns false for future expiry', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );

      expect(code.isExpired, false);
    });

    test('isValid is true when not used and not expired', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
        isUsed: false,
      );

      expect(code.isValid, true);
    });

    test('isValid is false when used', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
        isUsed: true,
      );

      expect(code.isValid, false);
    });

    test('isValid is false when expired', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        isUsed: false,
      );

      expect(code.isValid, false);
    });

    test('isValid is false when both used and expired', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'ABC123',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.caregiver,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        isUsed: true,
      );

      expect(code.isValid, false);
    });

    test('toFirestore includes all fields', () {
      final code = InviteCode(
        id: 'ic1',
        code: 'XYZ789',
        patientId: 'p1',
        createdBy: 'c1',
        assignedRole: CaregiverRole.primaryCaregiver,
      );

      final map = code.toFirestore();

      expect(map['code'], 'XYZ789');
      expect(map['patientId'], 'p1');
      expect(map['createdBy'], 'c1');
      expect(map['assignedRole'], 'primary_caregiver');
      expect(map['isUsed'], false);
      expect(map['usedBy'], isNull);
      expect(map['usedAt'], isNull);
    });
  });
}

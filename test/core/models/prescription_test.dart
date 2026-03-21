import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/prescription.dart';

void main() {
  group('Prescription', () {
    Prescription createTestPrescription({
      int? totalQuantity,
      int? remainingQuantity,
      int? daysSupply,
      int? refillsRemaining,
      DateTime? nextRefillDate,
      DateTime? expirationDate,
      int refillReminderDaysBefore = 7,
    }) {
      final now = DateTime(2026, 3, 20);
      return Prescription(
        id: 'rx1',
        userId: 'u1',
        medicationName: 'Metformin',
        dosage: '500mg',
        frequency: 'twice daily',
        totalQuantity: totalQuantity,
        remainingQuantity: remainingQuantity,
        daysSupply: daysSupply,
        refillsRemaining: refillsRemaining,
        nextRefillDate: nextRefillDate,
        expirationDate: expirationDate,
        refillReminderDaysBefore: refillReminderDaysBefore,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('constructor sets defaults', () {
      final rx = createTestPrescription();
      expect(rx.status, PrescriptionStatus.active);
      expect(rx.refillReminderEnabled, true);
      expect(rx.refillReminderDaysBefore, 7);
    });

    group('daysUntilRefillNeeded', () {
      test('calculates correctly with full data', () {
        // 60 total pills, 30 day supply = 2 pills/day
        // 20 remaining = 10 days left
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 20,
          daysSupply: 30,
        );
        expect(rx.daysUntilRefillNeeded, 10);
      });

      test('returns null when remainingQuantity is null', () {
        final rx = createTestPrescription(
          totalQuantity: 60,
          daysSupply: 30,
        );
        expect(rx.daysUntilRefillNeeded, isNull);
      });

      test('returns null when daysSupply is null', () {
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 20,
        );
        expect(rx.daysUntilRefillNeeded, isNull);
      });

      test('returns null when totalQuantity is null', () {
        final rx = createTestPrescription(
          remainingQuantity: 20,
          daysSupply: 30,
        );
        expect(rx.daysUntilRefillNeeded, isNull);
      });

      test('returns 0 when no pills remaining', () {
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 0,
          daysSupply: 30,
        );
        expect(rx.daysUntilRefillNeeded, 0);
      });
    });

    group('needsRefillSoon', () {
      test('returns true when days remaining is within threshold', () {
        // 5 days remaining, threshold is 7
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 10,
          daysSupply: 30,
          refillReminderDaysBefore: 7,
        );
        expect(rx.needsRefillSoon, true);
      });

      test('returns false when plenty of supply', () {
        // 20 days remaining, threshold is 7
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 40,
          daysSupply: 30,
          refillReminderDaysBefore: 7,
        );
        expect(rx.needsRefillSoon, false);
      });

      test('falls back to nextRefillDate when quantities unavailable', () {
        // Next refill date is 3 days from now, threshold is 7
        final rx = createTestPrescription(
          nextRefillDate: DateTime.now().add(const Duration(days: 3)),
          refillReminderDaysBefore: 7,
        );
        expect(rx.needsRefillSoon, true);
      });

      test('returns false when no data available', () {
        final rx = createTestPrescription();
        expect(rx.needsRefillSoon, false);
      });
    });

    group('isRefillOverdue', () {
      test('returns true when 0 days remaining', () {
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 0,
          daysSupply: 30,
        );
        expect(rx.isRefillOverdue, true);
      });

      test('returns true when nextRefillDate is past', () {
        final rx = createTestPrescription(
          nextRefillDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(rx.isRefillOverdue, true);
      });

      test('returns false when supply is adequate', () {
        final rx = createTestPrescription(
          totalQuantity: 60,
          remainingQuantity: 40,
          daysSupply: 30,
        );
        expect(rx.isRefillOverdue, false);
      });
    });

    group('noRefillsRemaining', () {
      test('returns true when 0 refills', () {
        final rx = createTestPrescription(refillsRemaining: 0);
        expect(rx.noRefillsRemaining, true);
      });

      test('returns false when refills available', () {
        final rx = createTestPrescription(refillsRemaining: 3);
        expect(rx.noRefillsRemaining, false);
      });

      test('returns false when refillsRemaining is null', () {
        final rx = createTestPrescription();
        expect(rx.noRefillsRemaining, false);
      });
    });

    group('isExpired', () {
      test('returns true when expiration is past', () {
        final rx = createTestPrescription(
          expirationDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(rx.isExpired, true);
      });

      test('returns false when expiration is future', () {
        final rx = createTestPrescription(
          expirationDate: DateTime.now().add(const Duration(days: 365)),
        );
        expect(rx.isExpired, false);
      });

      test('returns false when no expiration set', () {
        final rx = createTestPrescription();
        expect(rx.isExpired, false);
      });
    });

    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 3, 20);
      final rx = Prescription(
        id: 'rx1',
        userId: 'u1',
        medicationName: 'Lisinopril',
        genericName: 'Lisinopril',
        brandName: 'Zestril',
        dosage: '10mg',
        frequency: 'once daily',
        instructions: 'Take in the morning',
        prescribedBy: 'Dr. Smith',
        rxNumber: 'RX-12345',
        totalQuantity: 30,
        remainingQuantity: 15,
        refillsRemaining: 5,
        refillsTotal: 11,
        daysSupply: 30,
        status: PrescriptionStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final map = rx.toFirestore();
      expect(map['medicationName'], 'Lisinopril');
      expect(map['genericName'], 'Lisinopril');
      expect(map['brandName'], 'Zestril');
      expect(map['dosage'], '10mg');
      expect(map['frequency'], 'once daily');
      expect(map['instructions'], 'Take in the morning');
      expect(map['rxNumber'], 'RX-12345');
      expect(map['totalQuantity'], 30);
      expect(map['remainingQuantity'], 15);
      expect(map['refillsRemaining'], 5);
      expect(map['status'], 'active');
    });

    test('copyWith preserves and overrides', () {
      final now = DateTime(2026, 3, 20);
      final rx = Prescription(
        id: 'rx1',
        userId: 'u1',
        medicationName: 'Metformin',
        dosage: '500mg',
        frequency: 'twice daily',
        remainingQuantity: 30,
        createdAt: now,
        updatedAt: now,
      );

      final updated = rx.copyWith(remainingQuantity: 25);

      expect(updated.medicationName, 'Metformin'); // Preserved
      expect(updated.remainingQuantity, 25); // Updated
    });
  });

  group('RefillRecord', () {
    test('constructor and toFirestore', () {
      final record = RefillRecord(
        id: 'rr1',
        prescriptionId: 'rx1',
        filledDate: DateTime(2026, 3, 15),
        pharmacyName: 'Walgreens',
        quantity: 30,
        cost: 12.99,
      );

      final map = record.toFirestore();
      expect(map['prescriptionId'], 'rx1');
      expect(map['pharmacyName'], 'Walgreens');
      expect(map['quantity'], 30);
      expect(map['cost'], 12.99);
    });
  });
}

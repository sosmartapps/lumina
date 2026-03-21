import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/medication.dart';

void main() {
  group('Medication', () {
    test('constructor sets defaults', () {
      final med = Medication(
        id: 'm1',
        userId: 'u1',
        name: 'Aspirin',
        createdBy: 'c1',
      );

      expect(med.id, 'm1');
      expect(med.name, 'Aspirin');
      expect(med.description, isNull);
      expect(med.dosage, isNull);
      expect(med.instructions, isNull);
      expect(med.schedules, isEmpty);
      expect(med.isActive, true);
      expect(med.refillAlertDays, 7);
      expect(med.currentSupply, 0);
      expect(med.createdAt, isNotNull);
    });

    test('toFirestore produces correct map', () {
      final med = Medication(
        id: 'm1',
        userId: 'u1',
        name: 'Lisinopril',
        dosage: '10mg',
        instructions: 'Take with water',
        schedules: [
          MedicationSchedule(id: 's1', hour: 8, minute: 0, label: 'Morning'),
        ],
        isActive: true,
        refillAlertDays: 14,
        currentSupply: 30,
        createdBy: 'c1',
      );

      final map = med.toFirestore();

      expect(map['userId'], 'u1');
      expect(map['name'], 'Lisinopril');
      expect(map['dosage'], '10mg');
      expect(map['instructions'], 'Take with water');
      expect(map['schedules'], hasLength(1));
      expect(map['isActive'], true);
      expect(map['refillAlertDays'], 14);
      expect(map['currentSupply'], 30);
      expect(map['createdBy'], 'c1');
    });

    test('copyWith overrides specific fields', () {
      final med = Medication(
        id: 'm1',
        userId: 'u1',
        name: 'Aspirin',
        dosage: '81mg',
        currentSupply: 30,
        createdBy: 'c1',
      );

      final updated = med.copyWith(
        currentSupply: 25,
        dosage: '100mg',
      );

      expect(updated.id, 'm1'); // Preserved
      expect(updated.name, 'Aspirin'); // Preserved
      expect(updated.dosage, '100mg'); // Updated
      expect(updated.currentSupply, 25); // Updated
      expect(updated.createdBy, 'c1'); // Preserved
    });
  });

  group('MedicationSchedule', () {
    test('fromMap parses all fields', () {
      final schedule = MedicationSchedule.fromMap({
        'id': 's1',
        'hour': 14,
        'minute': 30,
        'days': [1, 2, 3, 4, 5],
        'label': 'After lunch',
      });

      expect(schedule.id, 's1');
      expect(schedule.hour, 14);
      expect(schedule.minute, 30);
      expect(schedule.days, [1, 2, 3, 4, 5]);
      expect(schedule.label, 'After lunch');
    });

    test('fromMap defaults missing fields', () {
      final schedule = MedicationSchedule.fromMap({});
      expect(schedule.id, '');
      expect(schedule.hour, 8);
      expect(schedule.minute, 0);
      expect(schedule.days, isNull);
      expect(schedule.label, isNull);
    });

    test('toMap roundtrip preserves data', () {
      final original = MedicationSchedule(
        id: 's1',
        hour: 20,
        minute: 15,
        days: [6, 7],
        label: 'Evening',
      );

      final map = original.toMap();
      final restored = MedicationSchedule.fromMap(map);

      expect(restored.id, 's1');
      expect(restored.hour, 20);
      expect(restored.minute, 15);
      expect(restored.days, [6, 7]);
      expect(restored.label, 'Evening');
    });

    test('timeString formats AM correctly', () {
      final schedule = MedicationSchedule(id: 's1', hour: 8, minute: 0);
      expect(schedule.timeString, '8:00 AM');
    });

    test('timeString formats PM correctly', () {
      final schedule = MedicationSchedule(id: 's1', hour: 14, minute: 30);
      expect(schedule.timeString, '2:30 PM');
    });

    test('timeString formats 12 PM (noon) correctly', () {
      final schedule = MedicationSchedule(id: 's1', hour: 12, minute: 0);
      expect(schedule.timeString, '12:00 PM');
    });

    test('timeString formats 12 AM (midnight) correctly', () {
      final schedule = MedicationSchedule(id: 's1', hour: 0, minute: 0);
      expect(schedule.timeString, '12:00 AM');
    });

    test('timeString pads single-digit minutes', () {
      final schedule = MedicationSchedule(id: 's1', hour: 9, minute: 5);
      expect(schedule.timeString, '9:05 AM');
    });
  });

  group('MedicationLogStatus', () {
    test('fromString parses all known statuses', () {
      expect(MedicationLogStatus.fromString('pending'), MedicationLogStatus.pending);
      expect(MedicationLogStatus.fromString('taken'), MedicationLogStatus.taken);
      expect(MedicationLogStatus.fromString('missed'), MedicationLogStatus.missed);
      expect(MedicationLogStatus.fromString('snoozed'), MedicationLogStatus.snoozed);
      expect(MedicationLogStatus.fromString('skipped'), MedicationLogStatus.skipped);
    });

    test('fromString defaults to pending for unknown', () {
      expect(MedicationLogStatus.fromString('unknown'), MedicationLogStatus.pending);
    });

    test('value roundtrips correctly', () {
      for (final status in MedicationLogStatus.values) {
        expect(MedicationLogStatus.fromString(status.value), status);
      }
    });

    test('displayName is non-empty for all statuses', () {
      for (final status in MedicationLogStatus.values) {
        expect(status.displayName, isNotEmpty);
      }
    });
  });

  group('MedicationLog', () {
    test('constructor sets defaults', () {
      final log = MedicationLog(
        id: 'ml1',
        medicationId: 'm1',
        userId: 'u1',
        scheduledTime: DateTime(2026, 3, 20, 8, 0),
      );

      expect(log.status, MedicationLogStatus.pending);
      expect(log.takenTime, isNull);
      expect(log.photoUrl, isNull);
      expect(log.verifiedByComparison, false);
      expect(log.comparisonScore, isNull);
    });

    test('toFirestore includes all fields', () {
      final log = MedicationLog(
        id: 'ml1',
        medicationId: 'm1',
        userId: 'u1',
        scheduledTime: DateTime(2026, 3, 20, 8, 0),
        takenTime: DateTime(2026, 3, 20, 8, 5),
        status: MedicationLogStatus.taken,
        verifiedByComparison: true,
        comparisonScore: 0.95,
      );

      final map = log.toFirestore();
      expect(map['medicationId'], 'm1');
      expect(map['status'], 'taken');
      expect(map['verifiedByComparison'], true);
      expect(map['comparisonScore'], 0.95);
    });
  });
}

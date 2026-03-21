import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/reminder.dart';

void main() {
  group('ReminderType', () {
    test('fromString parses all known types', () {
      expect(ReminderType.fromString('medication'), ReminderType.medication);
      expect(ReminderType.fromString('task'), ReminderType.task);
      expect(ReminderType.fromString('appointment'), ReminderType.appointment);
      expect(ReminderType.fromString('meal_time'), ReminderType.mealTime);
      expect(ReminderType.fromString('hydration'), ReminderType.hydration);
      expect(ReminderType.fromString('exercise'), ReminderType.exercise);
      expect(ReminderType.fromString('pet_care'), ReminderType.petCare);
      expect(ReminderType.fromString('general'), ReminderType.general);
    });

    test('fromString defaults to general for unknown values', () {
      expect(ReminderType.fromString('unknown'), ReminderType.general);
      expect(ReminderType.fromString(''), ReminderType.general);
    });

    test('value roundtrips correctly', () {
      for (final type in ReminderType.values) {
        expect(ReminderType.fromString(type.value), type);
      }
    });

    test('displayName is non-empty for all types', () {
      for (final type in ReminderType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('defaultIcon is non-empty for all types', () {
      for (final type in ReminderType.values) {
        expect(type.defaultIcon, isNotEmpty);
      }
    });
  });

  group('RepeatFrequency', () {
    test('fromString parses all known values', () {
      expect(RepeatFrequency.fromString('once'), RepeatFrequency.once);
      expect(RepeatFrequency.fromString('daily'), RepeatFrequency.daily);
      expect(RepeatFrequency.fromString('weekly'), RepeatFrequency.weekly);
      expect(RepeatFrequency.fromString('custom'), RepeatFrequency.custom);
    });

    test('fromString defaults to daily for unknown', () {
      expect(RepeatFrequency.fromString('unknown'), RepeatFrequency.daily);
    });

    test('value roundtrips correctly', () {
      for (final freq in RepeatFrequency.values) {
        expect(RepeatFrequency.fromString(freq.value), freq);
      }
    });

    test('displayName is non-empty for all frequencies', () {
      for (final freq in RepeatFrequency.values) {
        expect(freq.displayName, isNotEmpty);
      }
    });
  });

  group('Reminder', () {
    Reminder createTestReminder({
      ReminderType type = ReminderType.general,
      bool? homeOnly,
      String? spokenMessage,
    }) {
      return Reminder(
        id: 'r1',
        userId: 'u1',
        title: 'Take medication',
        type: type,
        scheduledTime: DateTime(2026, 3, 20, 8, 0),
        createdBy: 'c1',
        homeOnly: homeOnly,
        spokenMessage: spokenMessage,
      );
    }

    test('defaults isActive to true', () {
      final r = createTestReminder();
      expect(r.isActive, true);
    });

    test('defaults snooze settings', () {
      final r = createTestReminder();
      expect(r.snoozeMinutes, 10);
      expect(r.maxSnoozeCount, 3);
      expect(r.currentSnoozeCount, 0);
    });

    test('medication type defaults to homeOnly', () {
      final r = createTestReminder(type: ReminderType.medication);
      expect(r.homeOnly, true);
    });

    test('petCare type defaults to homeOnly', () {
      final r = createTestReminder(type: ReminderType.petCare);
      expect(r.homeOnly, true);
    });

    test('mealTime type defaults to homeOnly', () {
      final r = createTestReminder(type: ReminderType.mealTime);
      expect(r.homeOnly, true);
    });

    test('appointment type defaults to NOT homeOnly', () {
      final r = createTestReminder(type: ReminderType.appointment);
      expect(r.homeOnly, false);
    });

    test('exercise type defaults to NOT homeOnly', () {
      final r = createTestReminder(type: ReminderType.exercise);
      expect(r.homeOnly, false);
    });

    test('explicit homeOnly overrides type default', () {
      final r = createTestReminder(
        type: ReminderType.medication,
        homeOnly: false,
      );
      expect(r.homeOnly, false);
    });

    test('getSpokenMessage uses custom message with name substitution', () {
      final r = createTestReminder(
        spokenMessage: 'Hey {name}, time for your pills!',
      );
      expect(
        r.getSpokenMessage('Bob'),
        'Hey Bob, time for your pills!',
      );
    });

    test('getSpokenMessage falls back to title with name prefix', () {
      final r = createTestReminder();
      expect(r.getSpokenMessage('Bob'), 'Bob, Take medication');
    });

    test('getSpokenMessage ignores empty spokenMessage', () {
      final r = createTestReminder(spokenMessage: '');
      expect(r.getSpokenMessage('Alice'), 'Alice, Take medication');
    });

    test('toFirestore includes all fields', () {
      final r = Reminder(
        id: 'r1',
        userId: 'u1',
        title: 'Take Aspirin',
        description: 'With food',
        spokenMessage: 'Time for Aspirin',
        type: ReminderType.medication,
        scheduledTime: DateTime(2026, 3, 20, 8, 0),
        repeatDays: [1, 3, 5],
        repeatFrequency: RepeatFrequency.custom,
        isActive: true,
        requiresConfirmation: true,
        requiresPhoto: true,
        iconName: 'medication',
        color: '#FF0000',
        snoozeMinutes: 15,
        maxSnoozeCount: 5,
        currentSnoozeCount: 1,
        homeOnly: true,
        createdBy: 'c1',
      );

      final map = r.toFirestore();

      expect(map['userId'], 'u1');
      expect(map['title'], 'Take Aspirin');
      expect(map['description'], 'With food');
      expect(map['spokenMessage'], 'Time for Aspirin');
      expect(map['type'], 'medication');
      expect(map['repeatDays'], [1, 3, 5]);
      expect(map['repeatFrequency'], 'custom');
      expect(map['isActive'], true);
      expect(map['requiresConfirmation'], true);
      expect(map['requiresPhoto'], true);
      expect(map['iconName'], 'medication');
      expect(map['color'], '#FF0000');
      expect(map['snoozeMinutes'], 15);
      expect(map['maxSnoozeCount'], 5);
      expect(map['currentSnoozeCount'], 1);
      expect(map['homeOnly'], true);
      expect(map['createdBy'], 'c1');
    });

    test('copyWith preserves original and overrides specified', () {
      final original = createTestReminder();
      final updated = original.copyWith(
        title: 'Updated title',
        isActive: false,
        snoozeMinutes: 20,
      );

      expect(updated.id, 'r1'); // Preserved
      expect(updated.userId, 'u1'); // Preserved
      expect(updated.title, 'Updated title');
      expect(updated.isActive, false);
      expect(updated.snoozeMinutes, 20);
      expect(updated.type, ReminderType.general); // Preserved
      expect(updated.createdBy, 'c1'); // Preserved
    });
  });
}

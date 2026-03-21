import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('constructor sets required fields and defaults', () {
      final user = AppUser(id: 'u1', name: 'John Doe');

      expect(user.id, 'u1');
      expect(user.name, 'John Doe');
      expect(user.preferredName, isNull);
      expect(user.photoUrl, isNull);
      expect(user.phoneNumber, isNull);
      expect(user.caregiverIds, isEmpty);
      expect(user.primaryCaregiverId, isNull);
      expect(user.homeLocation, isNull);
      expect(user.homeAddress, isNull);
      expect(user.savedLocations, isEmpty);
      expect(user.emergencyContacts, isEmpty);
      expect(user.subscriptionTier, 'free');
      expect(user.subscriptionExpiresAt, isNull);
      expect(user.revenueCatCustomerId, isNull);
      expect(user.createdAt, isNotNull);
      expect(user.updatedAt, isNotNull);
    });

    test('displayName returns preferredName when set', () {
      final user = AppUser(
        id: 'u1',
        name: 'John Michael Doe',
        preferredName: 'Johnny',
      );
      expect(user.displayName, 'Johnny');
    });

    test('displayName returns first name when preferredName is null', () {
      final user = AppUser(id: 'u1', name: 'John Michael Doe');
      expect(user.displayName, 'John');
    });

    test('displayName handles single-word name', () {
      final user = AppUser(id: 'u1', name: 'Cher');
      expect(user.displayName, 'Cher');
    });

    test('toFirestore produces correct map', () {
      final now = DateTime(2026, 3, 20);
      final user = AppUser(
        id: 'u1',
        name: 'Jane Doe',
        preferredName: 'Janie',
        phoneNumber: '520-555-1234',
        caregiverIds: ['c1', 'c2'],
        primaryCaregiverId: 'c1',
        homeAddress: '123 Main St',
        subscriptionTier: 'premium',
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toFirestore();

      expect(map['name'], 'Jane Doe');
      expect(map['preferredName'], 'Janie');
      expect(map['phoneNumber'], '520-555-1234');
      expect(map['caregiverIds'], ['c1', 'c2']);
      expect(map['primaryCaregiverId'], 'c1');
      expect(map['homeAddress'], '123 Main St');
      expect(map['subscriptionTier'], 'premium');
      // savedLocations and emergencyContacts should be empty lists
      expect(map['savedLocations'], isEmpty);
      expect(map['emergencyContacts'], isEmpty);
    });

    test('copyWith preserves fields not overridden', () {
      final user = AppUser(
        id: 'u1',
        name: 'Jane Doe',
        preferredName: 'Janie',
        subscriptionTier: 'premium',
      );

      final updated = user.copyWith(name: 'Jane Smith');

      expect(updated.id, 'u1'); // Not changeable via copyWith
      expect(updated.name, 'Jane Smith');
      expect(updated.preferredName, 'Janie'); // Preserved
      expect(updated.subscriptionTier, 'premium'); // Preserved
    });

    test('copyWith overrides multiple fields', () {
      final user = AppUser(id: 'u1', name: 'Jane');
      final updated = user.copyWith(
        name: 'Jane Updated',
        phoneNumber: '555-0000',
        subscriptionTier: 'premium',
      );

      expect(updated.name, 'Jane Updated');
      expect(updated.phoneNumber, '555-0000');
      expect(updated.subscriptionTier, 'premium');
    });

    test('settings defaults when not provided', () {
      final user = AppUser(id: 'u1', name: 'Test');
      expect(user.settings.highContrastMode, false);
      expect(user.settings.textScale, 1.2);
      expect(user.settings.soundEnabled, true);
      expect(user.settings.voicePromptsEnabled, true);
    });
  });

  group('UserSettings', () {
    test('defaults are accessibility-focused', () {
      final settings = UserSettings();
      expect(settings.highContrastMode, false);
      expect(settings.textScale, 1.2);
      expect(settings.soundEnabled, true);
      expect(settings.vibrationEnabled, true);
      expect(settings.voicePromptsEnabled, true);
      expect(settings.reminderVolume, 80);
      expect(settings.voiceLanguage, 'en-US');
      expect(settings.sundownAlertEnabled, true);
      expect(settings.sundownBufferMinutes, 30);
      expect(settings.motionDetectionEnabled, true);
      expect(settings.morningWindowStart, 5);
      expect(settings.morningWindowEnd, 10);
    });

    test('fromMap handles missing fields with defaults', () {
      final settings = UserSettings.fromMap({});
      expect(settings.highContrastMode, false);
      expect(settings.textScale, 1.2);
      expect(settings.soundEnabled, true);
      expect(settings.reminderVolume, 80);
    });

    test('fromMap parses all fields correctly', () {
      final settings = UserSettings.fromMap({
        'highContrastMode': true,
        'textScale': 1.5,
        'soundEnabled': false,
        'vibrationEnabled': false,
        'voicePromptsEnabled': false,
        'reminderVolume': 50,
        'voiceLanguage': 'es-MX',
        'sundownAlertEnabled': false,
        'sundownBufferMinutes': 45,
        'motionDetectionEnabled': false,
        'morningWindowStart': 6,
        'morningWindowEnd': 11,
      });

      expect(settings.highContrastMode, true);
      expect(settings.textScale, 1.5);
      expect(settings.soundEnabled, false);
      expect(settings.vibrationEnabled, false);
      expect(settings.voicePromptsEnabled, false);
      expect(settings.reminderVolume, 50);
      expect(settings.voiceLanguage, 'es-MX');
      expect(settings.sundownAlertEnabled, false);
      expect(settings.sundownBufferMinutes, 45);
      expect(settings.motionDetectionEnabled, false);
      expect(settings.morningWindowStart, 6);
      expect(settings.morningWindowEnd, 11);
    });

    test('sundownBufferMinutes clamps to 30-60 range', () {
      final low = UserSettings.fromMap({'sundownBufferMinutes': 10});
      expect(low.sundownBufferMinutes, 30);

      final high = UserSettings.fromMap({'sundownBufferMinutes': 120});
      expect(high.sundownBufferMinutes, 60);

      final normal = UserSettings.fromMap({'sundownBufferMinutes': 45});
      expect(normal.sundownBufferMinutes, 45);
    });

    test('toMap roundtrip preserves values', () {
      final original = UserSettings(
        highContrastMode: true,
        textScale: 1.8,
        soundEnabled: false,
        reminderVolume: 42,
      );

      final restored = UserSettings.fromMap(original.toMap());

      expect(restored.highContrastMode, true);
      expect(restored.textScale, 1.8);
      expect(restored.soundEnabled, false);
      expect(restored.reminderVolume, 42);
    });

    test('copyWith overrides specific fields', () {
      final settings = UserSettings();
      final updated = settings.copyWith(
        highContrastMode: true,
        textScale: 2.0,
      );

      expect(updated.highContrastMode, true);
      expect(updated.textScale, 2.0);
      expect(updated.soundEnabled, true); // Preserved
    });
  });

  group('SavedLocation', () {
    test('fromMap handles all fields', () {
      final loc = SavedLocation.fromMap({
        'id': 'loc1',
        'name': 'Home',
        'address': '123 Main St',
        'iconName': 'home',
        'color': '#FF0000',
        'orderIndex': 1,
      });

      expect(loc.id, 'loc1');
      expect(loc.name, 'Home');
      expect(loc.address, '123 Main St');
      expect(loc.iconName, 'home');
      expect(loc.color, '#FF0000');
      expect(loc.orderIndex, 1);
    });

    test('fromMap defaults missing optional fields', () {
      final loc = SavedLocation.fromMap({});
      expect(loc.id, '');
      expect(loc.name, '');
      expect(loc.iconName, isNull);
      expect(loc.color, isNull);
      expect(loc.orderIndex, 0);
    });

    test('toMap roundtrip preserves data', () {
      final original = SavedLocation.fromMap({
        'id': 'loc1',
        'name': 'Pharmacy',
        'address': '456 Oak Ave',
        'iconName': 'local_pharmacy',
        'orderIndex': 3,
      });

      final map = original.toMap();
      expect(map['id'], 'loc1');
      expect(map['name'], 'Pharmacy');
      expect(map['address'], '456 Oak Ave');
      expect(map['iconName'], 'local_pharmacy');
      expect(map['orderIndex'], 3);
    });
  });

  group('EmergencyContact', () {
    test('fromMap parses all fields', () {
      final contact = EmergencyContact.fromMap({
        'id': 'ec1',
        'name': 'Dr. Smith',
        'phoneNumber': '520-555-9999',
        'relationship': 'Doctor',
        'photoUrl': 'https://example.com/photo.jpg',
        'color': '#00FF00',
        'orderIndex': 0,
      });

      expect(contact.id, 'ec1');
      expect(contact.name, 'Dr. Smith');
      expect(contact.phoneNumber, '520-555-9999');
      expect(contact.relationship, 'Doctor');
      expect(contact.photoUrl, 'https://example.com/photo.jpg');
      expect(contact.color, '#00FF00');
      expect(contact.orderIndex, 0);
    });

    test('fromMap defaults missing fields', () {
      final contact = EmergencyContact.fromMap({});
      expect(contact.id, '');
      expect(contact.name, '');
      expect(contact.phoneNumber, '');
      expect(contact.relationship, isNull);
      expect(contact.photoUrl, isNull);
      expect(contact.orderIndex, 0);
    });

    test('toMap roundtrip preserves data', () {
      final original = EmergencyContact.fromMap({
        'id': 'ec1',
        'name': 'Mary',
        'phoneNumber': '555-1111',
        'relationship': 'Daughter',
      });
      final map = original.toMap();
      expect(map['name'], 'Mary');
      expect(map['phoneNumber'], '555-1111');
      expect(map['relationship'], 'Daughter');
    });
  });

  group('ActivityEvent', () {
    test('constructor sets all fields', () {
      final event = ActivityEvent(
        id: 'ae1',
        userId: 'u1',
        type: 'device_pickup',
        timestamp: DateTime(2026, 3, 20, 8, 0),
        metadata: {'source': 'accelerometer'},
      );

      expect(event.id, 'ae1');
      expect(event.userId, 'u1');
      expect(event.type, 'device_pickup');
      expect(event.timestamp, DateTime(2026, 3, 20, 8, 0));
      expect(event.metadata?['source'], 'accelerometer');
    });

    test('toFirestore includes all fields', () {
      final event = ActivityEvent(
        id: 'ae1',
        userId: 'u1',
        type: 'morning_wake',
        timestamp: DateTime(2026, 3, 20, 7, 30),
      );

      final map = event.toFirestore();
      expect(map['userId'], 'u1');
      expect(map['type'], 'morning_wake');
      expect(map['metadata'], isNull);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/geo_zone.dart';

void main() {
  group('GeoZoneType', () {
    test('fromString parses all known types', () {
      expect(GeoZoneType.fromString('safe'), GeoZoneType.safe);
      expect(GeoZoneType.fromString('danger'), GeoZoneType.danger);
      expect(GeoZoneType.fromString('home'), GeoZoneType.home);
      expect(GeoZoneType.fromString('work'), GeoZoneType.work);
      expect(GeoZoneType.fromString('medical'), GeoZoneType.medical);
    });

    test('fromString defaults to safe for unknown', () {
      expect(GeoZoneType.fromString('unknown'), GeoZoneType.safe);
      expect(GeoZoneType.fromString(''), GeoZoneType.safe);
    });

    test('value roundtrips correctly', () {
      for (final type in GeoZoneType.values) {
        expect(GeoZoneType.fromString(type.value), type);
      }
    });

    test('displayName is non-empty', () {
      for (final type in GeoZoneType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('displayName maps correctly', () {
      expect(GeoZoneType.safe.displayName, 'Safe Zone');
      expect(GeoZoneType.danger.displayName, 'Restricted Area');
      expect(GeoZoneType.home.displayName, 'Home');
      expect(GeoZoneType.work.displayName, 'Day Center');
      expect(GeoZoneType.medical.displayName, 'Medical Facility');
    });
  });

  group('GeoZoneEventType', () {
    test('fromString parses all known types', () {
      expect(GeoZoneEventType.fromString('enter'), GeoZoneEventType.enter);
      expect(GeoZoneEventType.fromString('exit'), GeoZoneEventType.exit);
      expect(GeoZoneEventType.fromString('dwell'), GeoZoneEventType.dwell);
    });

    test('fromString defaults to enter for unknown', () {
      expect(GeoZoneEventType.fromString('xyz'), GeoZoneEventType.enter);
    });
  });

  group('GeoZone', () {
    test('constructor sets defaults', () {
      final zone = GeoZone(
        id: 'z1',
        userId: 'u1',
        name: 'Home Zone',
        center: const GeoPoint(32.2226, -110.9747),
        radiusMeters: 200,
        createdBy: 'c1',
      );

      expect(zone.type, GeoZoneType.safe);
      expect(zone.alertOnEntry, false);
      expect(zone.alertOnExit, true);
      expect(zone.isActive, true);
      expect(zone.color, isNull);
    });

    test('toFirestore includes all fields', () {
      final zone = GeoZone(
        id: 'z1',
        userId: 'u1',
        name: 'Hospital',
        center: const GeoPoint(32.2, -110.9),
        radiusMeters: 500,
        type: GeoZoneType.medical,
        alertOnEntry: true,
        alertOnExit: false,
        createdBy: 'c1',
      );

      final map = zone.toFirestore();

      expect(map['userId'], 'u1');
      expect(map['name'], 'Hospital');
      expect(map['radiusMeters'], 500);
      expect(map['type'], 'medical');
      expect(map['alertOnEntry'], true);
      expect(map['alertOnExit'], false);
    });

    test('copyWith preserves and overrides', () {
      final zone = GeoZone(
        id: 'z1',
        userId: 'u1',
        name: 'Home',
        center: const GeoPoint(32.2, -110.9),
        radiusMeters: 100,
        type: GeoZoneType.home,
        createdBy: 'c1',
      );

      final updated = zone.copyWith(
        name: 'Home - Updated',
        radiusMeters: 300,
      );

      expect(updated.id, 'z1'); // Preserved
      expect(updated.name, 'Home - Updated');
      expect(updated.radiusMeters, 300);
      expect(updated.type, GeoZoneType.home); // Preserved
      expect(updated.createdBy, 'c1'); // Preserved
    });
  });

  group('GeoZoneEvent', () {
    test('constructor and toFirestore roundtrip', () {
      final event = GeoZoneEvent(
        id: 'ev1',
        zoneId: 'z1',
        userId: 'u1',
        eventType: GeoZoneEventType.exit,
        location: const GeoPoint(32.22, -110.97),
        timestamp: DateTime(2026, 3, 20, 14, 30),
        alertSent: true,
        notifiedCaregivers: ['c1', 'c2'],
      );

      final map = event.toFirestore();

      expect(map['zoneId'], 'z1');
      expect(map['userId'], 'u1');
      expect(map['eventType'], 'exit');
      expect(map['alertSent'], true);
      expect(map['notifiedCaregivers'], ['c1', 'c2']);
    });

    test('defaults alertSent to false', () {
      final event = GeoZoneEvent(
        id: 'ev1',
        zoneId: 'z1',
        userId: 'u1',
        eventType: GeoZoneEventType.enter,
        location: const GeoPoint(0, 0),
        timestamp: DateTime.now(),
      );

      expect(event.alertSent, false);
      expect(event.notifiedCaregivers, isEmpty);
    });
  });

  group('LocationUpdate', () {
    test('constructor and toFirestore', () {
      final update = LocationUpdate(
        id: 'lu1',
        userId: 'u1',
        location: const GeoPoint(32.2226, -110.9747),
        accuracy: 10.5,
        speed: 1.2,
        heading: 180.0,
        altitude: 728.0,
        batteryLevel: 85,
        timestamp: DateTime(2026, 3, 20, 10, 0),
      );

      expect(update.accuracy, 10.5);
      expect(update.speed, 1.2);
      expect(update.batteryLevel, 85);

      final map = update.toFirestore();
      expect(map['userId'], 'u1');
      expect(map['accuracy'], 10.5);
      expect(map['speed'], 1.2);
      expect(map['heading'], 180.0);
      expect(map['altitude'], 728.0);
      expect(map['batteryLevel'], 85);
    });

    test('optional fields default to null', () {
      final update = LocationUpdate(
        id: 'lu1',
        userId: 'u1',
        location: const GeoPoint(0, 0),
        timestamp: DateTime.now(),
      );

      expect(update.accuracy, isNull);
      expect(update.speed, isNull);
      expect(update.heading, isNull);
      expect(update.altitude, isNull);
      expect(update.batteryLevel, isNull);
    });
  });
}

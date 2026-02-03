import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a geographic zone for monitoring user location
class GeoZone {
  final String id;
  final String userId;
  final String name;
  final GeoPoint center;
  final double radiusMeters;
  final GeoZoneType type;
  final bool alertOnEntry;
  final bool alertOnExit;
  final bool isActive;
  final String? color;
  final DateTime createdAt;
  final String createdBy;

  GeoZone({
    required this.id,
    required this.userId,
    required this.name,
    required this.center,
    required this.radiusMeters,
    this.type = GeoZoneType.safe,
    this.alertOnEntry = false,
    this.alertOnExit = true,
    this.isActive = true,
    this.color,
    DateTime? createdAt,
    required this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GeoZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GeoZone(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      center: data['center'] ?? const GeoPoint(0, 0),
      radiusMeters: (data['radiusMeters'] ?? 100).toDouble(),
      type: GeoZoneType.fromString(data['type'] ?? 'safe'),
      alertOnEntry: data['alertOnEntry'] ?? false,
      alertOnExit: data['alertOnExit'] ?? true,
      isActive: data['isActive'] ?? true,
      color: data['color'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'center': center,
      'radiusMeters': radiusMeters,
      'type': type.value,
      'alertOnEntry': alertOnEntry,
      'alertOnExit': alertOnExit,
      'isActive': isActive,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  GeoZone copyWith({
    String? name,
    GeoPoint? center,
    double? radiusMeters,
    GeoZoneType? type,
    bool? alertOnEntry,
    bool? alertOnExit,
    bool? isActive,
    String? color,
  }) {
    return GeoZone(
      id: id,
      userId: userId,
      name: name ?? this.name,
      center: center ?? this.center,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      type: type ?? this.type,
      alertOnEntry: alertOnEntry ?? this.alertOnEntry,
      alertOnExit: alertOnExit ?? this.alertOnExit,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}

enum GeoZoneType {
  safe('safe'),       // Normal zone - alert when leaving
  danger('danger'),   // Alert when entering
  home('home'),       // Home zone
  work('work'),       // Work/day center
  medical('medical'); // Hospital/clinic

  final String value;
  const GeoZoneType(this.value);

  static GeoZoneType fromString(String value) {
    return GeoZoneType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GeoZoneType.safe,
    );
  }

  String get displayName {
    switch (this) {
      case GeoZoneType.safe:
        return 'Safe Zone';
      case GeoZoneType.danger:
        return 'Restricted Area';
      case GeoZoneType.home:
        return 'Home';
      case GeoZoneType.work:
        return 'Day Center';
      case GeoZoneType.medical:
        return 'Medical Facility';
    }
  }
}

/// Record of geofence events
class GeoZoneEvent {
  final String id;
  final String zoneId;
  final String userId;
  final GeoZoneEventType eventType;
  final GeoPoint location;
  final DateTime timestamp;
  final bool alertSent;
  final List<String> notifiedCaregivers;

  GeoZoneEvent({
    required this.id,
    required this.zoneId,
    required this.userId,
    required this.eventType,
    required this.location,
    required this.timestamp,
    this.alertSent = false,
    this.notifiedCaregivers = const [],
  });

  factory GeoZoneEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GeoZoneEvent(
      id: doc.id,
      zoneId: data['zoneId'] ?? '',
      userId: data['userId'] ?? '',
      eventType: GeoZoneEventType.fromString(data['eventType'] ?? 'enter'),
      location: data['location'] ?? const GeoPoint(0, 0),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      alertSent: data['alertSent'] ?? false,
      notifiedCaregivers: List<String>.from(data['notifiedCaregivers'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'zoneId': zoneId,
      'userId': userId,
      'eventType': eventType.value,
      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'alertSent': alertSent,
      'notifiedCaregivers': notifiedCaregivers,
    };
  }
}

enum GeoZoneEventType {
  enter('enter'),
  exit('exit'),
  dwell('dwell'); // Stayed in zone for extended time

  final String value;
  const GeoZoneEventType(this.value);

  static GeoZoneEventType fromString(String value) {
    return GeoZoneEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GeoZoneEventType.enter,
    );
  }
}

/// Real-time location tracking record
class LocationUpdate {
  final String id;
  final String oderId;
  final GeoPoint location;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final DateTime timestamp;

  LocationUpdate({
    required this.id,
    required this.oderId,
    required this.location,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
    required this.timestamp,
  });

  factory LocationUpdate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationUpdate(
      id: doc.id,
      oderId: data['userId'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      accuracy: data['accuracy']?.toDouble(),
      speed: data['speed']?.toDouble(),
      heading: data['heading']?.toDouble(),
      altitude: data['altitude']?.toDouble(),
      batteryLevel: data['batteryLevel'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': oderId,
      'location': location,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
      'batteryLevel': batteryLevel,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

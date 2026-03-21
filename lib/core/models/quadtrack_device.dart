import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a QuadTrack hardware device — a self-charging GPS tracker
/// that fits into a Quad Lock phone case ring insert.
class QuadTrackDevice {
  final String id;
  final String deviceId; // Hardware serial / IMEI
  final String name; // User-friendly name, e.g. "Mom's Phone"
  final String patientId; // The user (patient) this tracker monitors
  final List<String> caregiverIds; // Who can see this tracker
  final String registeredBy; // Caregiver who set it up

  // Location
  final GeoPoint? lastLocation;
  final double? lastAccuracy;
  final DateTime? lastSeenAt;
  final LocationSource lastSource;

  // Battery & charging
  final int trackerBatteryLevel; // 0-100 — QuadTrack's own battery
  final int? phoneBatteryLevel; // 0-100 — host phone battery (from companion)
  final ChargingState chargingState;

  // Tracking
  final TrackingMode trackingMode;
  final DeviceStatus status;
  final String? firmwareVersion;

  // Emergency tracking
  final int? emergencyIntervalMinutes; // Current interval when in emergency mode
  final DateTime? emergencyActivatedAt;
  final String? emergencyActivatedBy;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  QuadTrackDevice({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.patientId,
    this.caregiverIds = const [],
    required this.registeredBy,
    this.lastLocation,
    this.lastAccuracy,
    this.lastSeenAt,
    this.lastSource = LocationSource.gps,
    this.trackerBatteryLevel = 100,
    this.phoneBatteryLevel,
    this.chargingState = ChargingState.unknown,
    this.trackingMode = TrackingMode.normal,
    this.status = DeviceStatus.offline,
    this.firmwareVersion,
    this.emergencyIntervalMinutes,
    this.emergencyActivatedAt,
    this.emergencyActivatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Whether the host phone appears to be dead
  bool get isPhoneDead =>
      phoneBatteryLevel != null && phoneBatteryLevel == 0 ||
      (status == DeviceStatus.phoneDead);

  /// Whether the tracker battery is critically low
  bool get isBatteryLow => trackerBatteryLevel < 20;

  /// Human-readable last-seen string
  String get lastSeenAgo {
    if (lastSeenAt == null) return 'Never';
    final diff = DateTime.now().difference(lastSeenAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  factory QuadTrackDevice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuadTrackDevice(
      id: doc.id,
      deviceId: data['deviceId'] ?? '',
      name: data['name'] ?? '',
      patientId: data['patientId'] ?? '',
      caregiverIds: List<String>.from(data['caregiverIds'] ?? []),
      registeredBy: data['registeredBy'] ?? '',
      lastLocation: data['lastLocation'] as GeoPoint?,
      lastAccuracy: data['lastAccuracy']?.toDouble(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      lastSource: LocationSource.fromString(data['lastSource'] ?? 'gps'),
      trackerBatteryLevel: data['trackerBatteryLevel'] ?? 100,
      phoneBatteryLevel: data['phoneBatteryLevel'],
      chargingState:
          ChargingState.fromString(data['chargingState'] ?? 'unknown'),
      trackingMode:
          TrackingMode.fromString(data['trackingMode'] ?? 'normal'),
      status: DeviceStatus.fromString(data['status'] ?? 'offline'),
      firmwareVersion: data['firmwareVersion'],
      emergencyIntervalMinutes: data['emergencyIntervalMinutes'],
      emergencyActivatedAt: (data['emergencyActivatedAt'] as Timestamp?)?.toDate(),
      emergencyActivatedBy: data['emergencyActivatedBy'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'name': name,
      'patientId': patientId,
      'caregiverIds': caregiverIds,
      'registeredBy': registeredBy,
      'lastLocation': lastLocation,
      'lastAccuracy': lastAccuracy,
      'lastSeenAt':
          lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
      'lastSource': lastSource.value,
      'trackerBatteryLevel': trackerBatteryLevel,
      'phoneBatteryLevel': phoneBatteryLevel,
      'chargingState': chargingState.value,
      'trackingMode': trackingMode.value,
      'status': status.value,
      'firmwareVersion': firmwareVersion,
      'emergencyIntervalMinutes': emergencyIntervalMinutes,
      'emergencyActivatedAt': emergencyActivatedAt != null
          ? Timestamp.fromDate(emergencyActivatedAt!)
          : null,
      'emergencyActivatedBy': emergencyActivatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  QuadTrackDevice copyWith({
    String? name,
    List<String>? caregiverIds,
    GeoPoint? lastLocation,
    double? lastAccuracy,
    DateTime? lastSeenAt,
    LocationSource? lastSource,
    int? trackerBatteryLevel,
    int? phoneBatteryLevel,
    ChargingState? chargingState,
    TrackingMode? trackingMode,
    DeviceStatus? status,
    String? firmwareVersion,
    int? emergencyIntervalMinutes,
    DateTime? emergencyActivatedAt,
    String? emergencyActivatedBy,
  }) {
    return QuadTrackDevice(
      id: id,
      deviceId: deviceId,
      name: name ?? this.name,
      patientId: patientId,
      caregiverIds: caregiverIds ?? this.caregiverIds,
      registeredBy: registeredBy,
      lastLocation: lastLocation ?? this.lastLocation,
      lastAccuracy: lastAccuracy ?? this.lastAccuracy,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSource: lastSource ?? this.lastSource,
      trackerBatteryLevel:
          trackerBatteryLevel ?? this.trackerBatteryLevel,
      phoneBatteryLevel: phoneBatteryLevel ?? this.phoneBatteryLevel,
      chargingState: chargingState ?? this.chargingState,
      trackingMode: trackingMode ?? this.trackingMode,
      status: status ?? this.status,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      emergencyIntervalMinutes:
          emergencyIntervalMinutes ?? this.emergencyIntervalMinutes,
      emergencyActivatedAt:
          emergencyActivatedAt ?? this.emergencyActivatedAt,
      emergencyActivatedBy:
          emergencyActivatedBy ?? this.emergencyActivatedBy,
      createdAt: createdAt,
    );
  }
}

// ─── Enums ──────────────────────────────────────────────────

enum TrackingMode {
  normal('normal', 'Normal', 30),       // 30-min intervals
  emergency('emergency', 'Emergency', 5), // 5-min intervals (default, can be overridden by battery level)
  idle('idle', 'Idle', 240);             // 4-hour intervals

  final String value;
  final String displayName;
  final int intervalMinutes; // Default interval, overridden by emergencyIntervalMinutes when in emergency

  const TrackingMode(this.value, this.displayName, this.intervalMinutes);

  static TrackingMode fromString(String value) {
    return TrackingMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TrackingMode.normal,
    );
  }
}

enum DeviceStatus {
  online('online', 'Online'),
  offline('offline', 'Offline'),
  sleeping('sleeping', 'Sleeping'),
  phoneDead('phone_dead', 'Phone Dead'),
  lowBattery('low_battery', 'Low Battery');

  final String value;
  final String displayName;
  const DeviceStatus(this.value, this.displayName);

  static DeviceStatus fromString(String value) {
    return DeviceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceStatus.offline,
    );
  }
}

enum ChargingState {
  chargingQi('charging_qi', 'Wireless Charging'),
  chargingReverse('charging_reverse', 'Reverse Charging'),
  chargingPogo('charging_pogo', 'Pogo Pin Charging'),
  onBattery('on_battery', 'On Battery'),
  unknown('unknown', 'Unknown');

  final String value;
  final String displayName;
  const ChargingState(this.value, this.displayName);

  static ChargingState fromString(String value) {
    return ChargingState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChargingState.unknown,
    );
  }
}

enum LocationSource {
  gps('gps'),
  wifi('wifi'),
  cell('cell');

  final String value;
  const LocationSource(this.value);

  static LocationSource fromString(String value) {
    return LocationSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LocationSource.gps,
    );
  }
}

/// A single location ping from the QuadTrack hardware
class QuadTrackPing {
  final String id;
  final String deviceId;
  final GeoPoint location;
  final double? accuracy;
  final double? altitude;
  final int batteryLevel;
  final int? phoneBatteryLevel;
  final ChargingState chargingState;
  final LocationSource source;
  final DateTime timestamp;

  QuadTrackPing({
    required this.id,
    required this.deviceId,
    required this.location,
    this.accuracy,
    this.altitude,
    required this.batteryLevel,
    this.phoneBatteryLevel,
    this.chargingState = ChargingState.unknown,
    this.source = LocationSource.gps,
    required this.timestamp,
  });

  factory QuadTrackPing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuadTrackPing(
      id: doc.id,
      deviceId: data['deviceId'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      accuracy: data['accuracy']?.toDouble(),
      altitude: data['altitude']?.toDouble(),
      batteryLevel: data['batteryLevel'] ?? 0,
      phoneBatteryLevel: data['phoneBatteryLevel'],
      chargingState:
          ChargingState.fromString(data['chargingState'] ?? 'unknown'),
      source: LocationSource.fromString(data['source'] ?? 'gps'),
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'location': location,
      'accuracy': accuracy,
      'altitude': altitude,
      'batteryLevel': batteryLevel,
      'phoneBatteryLevel': phoneBatteryLevel,
      'chargingState': chargingState.value,
      'source': source.value,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

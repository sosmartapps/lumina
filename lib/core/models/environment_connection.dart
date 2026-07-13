import 'package:cloud_firestore/cloud_firestore.dart';

/// A family's home-environment (temperature/humidity) provider links for
/// one patient.
///
/// Stored at `environment_connections/{patientUserId}` (doc id = patient),
/// mirroring the Bouncie pattern. A patient can have BOTH providers linked
/// (e.g. a SensorPush in the bedroom and a Nest thermostat in the hall).
///
/// Durable credentials:
///  - SensorPush: the account `authorization` token from the Gateway Cloud
///    API oauth/authorize step (re-exchangeable for access tokens; the
///    caregiver's password is NEVER stored).
///  - Nest: the Google OAuth `refreshToken` for the SDM API.
///
/// The `pollEnvironment` Cloud Function polls providers on a schedule,
/// appends history to `users/{id}/environment_readings`, and keeps
/// [latest] up to date so the dashboard card is instant.
class EnvironmentConnection {
  /// Patient (Lumina user) this home belongs to. Also the doc id.
  final String userId;

  final SensorPushLink? sensorPush;
  final NestLink? nest;
  final EnvironmentAlertConfig alerts;
  final EnvironmentReadingSnapshot? latest;

  EnvironmentConnection({
    required this.userId,
    this.sensorPush,
    this.nest,
    EnvironmentAlertConfig? alerts,
    this.latest,
  }) : alerts = alerts ?? EnvironmentAlertConfig();

  bool get hasAnyProvider => sensorPush != null || nest != null;

  factory EnvironmentConnection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EnvironmentConnection(
      userId: doc.id,
      sensorPush: data['sensorpush'] is Map
          ? SensorPushLink.fromMap(
              Map<String, dynamic>.from(data['sensorpush']))
          : null,
      nest: data['nest'] is Map
          ? NestLink.fromMap(Map<String, dynamic>.from(data['nest']))
          : null,
      alerts: data['alerts'] is Map
          ? EnvironmentAlertConfig.fromMap(
              Map<String, dynamic>.from(data['alerts']))
          : EnvironmentAlertConfig(),
      latest: data['latest'] is Map
          ? EnvironmentReadingSnapshot.fromMap(
              Map<String, dynamic>.from(data['latest']))
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (sensorPush != null) 'sensorpush': sensorPush!.toMap(),
      if (nest != null) 'nest': nest!.toMap(),
      'alerts': alerts.toMap(),
      if (latest != null) 'latest': latest!.toMap(),
    };
  }
}

/// SensorPush Gateway Cloud API account link + chosen sensor.
class SensorPushLink {
  /// Long-lived authorization token from oauth/authorize (NOT the password).
  final String authorization;
  final String sensorId;
  final String? sensorName;
  final String connectedBy; // caregiver uid
  final DateTime connectedAt;

  /// Set by the poller when the authorization stops working — the caregiver
  /// must re-link. Cleared on successful re-link.
  final bool needsReauth;

  SensorPushLink({
    required this.authorization,
    required this.sensorId,
    this.sensorName,
    required this.connectedBy,
    DateTime? connectedAt,
    this.needsReauth = false,
  }) : connectedAt = connectedAt ?? DateTime.now();

  factory SensorPushLink.fromMap(Map<String, dynamic> data) {
    return SensorPushLink(
      authorization: data['authorization'] ?? '',
      sensorId: data['sensorId'] ?? '',
      sensorName: data['sensorName'],
      connectedBy: data['connectedBy'] ?? '',
      connectedAt:
          (data['connectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      needsReauth: data['needsReauth'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorization': authorization,
      'sensorId': sensorId,
      'sensorName': sensorName,
      'connectedBy': connectedBy,
      'connectedAt': Timestamp.fromDate(connectedAt),
      'needsReauth': needsReauth,
    };
  }
}

/// Google Nest (Smart Device Management API) thermostat link.
class NestLink {
  /// Google OAuth refresh token scoped to sdm.service.
  final String refreshToken;

  /// Full SDM device name, e.g.
  /// `enterprises/{projectId}/devices/{deviceId}`.
  final String deviceName;
  final String? displayName;
  final String connectedBy; // caregiver uid
  final DateTime connectedAt;
  final bool needsReauth;

  NestLink({
    required this.refreshToken,
    required this.deviceName,
    this.displayName,
    required this.connectedBy,
    DateTime? connectedAt,
    this.needsReauth = false,
  }) : connectedAt = connectedAt ?? DateTime.now();

  factory NestLink.fromMap(Map<String, dynamic> data) {
    return NestLink(
      refreshToken: data['refreshToken'] ?? '',
      deviceName: data['deviceName'] ?? '',
      displayName: data['displayName'],
      connectedBy: data['connectedBy'] ?? '',
      connectedAt:
          (data['connectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      needsReauth: data['needsReauth'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'refreshToken': refreshToken,
      'deviceName': deviceName,
      'displayName': displayName,
      'connectedBy': connectedBy,
      'connectedAt': Timestamp.fromDate(connectedAt),
      'needsReauth': needsReauth,
    };
  }
}

/// Caregiver-configurable alert thresholds. Defaults are sensible for an
/// elderly person's home (heat stress + mold/dryness bands).
class EnvironmentAlertConfig {
  final bool enabled;
  final double minTempF;
  final double maxTempF;
  final double minHumidity;
  final double maxHumidity;

  EnvironmentAlertConfig({
    this.enabled = true,
    this.minTempF = 60,
    this.maxTempF = 85,
    this.minHumidity = 20,
    this.maxHumidity = 70,
  });

  factory EnvironmentAlertConfig.fromMap(Map<String, dynamic> data) {
    return EnvironmentAlertConfig(
      enabled: data['enabled'] != false,
      minTempF: (data['minTempF'] as num?)?.toDouble() ?? 60,
      maxTempF: (data['maxTempF'] as num?)?.toDouble() ?? 85,
      minHumidity: (data['minHumidity'] as num?)?.toDouble() ?? 20,
      maxHumidity: (data['maxHumidity'] as num?)?.toDouble() ?? 70,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'minTempF': minTempF,
      'maxTempF': maxTempF,
      'minHumidity': minHumidity,
      'maxHumidity': maxHumidity,
    };
  }

  EnvironmentAlertConfig copyWith({
    bool? enabled,
    double? minTempF,
    double? maxTempF,
    double? minHumidity,
    double? maxHumidity,
  }) {
    return EnvironmentAlertConfig(
      enabled: enabled ?? this.enabled,
      minTempF: minTempF ?? this.minTempF,
      maxTempF: maxTempF ?? this.maxTempF,
      minHumidity: minHumidity ?? this.minHumidity,
      maxHumidity: maxHumidity ?? this.maxHumidity,
    );
  }
}

/// Most recent reading, denormalized onto the connection doc so the
/// dashboard card renders instantly from the existing stream.
class EnvironmentReadingSnapshot {
  final double tempF;
  final double humidity; // % RH
  final DateTime observedAt;
  final String provider; // 'sensorpush' | 'nest'
  final String? sensorName;

  EnvironmentReadingSnapshot({
    required this.tempF,
    required this.humidity,
    required this.observedAt,
    required this.provider,
    this.sensorName,
  });

  factory EnvironmentReadingSnapshot.fromMap(Map<String, dynamic> data) {
    return EnvironmentReadingSnapshot(
      tempF: (data['tempF'] as num?)?.toDouble() ?? 0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0,
      observedAt:
          (data['observedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      provider: data['provider'] ?? '',
      sensorName: data['sensorName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tempF': tempF,
      'humidity': humidity,
      'observedAt': Timestamp.fromDate(observedAt),
      'provider': provider,
      'sensorName': sensorName,
    };
  }
}

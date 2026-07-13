import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../core/models/environment_connection.dart';

/// Home-environment (temperature/humidity) provider integrations.
///
/// Two providers, both cloud-to-cloud (no BLE — unlike So Smart Scans,
/// which talks to SensorPush over Bluetooth GATT during a scan):
///  - SensorPush Gateway Cloud API (https://www.sensorpush.com/gateway-cloud-api)
///  - Google Nest Smart Device Management API (thermostat temp + humidity)
///
/// Linking runs client-side (same as Bouncie): the caregiver signs in to
/// THEIR provider account; only durable tokens are stored in
/// `environment_connections/{patientId}` — never passwords.
/// NOTE: endpoint shapes follow the published API docs + community
/// libraries, but are NOT yet verified against a live account.

// ─── SensorPush Gateway Cloud API ─────────────────────────────────────────

class SensorPushApi {
  static const String _base = 'https://api.sensorpush.com/api/v1';

  /// Step 1: exchange the caregiver's SensorPush email/password for a
  /// long-lived `authorization` token. The password is used once, in
  /// memory, and never persisted.
  static Future<String> authorize(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/oauth/authorize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw Exception('SensorPush sign-in failed (${res.statusCode})');
    }
    final auth = (jsonDecode(res.body) as Map)['authorization'] as String?;
    if (auth == null || auth.isEmpty) {
      throw Exception('SensorPush sign-in returned no authorization');
    }
    return auth;
  }

  /// Step 2: exchange the authorization token for a short-lived access token.
  static Future<String> accessToken(String authorization) async {
    final res = await http.post(
      Uri.parse('$_base/oauth/accesstoken'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'authorization': authorization}),
    );
    if (res.statusCode != 200) {
      throw Exception('SensorPush token exchange failed (${res.statusCode})');
    }
    final token = (jsonDecode(res.body) as Map)['accesstoken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('SensorPush returned no access token');
    }
    return token;
  }

  /// All sensors on the account: `[{id, name, active}]`.
  static Future<List<Map<String, dynamic>>> listSensors(
      String accessToken) async {
    final res = await http.post(
      Uri.parse('$_base/devices/sensors'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': accessToken,
      },
      body: jsonEncode({}),
    );
    if (res.statusCode != 200) {
      throw Exception('SensorPush sensors fetch failed (${res.statusCode})');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return map.entries
        .map((e) => {
              'id': e.key,
              'name': (e.value as Map)['name'] ?? e.key,
              'active': (e.value as Map)['active'] != false,
            })
        .toList();
  }

  /// Latest sample for one sensor. SensorPush samples report temperature
  /// in °F and humidity in % RH.
  static Future<EnvironmentReadingSnapshot?> latestSample(
      String accessToken, String sensorId, String? sensorName) async {
    final res = await http.post(
      Uri.parse('$_base/samples'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': accessToken,
      },
      body: jsonEncode({
        'limit': 1,
        'sensors': [sensorId],
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('SensorPush samples fetch failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sensors = body['sensors'] as Map<String, dynamic>? ?? {};
    final samples = sensors[sensorId] as List? ?? [];
    if (samples.isEmpty) return null;
    final s = samples.first as Map<String, dynamic>;
    return EnvironmentReadingSnapshot(
      tempF: (s['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (s['humidity'] as num?)?.toDouble() ?? 0,
      observedAt: DateTime.tryParse(s['observed'] ?? '') ?? DateTime.now(),
      provider: 'sensorpush',
      sensorName: sensorName,
    );
  }
}

// ─── Google Nest SDM API ──────────────────────────────────────────────────

class NestApi {
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _sdmBase =
      'https://smartdevicemanagement.googleapis.com/v1';

  /// URL the caregiver visits to authorize Lumina against THEIR Google
  /// account (Device Access partner-connections flow).
  static String authorizeUrl({
    required String projectId,
    required String clientId,
    required String redirectUri,
  }) =>
      'https://nestservices.google.com/partnerconnections/$projectId/auth'
      '?redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&access_type=offline&prompt=consent&client_id=$clientId'
      '&response_type=code'
      '&scope=${Uri.encodeComponent('https://www.googleapis.com/auth/sdm.service')}';

  /// Exchange a pasted authorization code → (accessToken, refreshToken).
  static Future<({String accessToken, String refreshToken})> exchangeCode({
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    required String code,
  }) async {
    final res = await http.post(Uri.parse(_tokenUrl), body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
    });
    if (res.statusCode != 200) {
      throw Exception('Google token exchange failed (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw Exception('Google did not return tokens — try again and make '
          'sure you approve all permissions');
    }
    return (accessToken: access, refreshToken: refresh);
  }

  static Future<String> refreshAccessToken({
    required String clientId,
    required String clientSecret,
    required String refreshToken,
  }) async {
    final res = await http.post(Uri.parse(_tokenUrl), body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    if (res.statusCode != 200) {
      throw Exception('Google token refresh failed (${res.statusCode})');
    }
    return (jsonDecode(res.body) as Map)['access_token'] as String;
  }

  /// Thermostats on the account with their current readings:
  /// `[{name, displayName, tempF, humidity}]`.
  static Future<List<Map<String, dynamic>>> listThermostats(
      String accessToken, String projectId) async {
    final res = await http.get(
      Uri.parse('$_sdmBase/enterprises/$projectId/devices'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw Exception('Nest devices fetch failed (${res.statusCode})');
    }
    final devices =
        ((jsonDecode(res.body) as Map)['devices'] as List? ?? []);
    return devices
        .cast<Map<String, dynamic>>()
        .where((d) =>
            (d['type'] as String? ?? '').endsWith('THERMOSTAT') ||
            _readTraits(d) != null)
        .map((d) {
      final reading = _readTraits(d);
      final parentRelations = d['parentRelations'] as List? ?? [];
      final room = parentRelations.isNotEmpty
          ? (parentRelations.first as Map)['displayName'] as String?
          : null;
      return {
        'name': d['name'],
        'displayName': room ?? 'Thermostat',
        'tempF': reading?.tempF,
        'humidity': reading?.humidity,
      };
    }).toList();
  }

  /// Current reading for one device.
  static Future<EnvironmentReadingSnapshot?> readDevice(
      String accessToken, String deviceName, String? displayName) async {
    final res = await http.get(
      Uri.parse('$_sdmBase/$deviceName'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw Exception('Nest device fetch failed (${res.statusCode})');
    }
    final device = jsonDecode(res.body) as Map<String, dynamic>;
    final reading = _readTraits(device);
    if (reading == null) return null;
    return EnvironmentReadingSnapshot(
      tempF: reading.tempF,
      humidity: reading.humidity,
      observedAt: DateTime.now(),
      provider: 'nest',
      sensorName: displayName,
    );
  }

  static ({double tempF, double humidity})? _readTraits(
      Map<String, dynamic> device) {
    final traits = device['traits'] as Map<String, dynamic>? ?? {};
    final temp = traits['sdm.devices.traits.Temperature']
        as Map<String, dynamic>?;
    final hum = traits['sdm.devices.traits.Humidity'] as Map<String, dynamic>?;
    final tempC = (temp?['ambientTemperatureCelsius'] as num?)?.toDouble();
    if (tempC == null) return null;
    return (
      tempF: tempC * 9 / 5 + 32,
      humidity:
          (hum?['ambientHumidityPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ─── Firestore-facing service ─────────────────────────────────────────────

class EnvironmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String patientId) =>
      _firestore.collection('environment_connections').doc(patientId);

  Future<void> saveSensorPushLink(String patientId, SensorPushLink link) {
    return _doc(patientId).set({'sensorpush': link.toMap()},
        SetOptions(merge: true));
  }

  Future<void> saveNestLink(String patientId, NestLink link) {
    return _doc(patientId)
        .set({'nest': link.toMap()}, SetOptions(merge: true));
  }

  Future<void> saveBleLink(String patientId, BleLink link) {
    return _doc(patientId)
        .set({'ble': link.toMap()}, SetOptions(merge: true));
  }

  Future<void> unlinkProvider(String patientId, String provider) async {
    await _doc(patientId).update({provider: FieldValue.delete()});
    // Remove the whole doc if nothing is linked anymore.
    final snap = await _doc(patientId).get();
    final data = snap.data();
    if (data != null &&
        data['sensorpush'] == null &&
        data['nest'] == null &&
        data['ble'] == null) {
      await _doc(patientId).delete();
    }
  }

  Future<void> saveAlertConfig(
      String patientId, EnvironmentAlertConfig config) {
    return _doc(patientId)
        .set({'alerts': config.toMap()}, SetOptions(merge: true));
  }

  /// Live client-side refresh (the card's refresh button / auto-refresh).
  /// Prefers SensorPush (dedicated sensor) and falls back to Nest.
  /// Writes the result to `latest` so all caregivers' cards update.
  Future<EnvironmentReadingSnapshot?> refreshLatest(
    EnvironmentConnection connection,
    ({String clientId, String clientSecret, String projectId, String redirectUri})
        nestConfig,
  ) async {
    EnvironmentReadingSnapshot? reading;

    final sp = connection.sensorPush;
    if (sp != null && !sp.needsReauth) {
      try {
        final token = await SensorPushApi.accessToken(sp.authorization);
        reading = await SensorPushApi.latestSample(
            token, sp.sensorId, sp.sensorName);
      } catch (_) {
        // fall through to Nest
      }
    }

    final nest = connection.nest;
    if (reading == null &&
        nest != null &&
        !nest.needsReauth &&
        nestConfig.clientId.isNotEmpty) {
      final token = await NestApi.refreshAccessToken(
        clientId: nestConfig.clientId,
        clientSecret: nestConfig.clientSecret,
        refreshToken: nest.refreshToken,
      );
      reading =
          await NestApi.readDevice(token, nest.deviceName, nest.displayName);
    }

    if (reading != null) {
      await _doc(connection.userId)
          .set({'latest': reading.toMap()}, SetOptions(merge: true));
    }
    return reading;
  }
}

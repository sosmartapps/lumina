import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

/// Bouncie REST API v1 integration.
/// Docs: https://docs.bouncie.dev
/// Auth: OAuth 2.0 — re-exchanges authorization code when token expires.
class BouncieService {
  static const String _baseUrl = 'https://api.bouncie.dev/v1';
  static const String _tokenUrl = 'https://auth.bouncie.com/oauth/token';
  static const String _tokenKey = 'bouncie_access_token';
  static const String _tokenExpiryKey = 'bouncie_token_expiry';

  final String clientId;
  final String clientSecret;
  final String authCode;
  final String redirectUri;

  String? _accessToken;
  DateTime? _tokenExpiry;

  BouncieService({
    required this.clientId,
    required this.clientSecret,
    required this.authCode,
    required this.redirectUri,
  });

  // ─── Token Management ───────────────────────────────────────────────────

  /// Returns a valid access token, refreshing if needed.
  Future<String> getToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _accessToken!;
    }

    // Try loading cached token from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_tokenKey);
    final cachedExpiry = prefs.getInt(_tokenExpiryKey);
    if (cached != null && cachedExpiry != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(cachedExpiry);
      if (DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 5)))) {
        _accessToken = cached;
        _tokenExpiry = expiry;
        return cached;
      }
    }

    // Exchange auth code for a fresh token.
    return _exchangeAuthCode();
  }

  Future<String> _exchangeAuthCode() async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'authorization_code',
        'code': authCode,
        'redirect_uri': redirectUri,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Bouncie token exchange failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    // Cache for reuse across app restarts.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _accessToken!);
    await prefs.setInt(_tokenExpiryKey, _tokenExpiry!.millisecondsSinceEpoch);

    return _accessToken!;
  }

  // ─── API Helpers ────────────────────────────────────────────────────────

  Future<http.Response> _authGet(String path) async {
    final token = await getToken();
    return http.get(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );
  }

  // ─── Vehicle Data ──────────────────────────────────────────────────────

  /// Fetches all vehicles on the account.
  Future<List<Map<String, dynamic>>> getVehicles() async {
    final response = await _authGet('/vehicles');
    if (response.statusCode != 200) {
      throw Exception('Bouncie API error: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  /// Fetches data for a single vehicle by IMEI.
  Future<Map<String, dynamic>> getVehicleData(String imei) async {
    final vehicles = await getVehicles();
    return vehicles.firstWhere(
      (v) => v['imei'] == imei,
      orElse: () => throw Exception('Vehicle $imei not found'),
    );
  }

  /// Returns latest GPS coordinates from Bouncie.
  Future<LatLng?> getVehicleLocation(String imei) async {
    final data = await getVehicleData(imei);
    final stats = data['stats'] as Map<String, dynamic>?;
    final location = stats?['location'] as Map<String, dynamic>?;
    if (location == null) return null;
    return LatLng(
      (location['lat'] as num).toDouble(),
      (location['lon'] as num).toDouble(),
    );
  }

  /// Returns fuel level as 0.0–1.0, or null if unavailable.
  Future<double?> getFuelLevel(String imei) async {
    final data = await getVehicleData(imei);
    final stats = data['stats'] as Map<String, dynamic>?;
    final rawFuel = stats?['fuelLevel'];
    if (rawFuel == null) return null;
    return (rawFuel as num).toDouble() / 100.0;
  }

  /// Returns whether the vehicle engine is currently running.
  Future<bool> isRunning(String imei) async {
    final data = await getVehicleData(imei);
    final stats = data['stats'] as Map<String, dynamic>?;
    return stats?['isRunning'] == true;
  }

  /// Returns the vehicle's current speed in mph.
  Future<double> getSpeed(String imei) async {
    final data = await getVehicleData(imei);
    final stats = data['stats'] as Map<String, dynamic>?;
    return (stats?['speed'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns battery health status string.
  Future<String> getBatteryStatus(String imei) async {
    final data = await getVehicleData(imei);
    final stats = data['stats'] as Map<String, dynamic>?;
    final battery = stats?['battery'] as Map<String, dynamic>?;
    return battery?['status'] as String? ?? 'unknown';
  }

  /// Returns whether check-engine light (MIL) is on.
  Future<bool> isMilOn(String imei) async {
    final data = await getVehicleData(imei);
    final stats = data['stats'] as Map<String, dynamic>?;
    final mil = stats?['mil'] as Map<String, dynamic>?;
    return mil?['milOn'] == true;
  }

  // ─── Periodic Polling Stream ───────────────────────────────────────────

  /// Emits full vehicle data every [interval].
  Stream<Map<String, dynamic>> vehicleStream(
    String imei, {
    Duration interval = const Duration(seconds: 60),
  }) {
    return Stream.periodic(interval).asyncMap((_) => getVehicleData(imei));
  }
}

// ─── Location Sync Checker ────────────────────────────────────────────────

class LocationSyncChecker {
  /// Threshold in meters before raising a mismatch alert.
  final double maxDistanceMeters;

  const LocationSyncChecker({this.maxDistanceMeters = 500.0});

  Future<bool> isPhoneNearVehicle({
    required LatLng phoneLocation,
    required LatLng vehicleLocation,
  }) async {
    final distance = Geolocator.distanceBetween(
      phoneLocation.latitude,
      phoneLocation.longitude,
      vehicleLocation.latitude,
      vehicleLocation.longitude,
    );
    return distance <= maxDistanceMeters;
  }

  Future<SyncCheckResult> check({
    required LatLng phoneLocation,
    required LatLng vehicleLocation,
  }) async {
    final inSync = await isPhoneNearVehicle(
      phoneLocation: phoneLocation,
      vehicleLocation: vehicleLocation,
    );
    final distance = Geolocator.distanceBetween(
      phoneLocation.latitude,
      phoneLocation.longitude,
      vehicleLocation.latitude,
      vehicleLocation.longitude,
    );
    return SyncCheckResult(
      inSync: inSync,
      distanceMeters: distance,
      phoneLocation: phoneLocation,
      vehicleLocation: vehicleLocation,
      timestamp: DateTime.now(),
    );
  }
}

class SyncCheckResult {
  final bool inSync;
  final double distanceMeters;
  final LatLng phoneLocation;
  final LatLng vehicleLocation;
  final DateTime timestamp;

  const SyncCheckResult({
    required this.inSync,
    required this.distanceMeters,
    required this.phoneLocation,
    required this.vehicleLocation,
    required this.timestamp,
  });
}

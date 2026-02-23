import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_launcher/map_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FuelMonitor {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final String googlePlacesApiKey;

  // Keys
  static const _thresholdKey = 'fuel_threshold';
  static const _lastAlertKey = 'fuel_last_alert';
  static const _alertCooldownMinutes = 30;

  FuelMonitor({required this.googlePlacesApiKey});

  // ─── Threshold ────────────────────────────────────────────────────────────

  Future<double> getThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_thresholdKey) ?? 0.20;
  }

  Future<void> setThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdKey, value.clamp(0.05, 0.50));
  }

  // ─── Check ────────────────────────────────────────────────────────────────

  /// Call this each time Bouncie emits a fuel level (0.0–1.0).
  Future<void> checkFuelLevel(double fuelPercent) async {
    final threshold = await getThreshold();
    if (fuelPercent > threshold) return;

    // Cooldown check
    final prefs = await SharedPreferences.getInstance();
    final lastAlert = prefs.getString(_lastAlertKey);
    if (lastAlert != null) {
      final lastTime = DateTime.parse(lastAlert);
      if (DateTime.now().difference(lastTime).inMinutes <
          _alertCooldownMinutes) {
        return;
      }
    }
    await prefs.setString(_lastAlertKey, DateTime.now().toIso8601String());

    final pct = (fuelPercent * 100).toStringAsFixed(0);

    await _sendLocalNotification(
      title: '⛽ Low Fuel – $pct%',
      body: 'Finding nearest gas station…',
    );

    await _navigateToNearestStation();
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  Future<void> _navigateToNearestStation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) return;

    final position = await Geolocator.getCurrentPosition();

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&rankby=distance'
      '&type=gas_station'
      '&key=$googlePlacesApiKey',
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;
    if (results.isEmpty) return;

    final station = results.first as Map<String, dynamic>;
    final loc = station['geometry']['location'] as Map<String, dynamic>;
    final name = station['name'] as String;
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();

    final availableMaps = await MapLauncher.installedMaps;
    if (availableMaps.isEmpty) return;

    // Prefer Apple Maps on iOS, fall back to first available.
    final targetMap = availableMaps.firstWhere(
      (m) => m.mapType == MapType.apple,
      orElse: () => availableMaps.first,
    );

    await targetMap.showDirections(
      destination: Coords(lat, lng),
      destinationTitle: name,
    );
  }

  Future<void> _sendLocalNotification({
    required String title,
    required String body,
  }) async {
    const iosDetails = DarwinNotificationDetails(presentAlert: true);
    await _notifications.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(iOS: iosDetails),
    );
  }
}

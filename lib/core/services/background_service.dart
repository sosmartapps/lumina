import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';

/// Background service for continuous location monitoring, geofence checks,
/// and sundown alerts when the app is not in the foreground.
class BackgroundMonitoringService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Initialize and start the background service
  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.location],
        notificationChannelId: 'lumina_background',
        initialNotificationTitle: 'Lumina',
        initialNotificationContent: 'Monitoring your safety',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Start the service if not already running
  static Future<void> start() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
  }

  /// Stop the background service
  static Future<void> stop() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stop');
    }
  }
}

/// iOS background handler — must be a top-level function
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point — must be a top-level function
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Firebase in the background isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  Timer? locationTimer;

  // Handle stop command
  service.on('stop').listen((_) {
    locationTimer?.cancel();
    service.stopSelf();
  });

  // Get stored user ID
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('currentUserId');
  if (userId == null) {
    debugPrint('BackgroundService: No user ID found, stopping');
    service.stopSelf();
    return;
  }

  // Periodic location update and safety check (every 2 minutes)
  locationTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Update location in Firestore
      await firestore.collection('users').doc(userId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      // Save to location history
      await firestore
          .collection('users')
          .doc(userId)
          .collection('location_updates')
          .add({
        'location': GeoPoint(position.latitude, position.longitude),
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'altitude': position.altitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Check geofence zones
      await _checkGeofences(firestore, userId, position);

      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Lumina',
          content: 'Safety monitoring active',
        );
      }
    } catch (e) {
      debugPrint('BackgroundService error: $e');
    }
  });
}

/// Check if the user has crossed any geofence boundaries
Future<void> _checkGeofences(
  FirebaseFirestore firestore,
  String userId,
  Position position,
) async {
  try {
    final zonesSnapshot = await firestore
        .collection('geo_zones')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in zonesSnapshot.docs) {
      final data = doc.data();
      final center = data['center'] as GeoPoint;
      final radius = (data['radiusMeters'] as num).toDouble();

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        center.latitude,
        center.longitude,
      );

      final isInside = distance <= radius;
      final zoneType = data['type'] as String? ?? 'custom';

      // Store the current state for the foreground app to compare
      await firestore
          .collection('users')
          .doc(userId)
          .collection('zone_states')
          .doc(doc.id)
          .set({
        'isInside': isInside,
        'distance': distance,
        'zoneType': zoneType,
        'zoneName': data['name'],
        'lastChecked': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  } catch (e) {
    debugPrint('BackgroundService geofence check error: $e');
  }
}

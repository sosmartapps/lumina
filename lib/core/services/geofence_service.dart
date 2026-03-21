import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/geo_zone.dart';
import 'notification_service.dart';
import 'location_service.dart';
import '../../features/bouncie/bouncie_service.dart';
import '../../features/bouncie/bouncie_alert_manager.dart';
import '../../features/fuel/fuel_monitor.dart';

/// Service for managing geofencing and zone alerts
class GeofenceServiceWrapper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  Timer? _geofenceCheckTimer;
  String? _currentUserId;
  List<GeoZone> _activeZones = [];
  Map<String, bool> _zoneStates = {}; // Track if user is inside each zone

  // Bouncie vehicle location sync
  BouncieService? _bouncieService;
  String? _vehicleImei;
  final LocationSyncChecker _syncChecker = const LocationSyncChecker();
  final BouncieAlertManager _alertManager = BouncieAlertManager();
  FuelMonitor? _fuelMonitor;

  /// Configure Bouncie vehicle tracking for location sync checks.
  void configureBouncie(BouncieService service, String imei, {FuelMonitor? fuelMonitor}) {
    _bouncieService = service;
    _vehicleImei = imei;
    _fuelMonitor = fuelMonitor;
  }

  /// Initialize geofencing for a user
  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    // Load active zones
    await _loadActiveZones();

    // Start periodic geofence checking
    _startGeofenceMonitoring();

    // Listen for zone changes
    _firestore
        .collection('geo_zones')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _activeZones =
          snapshot.docs.map((doc) => GeoZone.fromFirestore(doc)).toList();
      _initializeZoneStates();
    }, onError: (e) {
      debugPrint('Error listening to zone changes: $e');
    });
  }

  /// Load active zones from Firestore
  Future<void> _loadActiveZones() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('geo_zones')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      _activeZones =
          snapshot.docs.map((doc) => GeoZone.fromFirestore(doc)).toList();
      _initializeZoneStates();
    } catch (e) {
      debugPrint('Error loading active zones: $e');
    }
  }

  /// Initialize zone states based on current position
  Future<void> _initializeZoneStates() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      for (final zone in _activeZones) {
        _zoneStates[zone.id] = _locationService.isPositionInZone(position, zone);
      }
    } catch (e) {
      debugPrint('Error initializing zone states: $e');
    }
  }

  /// Start periodic geofence monitoring
  void _startGeofenceMonitoring() {
    _geofenceCheckTimer?.cancel();
    _geofenceCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkGeofences(),
    );
  }

  /// Check all geofences and vehicle sync
  Future<void> _checkGeofences() async {
    if (_currentUserId == null) return;

    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      // Check geofence zones
      for (final zone in _activeZones) {
        final isInside = _locationService.isPositionInZone(position, zone);
        final wasInside = _zoneStates[zone.id] ?? false;

        if (isInside != wasInside) {
          // State changed
          _zoneStates[zone.id] = isInside;

          if (isInside && zone.alertOnEntry) {
            await _handleZoneEntry(zone, position);
          } else if (!isInside && zone.alertOnExit) {
            await _handleZoneExit(zone, position);
          }
        }
      }

      // Check vehicle-phone location sync
      await _checkVehicleSync(position);
    } catch (e) {
      debugPrint('Error checking geofences: $e');
    }
  }

  /// Compare phone GPS against Bouncie vehicle GPS.
  Future<void> _checkVehicleSync(Position position) async {
    if (_bouncieService == null || _vehicleImei == null) return;

    try {
      // Check fuel level if fuel monitor is configured
      if (_fuelMonitor != null) {
        final fuelLevel = await _bouncieService!.getFuelLevel(_vehicleImei!);
        if (fuelLevel != null) {
          await _fuelMonitor!.checkFuelLevel(fuelLevel);
        }
      }

      final vehicleLocation =
          await _bouncieService!.getVehicleLocation(_vehicleImei!);
      if (vehicleLocation == null) return;

      final phoneLocation = ll.LatLng(position.latitude, position.longitude);
      final result = await _syncChecker.check(
        phoneLocation: phoneLocation,
        vehicleLocation: vehicleLocation,
      );

      await _alertManager.handleSyncResult(
        result,
        caregiverName: 'Caregiver',
        caregiverWebhookUrl: 'https://us-central1-lumina-sosmartapps.cloudfunctions.net/bouncieWebhook',
      );

      if (!result.inSync) {
        // Also notify via the standard caregiver notification system.
        final distanceMi = (result.distanceMeters / 1609.34).toStringAsFixed(1);
        await NotificationService.notifyCaregivers(
          userId: _currentUserId!,
          title: 'Vehicle Location Mismatch',
          body: 'Phone is $distanceMi mi from vehicle ($vehicleLocation)',
          data: {
            'type': 'vehicle_sync_alert',
            'distanceMeters': result.distanceMeters.toString(),
            'vehicleLat': result.vehicleLocation.latitude.toString(),
            'vehicleLng': result.vehicleLocation.longitude.toString(),
          },
        );
      }
    } catch (e) {
      debugPrint('Error checking vehicle sync: $e');
    }
  }

  /// Handle zone entry
  Future<void> _handleZoneEntry(GeoZone zone, Position position) async {
    debugPrint('Entered zone: ${zone.name}');

    // Create event record
    await _createZoneEvent(
      zone: zone,
      eventType: GeoZoneEventType.enter,
      position: position,
    );

    // Notify caregivers if it's a danger zone
    if (zone.type == GeoZoneType.danger) {
      await NotificationService.notifyCaregivers(
        userId: _currentUserId!,
        title: '⚠️ Alert: Entered Restricted Area',
        body: 'User has entered ${zone.name}',
        data: {
          'type': 'geofence_alert',
          'zoneId': zone.id,
          'zoneName': zone.name,
          'event': 'entry',
        },
      );
    } else {
      await NotificationService.notifyCaregivers(
        userId: _currentUserId!,
        title: '📍 Location Update',
        body: 'User has arrived at ${zone.name}',
        data: {
          'type': 'geofence_info',
          'zoneId': zone.id,
          'zoneName': zone.name,
          'event': 'entry',
        },
      );
    }
  }

  /// Handle zone exit
  Future<void> _handleZoneExit(GeoZone zone, Position position) async {
    debugPrint('Exited zone: ${zone.name}');

    // Create event record
    await _createZoneEvent(
      zone: zone,
      eventType: GeoZoneEventType.exit,
      position: position,
    );

    // Notify caregivers
    final isHighPriority =
        zone.type == GeoZoneType.home || zone.type == GeoZoneType.safe;

    await NotificationService.notifyCaregivers(
      userId: _currentUserId!,
      title: isHighPriority ? '🚨 Alert: Left Safe Zone' : '📍 Location Update',
      body: 'User has left ${zone.name}',
      data: {
        'type': isHighPriority ? 'geofence_alert' : 'geofence_info',
        'zoneId': zone.id,
        'zoneName': zone.name,
        'event': 'exit',
      },
    );
  }

  /// Create zone event record
  Future<void> _createZoneEvent({
    required GeoZone zone,
    required GeoZoneEventType eventType,
    required Position position,
  }) async {
    final docRef = _firestore.collection('geo_zone_events').doc();
    final event = GeoZoneEvent(
      id: docRef.id,
      zoneId: zone.id,
      userId: _currentUserId!,
      eventType: eventType,
      location: GeoPoint(position.latitude, position.longitude),
      timestamp: DateTime.now(),
      alertSent: true,
    );

    await docRef.set(event.toFirestore());
  }

  // CRUD operations for zones

  /// Create a new geo zone
  Future<GeoZone> createZone(GeoZone zone) async {
    final docRef = _firestore.collection('geo_zones').doc();
    final newZone = GeoZone(
      id: docRef.id,
      userId: zone.userId,
      name: zone.name,
      center: zone.center,
      radiusMeters: zone.radiusMeters,
      type: zone.type,
      alertOnEntry: zone.alertOnEntry,
      alertOnExit: zone.alertOnExit,
      isActive: zone.isActive,
      color: zone.color,
      createdBy: zone.createdBy,
    );

    await docRef.set(newZone.toFirestore());

    return newZone;
  }

  /// Update a zone
  Future<void> updateZone(GeoZone zone) async {
    await _firestore
        .collection('geo_zones')
        .doc(zone.id)
        .update(zone.toFirestore());
  }

  /// Delete a zone
  Future<void> deleteZone(String zoneId) async {
    await _firestore.collection('geo_zones').doc(zoneId).delete();
    _activeZones.removeWhere((z) => z.id == zoneId);
    _zoneStates.remove(zoneId);
  }

  /// Get zones for a user
  Stream<List<GeoZone>> getZones(String userId) {
    return _firestore
        .collection('geo_zones')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GeoZone.fromFirestore(doc)).toList());
  }

  /// Get zone events
  Stream<List<GeoZoneEvent>> getZoneEvents(
    String userId, {
    String? zoneId,
    DateTime? startTime,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('geo_zone_events')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (zoneId != null) {
      query = query.where('zoneId', isEqualTo: zoneId);
    }

    if (startTime != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => GeoZoneEvent.fromFirestore(doc)).toList());
  }

  /// Check if user is currently in any safe zone
  Future<bool> isInSafeZone() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return false;

    for (final zone in _activeZones) {
      if (zone.type == GeoZoneType.safe || zone.type == GeoZoneType.home) {
        if (_locationService.isPositionInZone(position, zone)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Stop geofencing
  void stop() {
    _geofenceCheckTimer?.cancel();
    _geofenceCheckTimer = null;
    _currentUserId = null;
    _activeZones = [];
    _zoneStates = {};
  }

  /// Dispose resources
  void dispose() {
    stop();
    _locationService.dispose();
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

import '../models/geo_zone.dart';

/// Service for location tracking and management
class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;

  /// Check and request location permissions
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Request background location permission (for continuous tracking)
  Future<bool> requestBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.whileInUse) {
      // Request always permission for background tracking
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.always;
    }

    return permission == LocationPermission.always;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return _lastPosition;
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  /// Start continuous location tracking for a user
  Future<void> startTracking({
    required String userId,
    Duration updateInterval = const Duration(minutes: 1),
  }) async {
    // Stop any existing tracking
    await stopTracking();

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return;

    // Configure location settings
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastPosition = position;
        _saveLocationUpdate(userId, position);
      },
      onError: (error) {
        debugPrint('Location tracking error: $error');
      },
    );
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Save location update to Firestore
  Future<void> _saveLocationUpdate(String userId, Position position) async {
    try {
      final locationUpdate = LocationUpdate(
        id: '',
        oderId: userId,
        location: GeoPoint(position.latitude, position.longitude),
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        timestamp: DateTime.now(),
      );

      // Save to location_updates collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('location_updates')
          .add(locationUpdate.toFirestore());

      // Update user's current location
      await _firestore.collection('users').doc(userId).update({
        'currentLocation': locationUpdate.location,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  /// Get user's current location (for caregivers to view)
  Stream<GeoPoint?> watchUserLocation(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['currentLocation'] as GeoPoint?);
  }

  /// Get location history for a user
  Stream<List<LocationUpdate>> getLocationHistory(
    String userId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('location_updates')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startTime != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }
    if (endTime != null) {
      query = query.where('timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => LocationUpdate.fromFirestore(doc)).toList());
  }

  /// Convert GeoPoint to address
  Future<String?> getAddressFromLocation(GeoPoint location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
    return null;
  }

  /// Convert address to GeoPoint
  Future<GeoPoint?> getLocationFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        return GeoPoint(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    return null;
  }

  /// Calculate distance between two points (in meters)
  double calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Check if position is within a zone
  bool isPositionInZone(Position position, GeoZone zone) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      zone.center.latitude,
      zone.center.longitude,
    );

    return distance <= zone.radiusMeters;
  }

  /// Open directions in Google Maps
  Future<String> getGoogleMapsDirectionsUrl({
    required GeoPoint destination,
    GeoPoint? origin,
    String? destinationName,
  }) async {
    final destLat = destination.latitude;
    final destLng = destination.longitude;

    String url = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';

    if (origin != null) {
      url += '&origin=${origin.latitude},${origin.longitude}';
    }

    if (destinationName != null) {
      url += '&destination_place_id=${Uri.encodeComponent(destinationName)}';
    }

    url += '&travelmode=driving';

    return url;
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}

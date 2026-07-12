import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/geo_zone.dart';

/// Service for location tracking and management
class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastPosition;
  DateTime? _lastWriteTime;
  static const Duration _writeDebounce = Duration(seconds: 30);

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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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

  /// Save location update to Firestore (debounced to reduce writes)
  Future<void> _saveLocationUpdate(String userId, Position position) async {
    // Debounce: write at most once per 30 seconds to control Firestore costs
    final now = DateTime.now();
    if (_lastWriteTime != null &&
        now.difference(_lastWriteTime!) < _writeDebounce) {
      return;
    }
    _lastWriteTime = now;

    try {
      final locationUpdate = LocationUpdate(
        id: '',
        userId: userId,
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
      // Platform geocoders (esp. Android emulator) can stall — cap it.
      final locations = await locationFromAddress(address)
          .timeout(const Duration(seconds: 10));

      if (locations.isNotEmpty) {
        return GeoPoint(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    return null;
  }

  /// Resolve a free-form location query. Accepts, in priority order:
  /// 1. what3words — `///word.word.word` or `word.word.word`
  ///    (requires W3W_API_KEY in .env; free tier at what3words.com)
  /// 2. Decimal coordinates — `32.487749, -110.912154` (as copied from
  ///    Google Maps, including its invisible Unicode formatting marks)
  /// 3. DMS coordinates — `32°29'15.9"N 110°54'43.8"W`
  /// 4. Street address (geocoded)
  Future<GeoPoint?> resolveLocationQuery(String query) async {
    // Strip invisible/bidi formatting chars (Google Maps copies include
    // them — they survive trim() and silently break parsing) and unify
    // curly quotes to straight ones for DMS.
    final q = query
        // zero-width & bidi marks (Google Maps copies include these)
        .replaceAll(RegExp('[\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u206F\\uFEFF]'), '')
        // curly/prime quotes -> straight, for DMS input
        .replaceAll(RegExp('[\\u2018\\u2019\\u2032]'), "'")
        .replaceAll(RegExp('[\\u201C\\u201D\\u2033]'), '"')
        .trim();
    if (q.isEmpty) return null;

    // what3words: three words separated by dots, optional /// prefix.
    final w3w = RegExp(
      r'^/{0,3}([^\d\s./]+)\.([^\d\s./]+)\.([^\d\s./]+)$',
      unicode: true,
    ).firstMatch(q);
    if (w3w != null) {
      return _resolveWhat3Words(
          '${w3w.group(1)}.${w3w.group(2)}.${w3w.group(3)}');
    }

    // Decimal "lat, lng" — tolerant of extra whitespace.
    final coords = RegExp(
      r'^(-?\d{1,3}(?:\.\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:\.\d+)?)$',
    ).firstMatch(q);
    if (coords != null) {
      final lat = double.tryParse(coords.group(1)!);
      final lng = double.tryParse(coords.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
        return GeoPoint(lat, lng);
      }
    }

    // DMS: 32°29'15.9"N 110°54'43.8"W
    final dms = RegExp(
      r'''^(\d{1,3})°\s*(\d{1,2})'\s*([\d.]+)"?\s*([NSns])[,\s]+(\d{1,3})°\s*(\d{1,2})'\s*([\d.]+)"?\s*([EWew])$''',
    ).firstMatch(q);
    if (dms != null) {
      double toDecimal(String d, String m, String s) =>
          double.parse(d) + double.parse(m) / 60 + double.parse(s) / 3600;
      var lat = toDecimal(dms.group(1)!, dms.group(2)!, dms.group(3)!);
      var lng = toDecimal(dms.group(5)!, dms.group(6)!, dms.group(7)!);
      if (dms.group(4)!.toUpperCase() == 'S') lat = -lat;
      if (dms.group(8)!.toUpperCase() == 'W') lng = -lng;
      if (lat.abs() <= 90 && lng.abs() <= 180) return GeoPoint(lat, lng);
    }

    return getLocationFromAddress(q);
  }

  /// Convert a what3words address to coordinates via the w3w API.
  Future<GeoPoint?> _resolveWhat3Words(String words) async {
    final apiKey = (dotenv.env['W3W_API_KEY'] ?? '').trim();
    if (apiKey.isEmpty) {
      debugPrint('what3words lookup skipped: W3W_API_KEY not set in .env');
      return null;
    }
    try {
      final response = await http
          .get(Uri.https('api.what3words.com', '/v3/convert-to-coordinates', {
            'words': words,
            'key': apiKey,
          }))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final c = data['coordinates'] as Map<String, dynamic>?;
        if (c != null) {
          return GeoPoint(
              (c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
        }
      } else {
        debugPrint(
            'what3words error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('what3words lookup failed: $e');
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
    String travelMode = 'driving',
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

    url += '&travelmode=$travelMode';

    return url;
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}

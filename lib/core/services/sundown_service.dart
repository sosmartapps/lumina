import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'sunset_calculator.dart';

enum TravelMode { walking, driving }

class SundownCheckResult {
  final int minutesToSunset;
  final int estimatedTravelMinutes;
  final TravelMode travelMode;
  final double distanceMeters;
  final int alertLevel; // 1=gentle, 2=urgent, 3=critical
  final DateTime sunsetTime;
  final GeoPoint currentLocation;

  const SundownCheckResult({
    required this.minutesToSunset,
    required this.estimatedTravelMinutes,
    required this.travelMode,
    required this.distanceMeters,
    required this.alertLevel,
    required this.sunsetTime,
    required this.currentLocation,
  });
}

/// Service that monitors user distance from home and alerts them
/// to return before sunset. Persists until user is heading home.
class SundownService {
  final LocationService _locationService;

  Timer? _checkTimer;
  Timer? _reCheckTimer;
  String? _currentUserId;
  AppUser? _currentUser;

  // Daily state
  DateTime? _lastAlertDate;
  bool _initialAlertSent = false; // first alert of the day (triggers SMS)
  bool _smsSentToday = false;

  // Persistent alert tracking
  double? _previousDistanceToHome;
  int _consecutiveDecreases = 0;

  // Configuration (from UserSettings)
  bool _sundownAlertEnabled = true;
  int _sundownBufferMinutes = 30;

  /// Emits when an alert should be shown. Set to null to clear.
  final ValueNotifier<SundownCheckResult?> alertNotifier = ValueNotifier(null);

  static const double _homeRadiusMeters = 200.0;
  static const double _headingHomeThreshold = 50.0; // must decrease by 50m
  static const int _consecutiveDecreaseTarget = 2; // 2 checks showing decrease
  static const Duration _mainCheckInterval = Duration(minutes: 5);
  static const Duration _reCheckInterval = Duration(minutes: 2);

  // Average speeds in m/s
  static const double _walkingSpeed = 1.25; // ~4.5 km/h
  static const double _drivingSpeed = 11.11; // ~40 km/h
  static const double _routingFactor = 1.4;
  static const double _speedThreshold = 3.0; // m/s boundary between walk/drive

  SundownService({required LocationService locationService})
      : _locationService = locationService;

  /// Initialize monitoring for a user.
  Future<void> initialize(String userId, AppUser user) async {
    _currentUserId = userId;
    _currentUser = user;
    _sundownAlertEnabled = user.settings.sundownAlertEnabled;
    _sundownBufferMinutes = user.settings.sundownBufferMinutes;
    _resetDailyState();
    _startMonitoring();
  }

  /// Update config from settings (called when caregiver changes settings).
  /// Buffer enforces a minimum of 30 minutes leeway before sunset.
  void updateSettings({bool? enabled, int? bufferMinutes}) {
    if (enabled != null) _sundownAlertEnabled = enabled;
    if (bufferMinutes != null) _sundownBufferMinutes = bufferMinutes.clamp(30, 60);
  }

  /// Update cached user (called when user data changes).
  void updateUser(AppUser user) {
    _currentUser = user;
    _sundownAlertEnabled = user.settings.sundownAlertEnabled;
    _sundownBufferMinutes = user.settings.sundownBufferMinutes;
  }

  void _startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_mainCheckInterval, (_) => performCheck());
    // Run an initial check immediately
    performCheck();
  }

  /// Main periodic check — exposed for testing.
  Future<void> performCheck() async {
    try {
      // Reset daily state if new day
      final today = DateTime.now();
      if (_lastAlertDate != null &&
          _lastAlertDate!.day != today.day) {
        _resetDailyState();
      }
      _lastAlertDate = today;

      if (!_sundownAlertEnabled) return;
      if (_currentUser == null || _currentUser!.homeLocation == null) return;

      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      final homeLocation = _currentUser!.homeLocation!;
      final distance = _locationService.calculateDistance(
        GeoPoint(position.latitude, position.longitude),
        homeLocation,
      );

      // Already at home — clear everything
      if (distance < _homeRadiusMeters) {
        _clearAlert();
        return;
      }

      // Calculate sunset
      final sunsetTime = SunsetCalculator.getSunsetTime(
        latitude: position.latitude,
        longitude: position.longitude,
        date: today,
      );
      if (sunsetTime == null) return;

      final now = DateTime.now();
      final timeToSunset = sunsetTime.difference(now);

      // Detect travel mode from GPS speed (distance-based when stationary)
      final travelMode = _detectTravelMode(position.speed, distance);
      final avgSpeed = _getAverageSpeed(travelMode);

      // Estimate travel time with routing factor
      final estimatedTravelSeconds = (distance * _routingFactor) / avgSpeed;
      final estimatedTravelMinutes = (estimatedTravelSeconds / 60).ceil();
      final bufferSeconds = _sundownBufferMinutes * 60;

      // Determine alert level
      int alertLevel = 0;
      if (timeToSunset.isNegative) {
        // Sun has already set
        alertLevel = 3;
      } else if (estimatedTravelSeconds >= timeToSunset.inSeconds) {
        // Won't make it home even without buffer
        alertLevel = 2;
      } else if (estimatedTravelSeconds + bufferSeconds >= timeToSunset.inSeconds) {
        // Need to leave now to have buffer time
        alertLevel = 1;
      }

      if (alertLevel == 0) return;

      final result = SundownCheckResult(
        minutesToSunset: timeToSunset.isNegative ? 0 : timeToSunset.inMinutes,
        estimatedTravelMinutes: estimatedTravelMinutes,
        travelMode: travelMode,
        distanceMeters: distance,
        alertLevel: alertLevel,
        sunsetTime: sunsetTime,
        currentLocation: GeoPoint(position.latitude, position.longitude),
      );

      // Fire the alert
      _fireAlert(result);

      // Start persistent re-check timer if not already running
      _startReCheckTimer();
    } catch (e) {
      debugPrint('Error during sundown check: $e');
    }
  }

  void _fireAlert(SundownCheckResult result) {
    alertNotifier.value = result;

    // Send caregiver notifications on first alert of the day
    if (!_initialAlertSent && _currentUserId != null && _currentUser != null) {
      _initialAlertSent = true;
      _notifyCaregivers(result);
    }
  }

  Future<void> _notifyCaregivers(SundownCheckResult result) async {
    final userName = _currentUser!.name;
    final distanceKm = (result.distanceMeters / 1000).toStringAsFixed(1);
    final modeStr = result.travelMode == TravelMode.driving ? 'driving' : 'walking';

    // Push notification
    await NotificationService.notifyCaregivers(
      userId: _currentUserId!,
      title: '\u{1F305} Sundown Alert: $userName',
      body: '$userName is ${distanceKm}km from home ($modeStr). '
          'Sunset in ${result.minutesToSunset} min, ~${result.estimatedTravelMinutes} min to get home.',
      data: {
        'type': 'sundown_alert',
        'latitude': result.currentLocation.latitude.toString(),
        'longitude': result.currentLocation.longitude.toString(),
        'distanceMeters': result.distanceMeters.toString(),
        'alertLevel': result.alertLevel.toString(),
      },
    );

    // SMS to primary caregiver (only once per day)
    if (!_smsSentToday) {
      _smsSentToday = true;
      final mapsLink = 'https://www.google.com/maps?q='
          '${result.currentLocation.latitude},${result.currentLocation.longitude}';
      await NotificationService.sendSmsToCaregiver(
        userId: _currentUserId!,
        userName: userName,
        message: 'Lumina Alert: $userName needs to head home. '
            'They are ${distanceKm}km away ($modeStr). '
            'Sunset in ${result.minutesToSunset} min, ~${result.estimatedTravelMinutes} min to get home. '
            'Location: $mapsLink',
      );
    }
  }

  /// Persistent re-check: runs every 2 minutes after initial alert.
  /// Re-fires alert if user isn't heading home.
  void _startReCheckTimer() {
    if (_reCheckTimer != null) return; // already running
    _reCheckTimer = Timer.periodic(_reCheckInterval, (_) => _reCheck());
  }

  Future<void> _reCheck() async {
    try {
      if (_currentUser == null || _currentUser!.homeLocation == null) return;

      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      final homeLocation = _currentUser!.homeLocation!;
      final distance = _locationService.calculateDistance(
        GeoPoint(position.latitude, position.longitude),
        homeLocation,
      );

      // Arrived home
      if (distance < _homeRadiusMeters) {
        _clearAlert();
        return;
      }

      // Check if heading home (distance decreasing)
      if (_previousDistanceToHome != null) {
        final decreased = _previousDistanceToHome! - distance;
        if (decreased >= _headingHomeThreshold) {
          _consecutiveDecreases++;
        } else {
          _consecutiveDecreases = 0;
        }
      }
      _previousDistanceToHome = distance;

      // If consistently heading home, suppress popup but keep monitoring
      if (_consecutiveDecreases >= _consecutiveDecreaseTarget) {
        alertNotifier.value = null; // hide popup
        return;
      }

      // Not heading home — re-fire alert
      final now = DateTime.now();
      final sunsetTime = SunsetCalculator.getSunsetTime(
        latitude: position.latitude,
        longitude: position.longitude,
        date: now,
      );
      if (sunsetTime == null) return;

      final timeToSunset = sunsetTime.difference(now);
      final travelMode = _detectTravelMode(position.speed, distance);
      final avgSpeed = _getAverageSpeed(travelMode);
      final estimatedTravelSeconds = (distance * _routingFactor) / avgSpeed;
      final estimatedTravelMinutes = (estimatedTravelSeconds / 60).ceil();

      int alertLevel;
      if (timeToSunset.isNegative) {
        alertLevel = 3;
      } else if (estimatedTravelSeconds >= timeToSunset.inSeconds) {
        alertLevel = 2;
      } else {
        alertLevel = 1;
      }

      final result = SundownCheckResult(
        minutesToSunset: timeToSunset.isNegative ? 0 : timeToSunset.inMinutes,
        estimatedTravelMinutes: estimatedTravelMinutes,
        travelMode: travelMode,
        distanceMeters: distance,
        alertLevel: alertLevel,
        sunsetTime: sunsetTime,
        currentLocation: GeoPoint(position.latitude, position.longitude),
      );

      alertNotifier.value = result;
    } catch (e) {
      debugPrint('Error during sundown re-check: $e');
    }
  }

  /// Beyond this distance from home, a stationary user is assumed to be
  /// driving — nobody walks this far home (2026-07-12: stationary user
  /// 55 km out was told "733 minutes to get home. Walking").
  static const double _walkableDistanceMeters = 2000;

  TravelMode _detectTravelMode(double speedMs, double distanceMeters) {
    // Stationary or noisy reading — GPS speed says nothing about how
    // they'll travel. Fall back to distance: short → walking, far →
    // driving.
    if (speedMs < 0.5) {
      return distanceMeters > _walkableDistanceMeters
          ? TravelMode.driving
          : TravelMode.walking;
    }
    return speedMs > _speedThreshold ? TravelMode.driving : TravelMode.walking;
  }

  double _getAverageSpeed(TravelMode mode) {
    return mode == TravelMode.driving ? _drivingSpeed : _walkingSpeed;
  }

  void _clearAlert() {
    alertNotifier.value = null;
    _reCheckTimer?.cancel();
    _reCheckTimer = null;
    _previousDistanceToHome = null;
    _consecutiveDecreases = 0;
  }

  void _resetDailyState() {
    _initialAlertSent = false;
    _smsSentToday = false;
    _clearAlert();
  }

  /// Call when user dismisses the popup (temporary — re-check will re-fire if needed).
  void onAlertDismissed() {
    alertNotifier.value = null;
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _reCheckTimer?.cancel();
    _reCheckTimer = null;
  }

  void dispose() {
    stop();
    alertNotifier.dispose();
  }
}

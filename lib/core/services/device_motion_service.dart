import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/app_user.dart';

/// Detected motion state of the device.
enum DeviceMotionState { unknown, stationary, moving }

/// Service that monitors the phone's accelerometer to detect pickup events.
///
/// When the device transitions from [DeviceMotionState.stationary] to
/// [DeviceMotionState.moving] it fires a pickup event, which other parts of
/// the app (e.g., morning medication reminders) can react to.
class DeviceMotionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Configuration ─────────────────────────────────────────────────────
  /// Magnitude delta (m/s²) above gravity to count as motion.
  static const double _pickupThreshold = 1.5;

  /// How many consecutive low-variance samples before marking stationary.
  static const int _stationarySampleCount = 50; // ~10s at 200ms interval

  /// Cooldown between pickup events to avoid duplicates.
  static const Duration _pickupCooldown = Duration(minutes: 2);

  // ── State ─────────────────────────────────────────────────────────────
  DeviceMotionState _state = DeviceMotionState.unknown;
  DeviceMotionState get state => _state;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  String? _userId;

  int _stationaryCount = 0;
  DateTime? _lastPickupTime;

  /// Stream controller that emits `true` each time a pickup is detected.
  final _pickupController = StreamController<DateTime>.broadcast();

  /// Fires each time the device is picked up after being stationary.
  Stream<DateTime> get onPickup => _pickupController.stream;

  // ── Public API ────────────────────────────────────────────────────────

  /// Start monitoring the accelerometer for the given user.
  void start(String userId) {
    if (_accelSub != null) return; // already running
    _userId = userId;
    _state = DeviceMotionState.unknown;
    _stationaryCount = 0;

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(_onAccelerometerEvent);

    debugPrint('DeviceMotionService: started for user $userId');
  }

  /// Stop monitoring.
  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _state = DeviceMotionState.unknown;
    debugPrint('DeviceMotionService: stopped');
  }

  /// Dispose resources.
  void dispose() {
    stop();
    _pickupController.close();
  }

  // ── Internals ─────────────────────────────────────────────────────────

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Total acceleration magnitude (gravity ≈ 9.8 m/s²).
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Delta from resting gravity.
    final delta = (magnitude - 9.8).abs();

    if (delta < _pickupThreshold) {
      // Low motion — count toward stationary.
      _stationaryCount++;
      if (_stationaryCount >= _stationarySampleCount &&
          _state != DeviceMotionState.stationary) {
        _state = DeviceMotionState.stationary;
        debugPrint('DeviceMotionService: device now stationary');
      }
    } else {
      // Significant motion detected.
      if (_state == DeviceMotionState.stationary) {
        _onPickupDetected();
      }
      _stationaryCount = 0;
      _state = DeviceMotionState.moving;
    }
  }

  void _onPickupDetected() {
    final now = DateTime.now();

    // Enforce cooldown.
    if (_lastPickupTime != null &&
        now.difference(_lastPickupTime!) < _pickupCooldown) {
      return;
    }
    _lastPickupTime = now;

    debugPrint('DeviceMotionService: pickup detected at $now');

    _pickupController.add(now);
    _recordPickupEvent(now);
  }

  Future<void> _recordPickupEvent(DateTime timestamp) async {
    if (_userId == null) return;
    try {
      final event = ActivityEvent(
        id: '',
        userId: _userId!,
        type: 'device_pickup',
        timestamp: timestamp,
      );

      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('activity_events')
          .add(event.toFirestore());

      // Also update a quick-access field on the user doc.
      await _firestore.collection('users').doc(_userId!).update({
        'lastActiveAt': Timestamp.fromDate(timestamp),
      });
    } catch (e) {
      debugPrint('DeviceMotionService: failed to record event: $e');
    }
  }

  /// Check if the current time falls within the morning window.
  static bool isInMorningWindow(UserSettings settings) {
    final hour = DateTime.now().hour;
    return hour >= settings.morningWindowStart &&
        hour < settings.morningWindowEnd;
  }
}

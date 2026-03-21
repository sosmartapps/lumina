import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quadtrack_device.dart';
import 'notification_service.dart';

/// Service for managing QuadTrack devices and location tracking
class QuadTrackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register a new QuadTrack device
  Future<QuadTrackDevice> registerDevice({
    required String deviceId,
    required String name,
    required String patientId,
    required String caregiverId,
  }) async {
    try {
      final docRef = _firestore.collection('quadtrack_devices').doc();
      final now = DateTime.now();

      final device = QuadTrackDevice(
        id: docRef.id,
        deviceId: deviceId,
        name: name,
        patientId: patientId,
        caregiverIds: [caregiverId],
        registeredBy: caregiverId,
        lastLocation: null,
        lastAccuracy: null,
        lastSeenAt: null,
        lastSource: LocationSource.gps,
        trackerBatteryLevel: 100,
        phoneBatteryLevel: null,
        chargingState: ChargingState.unknown,
        trackingMode: TrackingMode.normal,
        status: DeviceStatus.offline,
        firmwareVersion: null,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(device.toFirestore());
      return device;
    } catch (e) {
      debugPrint('Error registering QuadTrack device: $e');
      rethrow;
    }
  }

  /// Get stream of devices for a caregiver
  Stream<List<QuadTrackDevice>> getDevicesForCaregiver(String caregiverId) {
    return _firestore
        .collection('quadtrack_devices')
        .where('caregiverIds', arrayContains: caregiverId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QuadTrackDevice.fromFirestore(doc))
          .toList();
    }).handleError((e) {
      debugPrint('Error getting devices for caregiver: $e');
      return <QuadTrackDevice>[];
    });
  }

  /// Get stream of devices for a patient
  Stream<List<QuadTrackDevice>> getDevicesForPatient(String patientId) {
    return _firestore
        .collection('quadtrack_devices')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QuadTrackDevice.fromFirestore(doc))
          .toList();
    }).handleError((e) {
      debugPrint('Error getting devices for patient: $e');
      return <QuadTrackDevice>[];
    });
  }

  /// Get stream of a single device
  Stream<QuadTrackDevice?> getDevice(String deviceId) {
    return _firestore
        .collection('quadtrack_devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return QuadTrackDevice.fromFirestore(doc);
      }
      return null;
    }).handleError((e) {
      debugPrint('Error getting device: $e');
      return null;
    });
  }

  /// Update tracking mode for a device
  Future<void> updateTrackingMode(
    String deviceId,
    TrackingMode mode,
  ) async {
    try {
      final deviceRef = _firestore.collection('quadtrack_devices').doc(deviceId);

      // Update device document
      await deviceRef.update({
        'trackingMode': mode.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If switching to emergency mode, write command for hardware
      if (mode == TrackingMode.emergency) {
        final commandRef =
            _firestore.collection('quadtrack_commands').doc(deviceId);

        await commandRef.set(
          {
            'deviceId': deviceId,
            'command': 'set_tracking_mode',
            'mode': 'emergency',
            'intervalMinutes': mode.intervalMinutes,
            'createdAt': FieldValue.serverTimestamp(),
            'acknowledged': false,
          },
          SetOptions(merge: true),
        );

        // Also update device status to indicate emergency mode active
        await deviceRef.update({
          'status': DeviceStatus.online.value,
        });

        // Notify caregivers of emergency mode activation
        final deviceDoc = await deviceRef.get();
        if (deviceDoc.exists) {
          final data = deviceDoc.data() as Map<String, dynamic>;
          final patientId = data['patientId'] as String?;
          if (patientId != null) {
            await NotificationService.notifyCaregivers(
              userId: patientId,
              title: '🚨 Emergency Tracking Activated',
              body:
                  'Tracking mode set to Emergency for ${data['name'] ?? 'device'}',
              data: {
                'type': 'quadtrack_emergency',
                'deviceId': deviceId,
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating tracking mode: $e');
      rethrow;
    }
  }

  /// Add a caregiver to a device
  Future<void> addCaregiver(String deviceId, String caregiverId) async {
    try {
      await _firestore.collection('quadtrack_devices').doc(deviceId).update({
        'caregiverIds': FieldValue.arrayUnion([caregiverId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding caregiver: $e');
      rethrow;
    }
  }

  /// Remove a caregiver from a device
  Future<void> removeCaregiver(String deviceId, String caregiverId) async {
    try {
      await _firestore.collection('quadtrack_devices').doc(deviceId).update({
        'caregiverIds': FieldValue.arrayRemove([caregiverId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error removing caregiver: $e');
      rethrow;
    }
  }

  /// Delete a device
  Future<void> removeDevice(String deviceId) async {
    try {
      // Delete device
      await _firestore.collection('quadtrack_devices').doc(deviceId).delete();

      // Delete any associated commands
      final commandsSnapshot = await _firestore
          .collection('quadtrack_commands')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      for (final doc in commandsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
      rethrow;
    }
  }

  /// Get location history for a device
  Future<List<QuadTrackPing>> getLocationHistory(
    String deviceId, {
    DateTime? start,
    DateTime? end,
    int limit = 200,
  }) async {
    try {
      Query query = _firestore
          .collection('quadtrack_pings')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (start != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }

      if (end != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => QuadTrackPing.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting location history: $e');
      return [];
    }
  }

  /// Stream latest pings for a device (real-time updates)
  Stream<List<QuadTrackPing>> streamLatestPings(
    String deviceId, {
    int limit = 1,
  }) {
    return _firestore
        .collection('quadtrack_pings')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QuadTrackPing.fromFirestore(doc))
          .toList();
    }).handleError((e) {
      debugPrint('Error streaming latest pings: $e');
      return <QuadTrackPing>[];
    });
  }

  /// Report phone battery level from companion app
  /// If battery is 0 (dead), auto-escalates tracking to emergency
  Future<void> reportPhoneBattery(String deviceId, int level) async {
    try {
      final deviceRef = _firestore.collection('quadtrack_devices').doc(deviceId);

      // Update phone battery level
      await deviceRef.update({
        'phoneBatteryLevel': level,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If battery is dead, escalate to emergency tracking
      if (level == 0) {
        // Update status to phoneDead
        await deviceRef.update({
          'status': DeviceStatus.phoneDead.value,
          'trackingMode': TrackingMode.emergency.value,
        });

        // Write command for emergency tracking
        await _firestore
            .collection('quadtrack_commands')
            .doc(deviceId)
            .set(
              {
                'deviceId': deviceId,
                'command': 'set_tracking_mode',
                'mode': 'emergency',
                'intervalMinutes': TrackingMode.emergency.intervalMinutes,
                'reason': 'phone_battery_dead',
                'createdAt': FieldValue.serverTimestamp(),
                'acknowledged': false,
              },
              SetOptions(merge: true),
            );

        // Get device info for notification
        final deviceDoc = await deviceRef.get();
        if (deviceDoc.exists) {
          final data = deviceDoc.data() as Map<String, dynamic>;
          final patientId = data['patientId'] as String?;
          final deviceName = data['name'] as String? ?? 'QuadTrack Device';

          if (patientId != null) {
            await NotificationService.notifyCaregivers(
              userId: patientId,
              title: '🔴 Phone Battery Dead',
              body:
                  'Phone for $deviceName has no battery. Emergency tracking activated.',
              data: {
                'type': 'quadtrack_phone_dead',
                'deviceId': deviceId,
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error reporting phone battery: $e');
      rethrow;
    }
  }

  /// Check if a device serial number is already registered
  Future<bool> isDeviceRegistered(String deviceId) async {
    try {
      final snapshot = await _firestore
          .collection('quadtrack_devices')
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking device registration: $e');
      return false;
    }
  }

  /// Calculate smart tracking interval based on battery level
  int _calculateSmartInterval(int batteryLevel) {
    if (batteryLevel > 80) return 1; // Aggressive: 1 minute
    if (batteryLevel >= 50) return 3; // Normal emergency: 3 minutes
    if (batteryLevel >= 20) return 5; // Conservative: 5 minutes
    if (batteryLevel >= 10) return 10; // Very low: 10 minutes
    return 15; // Critical: 15 minutes (conservation mode)
  }

  /// Activate battery-aware emergency tracking
  /// Calculates interval based on current tracker battery level
  Future<void> activateEmergencyTracking({
    required String deviceId,
    required String caregiverId,
    required String reason,
  }) async {
    try {
      final deviceRef = _firestore.collection('quadtrack_devices').doc(deviceId);
      final deviceDoc = await deviceRef.get();

      if (!deviceDoc.exists) {
        throw Exception('Device not found');
      }

      final data = deviceDoc.data() as Map<String, dynamic>;
      final trackerBattery = data['trackerBatteryLevel'] as int? ?? 100;
      final smartInterval = _calculateSmartInterval(trackerBattery);
      final now = DateTime.now();

      // Create emergency record
      final emergencyRef = _firestore
          .collection('quadtrack_emergencies')
          .doc(); // Auto-generate ID

      await emergencyRef.set({
        'deviceId': deviceId,
        'activatedBy': caregiverId,
        'reason': reason,
        'startedAt': FieldValue.serverTimestamp(),
        'intervalMinutes': smartInterval,
        'trackerBatteryAtStart': trackerBattery,
        'endedAt': null,
      });

      // Update device with emergency info
      await deviceRef.update({
        'trackingMode': TrackingMode.emergency.value,
        'status': DeviceStatus.online.value,
        'emergencyIntervalMinutes': smartInterval,
        'emergencyActivatedAt': FieldValue.serverTimestamp(),
        'emergencyActivatedBy': caregiverId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write command for hardware
      await _firestore.collection('quadtrack_commands').doc(deviceId).set(
        {
          'deviceId': deviceId,
          'command': 'set_tracking_mode',
          'mode': 'emergency',
          'intervalMinutes': smartInterval,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
          'acknowledged': false,
        },
        SetOptions(merge: true),
      );

      // Notify all caregivers
      final patientId = data['patientId'] as String?;
      final deviceName = data['name'] as String? ?? 'device';
      if (patientId != null) {
        await NotificationService.notifyCaregivers(
          userId: patientId,
          title: '🚨 Emergency Tracking Activated',
          body:
              'Battery-aware tracking for $deviceName set to every $smartInterval minutes. Reason: $reason',
          data: {
            'type': 'quadtrack_emergency',
            'deviceId': deviceId,
            'emergencyId': emergencyRef.id,
          },
        );
      }
    } catch (e) {
      debugPrint('Error activating emergency tracking: $e');
      rethrow;
    }
  }

  /// Deactivate emergency tracking and return to normal mode
  Future<void> deactivateEmergency(String deviceId) async {
    try {
      final deviceRef = _firestore.collection('quadtrack_devices').doc(deviceId);

      // Find active emergency record
      final emergencySnapshot = await _firestore
          .collection('quadtrack_emergencies')
          .where('deviceId', isEqualTo: deviceId)
          .where('endedAt', isNull: true)
          .limit(1)
          .get();

      // Close emergency record
      if (emergencySnapshot.docs.isNotEmpty) {
        await emergencySnapshot.docs.first.reference.update({
          'endedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update device to normal mode
      await deviceRef.update({
        'trackingMode': TrackingMode.normal.value,
        'emergencyIntervalMinutes': null,
        'emergencyActivatedAt': null,
        'emergencyActivatedBy': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write command to resume normal tracking
      await _firestore.collection('quadtrack_commands').doc(deviceId).set(
        {
          'deviceId': deviceId,
          'command': 'set_tracking_mode',
          'mode': 'normal',
          'intervalMinutes': TrackingMode.normal.intervalMinutes,
          'createdAt': FieldValue.serverTimestamp(),
          'acknowledged': false,
        },
        SetOptions(merge: true),
      );

      // Notify caregivers
      final deviceDoc = await deviceRef.get();
      if (deviceDoc.exists) {
        final data = deviceDoc.data() as Map<String, dynamic>;
        final patientId = data['patientId'] as String?;
        final deviceName = data['name'] as String? ?? 'device';
        if (patientId != null) {
          await NotificationService.notifyCaregivers(
            userId: patientId,
            title: '✓ Emergency Tracking Ended',
            body: 'Returned to normal tracking for $deviceName',
            data: {
              'type': 'quadtrack_emergency_ended',
              'deviceId': deviceId,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error deactivating emergency: $e');
      rethrow;
    }
  }

  /// Get active emergency for a device
  Stream<Map<String, dynamic>?> getActiveEmergency(String deviceId) {
    return _firestore
        .collection('quadtrack_emergencies')
        .where('deviceId', isEqualTo: deviceId)
        .where('endedAt', isNull: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    }).handleError((e) {
      debugPrint('Error getting active emergency: $e');
      return null;
    });
  }
}

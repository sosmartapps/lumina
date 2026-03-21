import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/quadtrack_service.dart';
import '../models/quadtrack_device.dart';

/// Provider for QuadTrackService instance
final quadTrackServiceProvider = Provider<QuadTrackService>((ref) {
  return QuadTrackService();
});

/// Provider for currently selected device ID
final selectedDeviceProvider = StateProvider<String?>((ref) {
  return null;
});

/// Stream provider for caregiver's devices
final caregiverDevicesProvider =
    StreamProvider.family<List<QuadTrackDevice>, String>((ref, caregiverId) {
  final service = ref.watch(quadTrackServiceProvider);
  return service.getDevicesForCaregiver(caregiverId);
});

/// Stream provider for patient's devices
final patientDevicesProvider =
    StreamProvider.family<List<QuadTrackDevice>, String>((ref, patientId) {
  final service = ref.watch(quadTrackServiceProvider);
  return service.getDevicesForPatient(patientId);
});

/// Stream provider for single device details
final deviceDetailProvider =
    StreamProvider.family<QuadTrackDevice?, String>((ref, deviceId) {
  final service = ref.watch(quadTrackServiceProvider);
  return service.getDevice(deviceId);
});

/// Stream provider for recent pings (last 50)
final devicePingsProvider =
    StreamProvider.family<List<QuadTrackPing>, String>((ref, deviceId) {
  final service = ref.watch(quadTrackServiceProvider);
  return service.streamLatestPings(deviceId, limit: 50);
});

/// Family provider for location history with date range
/// Usage: ref.watch(deviceHistoryProvider((deviceId: 'id', days: 7)))
final deviceHistoryProvider = FutureProvider.family<List<QuadTrackPing>,
    ({String deviceId, int days})>((ref, args) async {
  final service = ref.watch(quadTrackServiceProvider);
  final now = DateTime.now();
  final start = now.subtract(Duration(days: args.days));

  return service.getLocationHistory(
    args.deviceId,
    start: start,
    end: now,
    limit: 200,
  );
});

/// Check if device is registered
final deviceRegistrationCheckProvider =
    FutureProvider.family<bool, String>((ref, deviceId) async {
  final service = ref.watch(quadTrackServiceProvider);
  return service.isDeviceRegistered(deviceId);
});

/// Stream provider for active emergency on a device
final activeEmergencyProvider = StreamProvider.family<Map<String, dynamic>?, String>(
    (ref, deviceId) {
  final service = ref.watch(quadTrackServiceProvider);
  return service.getActiveEmergency(deviceId);
});

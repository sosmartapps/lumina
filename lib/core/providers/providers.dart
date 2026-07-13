import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/bouncie_connection.dart';
import '../models/environment_connection.dart';

import 'app_state_provider.dart';
import 'user_provider.dart';
import 'caregiver_provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';
import '../services/reminder_service.dart';
import '../services/geofence_service.dart';
import '../services/sundown_service.dart';
import '../services/invite_service.dart';
import '../services/subscription_service.dart';
import '../services/prescription_scan_service.dart';
import '../services/pill_photo_service.dart';
import '../services/medical_records_service.dart';
import '../services/device_motion_service.dart';
import '../services/expense_service.dart';
import '../services/receipt_scan_service.dart';
import '../services/pet_feeding_service.dart';
import 'subscription_provider.dart';
import '../../features/bouncie/bouncie_service.dart';
import '../../features/environment/environment_service.dart';
import '../services/sensorpush_ble_bridge.dart';

// ChangeNotifier providers — use ref.read() to get instance,
// ListenableBuilder to reactively rebuild on notifyListeners().
final appStateNotifierProvider = Provider((ref) => AppStateProvider());
final userNotifierProvider = Provider((ref) => UserProvider());
// ChangeNotifierProvider (not plain Provider) so ref.watch() rebuilds on
// notifyListeners() — plain Provider silently never rebuilds watchers
// (caused stale AppBar title + stale VehicleStatusCard on patient switch,
// 2026-07-12).
final caregiverNotifierProvider =
    ChangeNotifierProvider((ref) => CaregiverProvider());

// Service providers
final authServiceProvider = Provider((ref) => AuthService());
final locationServiceProvider = Provider((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});
final ttsServiceProvider = Provider((ref) {
  final service = TTSService();
  ref.onDispose(() => service.dispose());
  return service;
});
final reminderServiceProvider = Provider((ref) => ReminderService());
final geofenceServiceProvider = Provider((ref) {
  final service = GeofenceServiceWrapper();
  ref.onDispose(() => service.dispose());
  return service;
});
final sundownServiceProvider = Provider((ref) {
  final locationService = ref.read(locationServiceProvider);
  final service = SundownService(locationService: locationService);
  ref.onDispose(() => service.dispose());
  return service;
});

// ── Bouncie vehicle tracking ─────────────────────────────────────────────
// App-level developer credentials (identify the Lumina app to Bouncie —
// NOT user-specific). Per-family authorization + vehicle live in
// Firestore `bouncie_connections/{patientId}` (BouncieConnection).

/// (clientId, clientSecret, redirectUri) for the Lumina Bouncie app.
/// Empty strings when unconfigured — callers must handle gracefully.
final bouncieAppConfigProvider =
    Provider<({String clientId, String clientSecret, String redirectUri})>(
        (ref) {
  return (
    clientId: dotenv.env['BOUNCIE_CLIENT_ID'] ?? '',
    clientSecret: dotenv.env['BOUNCIE_CLIENT_SECRET'] ?? '',
    redirectUri: dotenv.env['BOUNCIE_REDIRECT_URI'] ?? '',
  );
});

/// Live per-patient Bouncie connection (null = no vehicle linked).
final bouncieConnectionProvider =
    StreamProvider.family<BouncieConnection?, String>((ref, patientId) {
  return FirebaseFirestore.instance
      .collection('bouncie_connections')
      .doc(patientId)
      .snapshots()
      .map((doc) => doc.exists ? BouncieConnection.fromFirestore(doc) : null);
});

/// Builds a [BouncieService] for a specific family connection.
/// Callers pass `ref.read(bouncieAppConfigProvider)` (works from both
/// widget and provider refs).
BouncieService bouncieServiceForConnection(
  ({String clientId, String clientSecret, String redirectUri}) config,
  BouncieConnection connection,
) {
  return BouncieService(
    clientId: config.clientId,
    clientSecret: config.clientSecret,
    authCode: connection.authCode,
    redirectUri: config.redirectUri,
  );
}

// ── Home environment (temperature / humidity) ───────────────────────────
// App-level Google Device Access credentials for the Nest SDM link flow
// (identify the Lumina app to Google — NOT user-specific). SensorPush
// needs no app credentials. Per-family tokens live in Firestore
// `environment_connections/{patientId}` (EnvironmentConnection).

/// Google Device Access config. Empty strings when unconfigured —
/// callers must handle gracefully.
final nestAppConfigProvider = Provider<
    ({
      String clientId,
      String clientSecret,
      String projectId,
      String redirectUri
    })>((ref) {
  return (
    clientId: dotenv.env['NEST_CLIENT_ID'] ?? '',
    clientSecret: dotenv.env['NEST_CLIENT_SECRET'] ?? '',
    projectId: dotenv.env['NEST_PROJECT_ID'] ?? '',
    redirectUri: dotenv.env['NEST_REDIRECT_URI'] ?? '',
  );
});

/// Live per-patient environment connection (null = nothing linked).
final environmentConnectionProvider =
    StreamProvider.family<EnvironmentConnection?, String>((ref, patientId) {
  return FirebaseFirestore.instance
      .collection('environment_connections')
      .doc(patientId)
      .snapshots()
      .map((doc) =>
          doc.exists ? EnvironmentConnection.fromFirestore(doc) : null);
});

final environmentServiceProvider = Provider((ref) => EnvironmentService());

/// Patient-phone BLE bridge to a SensorPush HT.w (no WiFi gateway needed).
/// Started at splash in user mode; runs only while `ble.enabled` is set
/// on the patient's environment connection by a caregiver.
final sensorPushBleBridgeProvider = Provider((ref) {
  final bridge = SensorPushBleBridge();
  ref.onDispose(() => bridge.dispose());
  return bridge;
});

// Invite service
final inviteServiceProvider = Provider((ref) => InviteService());

// Subscription / billing
final subscriptionServiceProvider = Provider((ref) => SubscriptionService());
final subscriptionNotifierProvider = Provider((ref) {
  final service = ref.read(subscriptionServiceProvider);
  return SubscriptionProvider(service);
});

// Prescription scanning & pill photos
final prescriptionScanServiceProvider = Provider((ref) {
  final service = PrescriptionScanService();
  ref.onDispose(() => service.dispose());
  return service;
});
final pillPhotoServiceProvider = Provider((ref) => PillPhotoService());

// Medical records export
final medicalRecordsServiceProvider =
    Provider((ref) => MedicalRecordsService());

// Pet feeding reminders
final petFeedingServiceProvider = Provider((ref) => PetFeedingService());

// Expense tracking & reimbursement
final expenseServiceProvider = Provider((ref) => ExpenseService());
final receiptScanServiceProvider = Provider((ref) {
  final service = ReceiptScanService();
  ref.onDispose(() => service.dispose());
  return service;
});

// QuadTrack device tracking — canonical provider is in quadtrack_provider.dart
// (removed duplicate quadTrackServiceProvider to avoid compile error)

// Device motion / pickup detection
final deviceMotionServiceProvider = Provider((ref) {
  final service = DeviceMotionService();
  ref.onDispose(() => service.dispose());
  return service;
});

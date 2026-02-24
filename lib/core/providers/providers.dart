import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
import 'subscription_provider.dart';
import '../../features/bouncie/bouncie_service.dart';

// ChangeNotifier providers — use ref.read() to get instance,
// ListenableBuilder to reactively rebuild on notifyListeners().
final appStateNotifierProvider = Provider((ref) => AppStateProvider());
final userNotifierProvider = Provider((ref) => UserProvider());
final caregiverNotifierProvider = Provider((ref) => CaregiverProvider());

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

// Bouncie vehicle tracking
final bouncieServiceProvider = Provider((ref) {
  return BouncieService(
    clientId: dotenv.env['BOUNCIE_CLIENT_ID']!,
    clientSecret: dotenv.env['BOUNCIE_CLIENT_SECRET']!,
    authCode: dotenv.env['BOUNCIE_AUTH_CODE']!,
    redirectUri: dotenv.env['BOUNCIE_REDIRECT_URI']!,
  );
});

final bouncieVehicleImeiProvider = Provider((ref) {
  return dotenv.env['BOUNCIE_VEHICLE_IMEI']!;
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

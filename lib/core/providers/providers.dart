import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state_provider.dart';
import 'user_provider.dart';
import 'caregiver_provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';
import '../services/reminder_service.dart';
import '../services/geofence_service.dart';
import '../services/sundown_service.dart';

// ChangeNotifier providers — use ref.read() to get instance,
// ListenableBuilder to reactively rebuild on notifyListeners().
final appStateNotifierProvider = Provider((ref) => AppStateProvider());
final userNotifierProvider = Provider((ref) => UserProvider());
final caregiverNotifierProvider = Provider((ref) => CaregiverProvider());

// Service providers
final authServiceProvider = Provider((ref) => AuthService());
final locationServiceProvider = Provider((ref) => LocationService());
final ttsServiceProvider = Provider((ref) => TTSService());
final reminderServiceProvider = Provider((ref) => ReminderService());
final geofenceServiceProvider = Provider((ref) => GeofenceServiceWrapper());
final sundownServiceProvider = Provider((ref) {
  final locationService = ref.read(locationServiceProvider);
  return SundownService(locationService: locationService);
});


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/tts_service.dart';
import 'core/services/reminder_service.dart';
import 'core/services/geofence_service.dart';
import 'core/services/screenshot_feedback_service.dart';
import 'core/providers/app_state_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/caregiver_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/feedback/bug_report_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Lock to portrait mode for easier use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notifications
  await NotificationService.initialize();

  runApp(const CaregiverApp());
}

class CaregiverApp extends StatelessWidget {
  const CaregiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CaregiverProvider()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => TTSService()),
        Provider(create: (_) => ReminderService()),
        Provider(create: (_) => GeofenceServiceWrapper()),
      ],
      child: ScreenshotFeedbackWrapper(
        // Only enable screenshot feedback in debug/profile mode
        enabled: !kReleaseMode,
        autoPrompt: true,
        onFeedbackRequested: (context, screenshot) async {
          // Show the feedback prompt when a screenshot is taken
          await showScreenshotFeedbackPrompt(
            context: context,
            screenshot: screenshot,
            onSendFeedback: () async {
              Uint8List? bytes;
              if (screenshot != null) {
                bytes = await screenshot.readAsBytes();
              }

              if (context.mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BugReportScreen(
                      initialScreenshot: bytes,
                    ),
                  ),
                );
              }
            },
          );
        },
        child: MaterialApp(
          title: 'Lumina',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light, // Default to light for better visibility
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

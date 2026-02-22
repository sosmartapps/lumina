
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart';
import 'core/services/screenshot_feedback_service.dart';
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

  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Lock to portrait mode for easier use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notifications
  await NotificationService.initialize();

  // Initialize background monitoring service
  await BackgroundMonitoringService.initialize();

  // Ensure the device always has a Firebase Auth context.
  // Patients don't log in, so we use anonymous auth to satisfy
  // Firestore security rules that require isAuthenticated().
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  // Log app open event
  unawaited(FirebaseAnalytics.instance.logAppOpen());

  runApp(const ProviderScope(child: CaregiverApp()));
}

class CaregiverApp extends StatelessWidget {
  const CaregiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenshotFeedbackWrapper(
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
    );
  }
}

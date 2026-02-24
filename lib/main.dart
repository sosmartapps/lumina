
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bug_reporter/bug_reporter.dart';
import 'package:screenshot/screenshot.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart';
import 'core/services/deep_link_service.dart';
import 'features/splash/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Bug Reporter (replaces manual Crashlytics + screenshot feedback)
  await BugReporterInitializer.init(
    reportEndpoint: 'https://us-central1-ssa-bug-dashboard.cloudfunctions.net/api/reports',
    shakeToReport: true,
  );

  // Lock to portrait mode for easier use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notifications
  await NotificationService.initialize();

  // Initialize background monitoring service
  try {
    await BackgroundMonitoringService.initialize();
  } catch (e) {
    debugPrint('Background service init failed: $e');
  }

  // Ensure the device always has a Firebase Auth context.
  // Patients don't log in, so we use anonymous auth to satisfy
  // Firestore security rules that require isAuthenticated().
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Anonymous auth failed (enable in Firebase console): $e');
  }

  // Initialize deep link handling
  await DeepLinkService().initialize();

  // Log app open event
  unawaited(FirebaseAnalytics.instance.logAppOpen());

  runApp(
    ProviderScope(
      child: Screenshot(
        controller: ScreenshotService.controller,
        child: CaregiverApp(
          navigatorKey: BugReporterInitializer.navigatorKey,
        ),
      ),
    ),
  );
}

class CaregiverApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const CaregiverApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Default to light for better visibility
      home: const SplashScreen(),
    );
  }
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bug_reporter/bug_reporter.dart';
import 'package:screenshot/screenshot.dart' as screenshot_lib;

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart';
import 'core/services/deep_link_service.dart';
import 'features/splash/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Completes when post-boot initialization (auth, notifications, background
/// service, deep links) has finished. SplashScreen awaits this before it
/// starts loading data, so Firestore reads never race anonymous auth.
final Completer<void> _bootCompleter = Completer<void>();
Future<void> get bootReady => _bootCompleter.future;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only the essentials before the first frame: env + Firebase (both local
  // and fast) and crash handler wiring. EVERYTHING else runs after runApp()
  // so a hung plugin or network call can never black-screen the app.
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    ProviderScope(
      child: screenshot_lib.Screenshot(
        controller: ScreenshotService.controller,
        child: CaregiverApp(
          navigatorKey: BugReporterInitializer.navigatorKey,
        ),
      ),
    ),
  );

  unawaited(_postBootInit());
}

/// Runs the remaining init steps after the first frame is scheduled.
/// Every step is individually try/caught and hard-timeboxed so one bad
/// plugin degrades gracefully instead of hanging boot (root cause of the
/// 2026-07-03 black-screen: an await in main() before runApp never
/// completed, so the first frame never rendered).
Future<void> _postBootInit() async {
  Future<void> step(
    String name,
    Future<void> Function() task, {
    int timeoutSeconds = 15,
  }) async {
    debugPrint('BOOT: $name…');
    try {
      await task().timeout(Duration(seconds: timeoutSeconds));
      debugPrint('BOOT: $name OK');
    } catch (e) {
      debugPrint('BOOT: $name FAILED: $e');
    }
  }

  await step('crashlytics collection', () =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true));

  await step('bug reporter', () => BugReporterInitializer.init(
        reportEndpoint:
            'https://us-central1-ssa-bug-dashboard.cloudfunctions.net/api/reports',
        shakeToReport: true,
      ));

  await step('orientation lock', () => SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]));

  await step('notifications', () => NotificationService.initialize());

  await step('background service', () => BackgroundMonitoringService.initialize());

  // Anonymous auth so Firestore rules (isAuthenticated) pass for patients.
  await step('anonymous auth', () async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  });

  await step('deep links', () => DeepLinkService().initialize());

  // Google Sign-In (v7 requires explicit initialize before authenticate).
  // iOS reads CLIENT_ID from GoogleService-Info.plist — requires the Google
  // provider to be enabled in Firebase console and a re-downloaded plist.
  await step('google sign-in', () => GoogleSignIn.instance.initialize());

  unawaited(FirebaseAnalytics.instance.logAppOpen());
  debugPrint('BOOT: complete');
  _bootCompleter.complete();
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
      builder: (context, child) {
        return BugReportFab(child: child ?? const SizedBox.shrink());
      },
      home: const SplashScreen(),
    );
  }
}

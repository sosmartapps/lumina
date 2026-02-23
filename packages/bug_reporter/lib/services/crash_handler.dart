import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashHandler {
  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    // Flutter framework errors (widget build failures, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      _persistCrash(details.toString());
    };

    // Dart async / platform channel errors
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      _persistCrash('$error\n\n$stack');
      return true;
    };
  }

  static Future<void> _persistCrash(String details) async {
    final prefs = await SharedPreferences.getInstance();
    final crashes = prefs.getStringList('pending_crashes') ?? [];
    crashes.add(jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'details': details,
    }));
    // Keep only last 5 crashes to avoid bloat.
    if (crashes.length > 5) crashes.removeAt(0);
    await prefs.setStringList('pending_crashes', crashes);
    await prefs.setBool('show_crash_report', true);
  }

  static Future<void> clearPendingCrashes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_crashes');
    await prefs.remove('show_crash_report');
  }

  /// Manually record a non-fatal error (e.g. caught exceptions you still want tracked).
  static Future<void> recordNonFatal(Object error, StackTrace stack) async {
    await FirebaseCrashlytics.instance
        .recordError(error, stack, fatal: false);
  }
}

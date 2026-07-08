import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized logging for all SSA apps.
///
/// In debug mode, prints to console. In release mode, logs to Crashlytics.
/// This replaces scattered debugPrint calls with a consistent logger that
/// also captures breadcrumbs for crash reports.
class SSALogger {
  SSALogger._();

  /// Log an informational message.
  static void info(String message, {String? tag}) {
    final formatted = tag != null ? '[$tag] $message' : message;
    debugPrint(formatted);
    if (kReleaseMode && !kIsWeb) {
      FirebaseCrashlytics.instance.log(formatted);
    }
  }

  /// Log a warning.
  static void warning(String message, {String? tag}) {
    final formatted = tag != null ? '[$tag] WARNING: $message' : 'WARNING: $message';
    debugPrint(formatted);
    if (kReleaseMode && !kIsWeb) {
      FirebaseCrashlytics.instance.log(formatted);
    }
  }

  /// Log an error with optional stack trace.
  ///
  /// In release mode, records the error in Crashlytics as a non-fatal.
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formatted = tag != null ? '[$tag] ERROR: $message' : 'ERROR: $message';
    debugPrint(formatted);
    if (error != null) debugPrint('  Cause: $error');

    if (kReleaseMode && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(
        error ?? Exception(message),
        stackTrace ?? StackTrace.current,
        reason: formatted,
      );
    }
  }

  /// Set a persistent key-value pair for Crashlytics reports.
  static void setCustomKey(String key, Object value) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    }
  }
}

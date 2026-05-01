import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/crash_handler.dart';
import 'services/report_uploader.dart';
import 'ui/bug_report_sheet.dart';

/// Call [BugReporterInitializer.init] inside your app's [main()] before runApp.
/// Pass [navigatorKey] so the sheet can be shown from anywhere, including
/// post-crash auto-launch on next startup.
class BugReporterInitializer {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> init({
    /// Endpoint to POST bug reports to. Can be a Firebase Function URL,
    /// a simple webhook, or a local dev server.
    required String reportEndpoint,

    /// Optional: Slack/email webhook for immediate dev notifications.
    String? alertWebhook,

    /// Enable shake-to-report gesture.
    bool shakeToReport = true,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Wire up crash handlers.
    await CrashHandler.initialize(navigatorKey: navigatorKey);

    // 2. Store config for use by uploader.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bug_report_endpoint', reportEndpoint);
    if (alertWebhook != null) {
      await prefs.setString('bug_alert_webhook', alertWebhook);
    }

    // 3. Retry any queued reports from last session (offline failures).
    await ReportUploader.retryQueued();

    // 4. Auto-submit any pending crashes silently to the bug dashboard.
    final showCrashReport = prefs.getBool('show_crash_report') ?? false;
    if (showCrashReport) {
      await prefs.setBool('show_crash_report', false);
      final crashes = prefs.getStringList('pending_crashes') ?? [];
      if (crashes.isNotEmpty) {
        // Silently auto-submit crash to bug dashboard in background
        _autoSubmitCrashes(crashes);
      }
    }

    // 5. Optionally enable shake-to-report.
    if (shakeToReport) {
      // Shake package listener wired in app widget — see README.
    }
  }

  /// Silently submits pending crashes to the bug dashboard.
  /// Runs in background — does not block app startup.
  static Future<void> _autoSubmitCrashes(List<String> crashes) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final devicePlugin = DeviceInfoPlugin();

      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';
      if (Platform.isIOS) {
        final info = await devicePlugin.iosInfo;
        deviceModel = info.utsname.machine;
        osVersion = info.systemVersion;
      } else if (Platform.isAndroid) {
        final info = await devicePlugin.androidInfo;
        deviceModel = '${info.manufacturer} ${info.model}';
        osVersion = 'Android ${info.version.release}';
      }

      for (final crashJson in crashes) {
        await ReportUploader.autoSubmitCrash(
          appName: packageInfo.appName,
          appVersion: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
          deviceModel: deviceModel,
          osVersion: osVersion,
          crashLog: crashJson,
        );
      }

      // Clear pending crashes after successful submission
      await CrashHandler.clearPendingCrashes();
    } catch (_) {
      // Non-critical — crashes will be retried next launch
    }
  }
}

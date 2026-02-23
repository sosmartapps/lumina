import 'package:flutter/material.dart';
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

    // 4. Check if last session crashed and auto-prompt on this launch.
    final showCrashReport = prefs.getBool('show_crash_report') ?? false;
    if (showCrashReport) {
      await prefs.setBool('show_crash_report', false);
      // Delay so the app UI is mounted before showing the sheet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context == null) return;
        final crashes = prefs.getStringList('pending_crashes') ?? [];
        BugReportSheet.show(
          context,
          crashLog: crashes.isNotEmpty ? crashes.last : null,
          isCrashReport: true,
        );
      });
    }

    // 5. Optionally enable shake-to-report.
    if (shakeToReport) {
      // Shake package listener wired in app widget — see README.
    }
  }
}

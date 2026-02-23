import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bug_report.dart';

class ReportUploader {
  /// Uploads report metadata as JSON then attaches all files as multipart.
  static Future<bool> upload(BugReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString('bug_report_endpoint');
    if (endpoint == null) return false;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));

      // JSON metadata field
      request.fields['report'] = jsonEncode(report.toJson());

      // Attach all screenshots and user photos
      for (final file in report.allAttachments) {
        if (await file.exists()) {
          request.files.add(await http.MultipartFile.fromPath(
            'attachments',
            file.path,
          ));
        }
      }

      final streamedResponse = await request.send();
      final success = streamedResponse.statusCode == 200;

      // Optional: ping alert webhook for immediate dev notification
      final alertWebhook = prefs.getString('bug_alert_webhook');
      if (success && alertWebhook != null) {
        await _pingAlertWebhook(alertWebhook, report);
      }

      return success;
    } catch (_) {
      // Queue for retry on next launch if offline
      await _queueForRetry(report);
      return false;
    }
  }

  static Future<void> _pingAlertWebhook(
    String webhookUrl,
    BugReport report,
  ) async {
    try {
      await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': '[${report.appName}] ${report.type.name.toUpperCase()} '
              'from ${report.deviceModel} v${report.appVersion}\n'
              '${report.description}',
        }),
      );
    } catch (_) {
      // Non-critical — report already uploaded.
    }
  }

  static Future<void> _queueForRetry(BugReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('queued_reports') ?? [];
    queue.add(jsonEncode(report.toJson()));
    await prefs.setStringList('queued_reports', queue);
  }

  /// Call on app launch to retry any reports that failed due to no connection.
  static Future<void> retryQueued() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('queued_reports') ?? [];
    if (queue.isEmpty) return;

    final endpoint = prefs.getString('bug_report_endpoint');
    if (endpoint == null) return;

    final remaining = <String>[];
    for (final item in queue) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: item,
        );
        if (response.statusCode != 200) remaining.add(item);
      } catch (_) {
        remaining.add(item);
      }
    }
    await prefs.setStringList('queued_reports', remaining);
  }
}

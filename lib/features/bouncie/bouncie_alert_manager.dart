import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'bouncie_service.dart';

/// Handles alerting logic when phone and vehicle fall out of sync.
class BouncieAlertManager {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Configurable alert cooldown — avoids spamming every poll cycle.
  DateTime? _lastAlertSent;
  static const _alertCooldown = Duration(minutes: 10);

  Future<void> handleSyncResult(
    SyncCheckResult result, {
    required String caregiverName,
    required String caregiverWebhookUrl, // SMS/push backend or n8n webhook
  }) async {
    if (result.inSync) {
      _lastAlertSent = null; // reset when back in sync
      return;
    }

    // Respect cooldown so caregiver isn't flooded.
    if (_lastAlertSent != null &&
        DateTime.now().difference(_lastAlertSent!) < _alertCooldown) {
      return;
    }
    _lastAlertSent = DateTime.now();

    final distanceKm = (result.distanceMeters / 1000).toStringAsFixed(1);
    final message =
        '⚠️ Location mismatch: Phone is ${distanceKm}km from vehicle. '
        'Last vehicle location: '
        '${result.vehicleLocation.latitude.toStringAsFixed(5)}, '
        '${result.vehicleLocation.longitude.toStringAsFixed(5)}';

    // Local notification to user.
    await _sendLocalNotification(
      title: 'Phone & Vehicle Out of Sync',
      body: 'Your phone is ${distanceKm}km from the tracked vehicle.',
    );

    // Caregiver push/SMS via webhook (works with Twilio, n8n, etc.)
    await _notifyCaregiver(
      webhookUrl: caregiverWebhookUrl,
      caregiverName: caregiverName,
      message: message,
      vehicleLat: result.vehicleLocation.latitude,
      vehicleLng: result.vehicleLocation.longitude,
    );
  }

  Future<void> _sendLocalNotification({
    required String title,
    required String body,
  }) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(iOS: iosDetails);
    await _localNotifications.show(
      id: 100,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> _notifyCaregiver({
    required String webhookUrl,
    required String caregiverName,
    required String message,
    required double vehicleLat,
    required double vehicleLng,
  }) async {
    try {
      await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': caregiverName,
          'message': message,
          'mapsLink':
              'https://maps.apple.com/?ll=$vehicleLat,$vehicleLng&q=Vehicle+Location',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Swallow — local notification already went out.
    }
  }
}

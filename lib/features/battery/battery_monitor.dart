import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BatteryMonitor {
  final Battery _battery = Battery();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const _thresholdKey = 'battery_threshold';
  static const _lastAlertKey = 'battery_last_alert';
  static const _alertCooldownMinutes = 20;

  Timer? _pollTimer;
  StreamSubscription<BatteryState>? _stateSubscription;

  // ─── Threshold ────────────────────────────────────────────────────────────

  Future<double> getThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_thresholdKey) ?? 0.20;
  }

  Future<void> setThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdKey, value.clamp(0.05, 0.50));
  }

  // ─── Monitoring ───────────────────────────────────────────────────────────

  void startMonitoring({
    required String caregiverWebhookUrl,
    required String userName,
  }) {
    // React to state changes (plugging in/unplugging).
    _stateSubscription = _battery.onBatteryStateChanged.listen((_) async {
      await _checkAndAlert(
        caregiverWebhookUrl: caregiverWebhookUrl,
        userName: userName,
      );
    });

    // Also poll every 5 minutes — state changes alone may be missed.
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _checkAndAlert(
        caregiverWebhookUrl: caregiverWebhookUrl,
        userName: userName,
      );
    });
  }

  void stopMonitoring() {
    _stateSubscription?.cancel();
    _pollTimer?.cancel();
  }

  // ─── Core Check ──────────────────────────────────────────────────────────

  Future<void> _checkAndAlert({
    required String caregiverWebhookUrl,
    required String userName,
  }) async {
    final state = await _battery.batteryState;

    // Don't alert while charging.
    if (state == BatteryState.charging || state == BatteryState.full) return;

    final level = await _battery.batteryLevel; // 0–100
    final threshold = await getThreshold();

    if (level / 100.0 > threshold) return;

    // Cooldown
    final prefs = await SharedPreferences.getInstance();
    final lastAlert = prefs.getString(_lastAlertKey);
    if (lastAlert != null) {
      final lastTime = DateTime.parse(lastAlert);
      if (DateTime.now().difference(lastTime).inMinutes <
          _alertCooldownMinutes) {
        return;
      }
    }
    await prefs.setString(_lastAlertKey, DateTime.now().toIso8601String());

    // Local user alert.
    await _sendLocalNotification(
      title: '🔋 Low Battery – $level%',
      body: 'Please plug in soon to stay reachable.',
    );

    // Caregiver alert.
    await _alertCaregiver(
      webhookUrl: caregiverWebhookUrl,
      userName: userName,
      batteryLevel: level,
    );
  }

  Future<void> _sendLocalNotification({
    required String title,
    required String body,
  }) async {
    const iosDetails = DarwinNotificationDetails(presentAlert: true);
    await _notifications.show(
      id: 2,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(iOS: iosDetails),
    );
  }

  Future<void> _alertCaregiver({
    required String webhookUrl,
    required String userName,
    required int batteryLevel,
  }) async {
    try {
      await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': "⚠️ $userName's phone battery is at $batteryLevel%. "
              'They may need a reminder to charge their phone.',
          'batteryLevel': batteryLevel,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Local alert already went out; swallow network error.
    }
  }
}

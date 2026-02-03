import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/reminder.dart';
import '../models/medication.dart';

/// Service for handling local and push notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channels
  static const String _reminderChannelId = 'reminder_channel';
  static const String _medicationChannelId = 'medication_channel';
  static const String _alertChannelId = 'alert_channel';
  static const String _geofenceChannelId = 'geofence_channel';

  // Callback handlers
  static Function(String?)? onNotificationTapped;
  static Function(RemoteMessage)? onPushReceived;

  /// Initialize notification service
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTapped?.call(response.payload);
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
  }

  /// Create Android notification channels
  static Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Reminder channel - high importance with sound
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          'Reminders',
          description: 'Reminders and tasks notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Medication channel - max importance
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _medicationChannelId,
          'Medications',
          description: 'Medication reminder notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );

      // Alert channel - max importance
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          'Alerts',
          description: 'Important alerts and emergencies',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );

      // Geofence channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _geofenceChannelId,
          'Location Alerts',
          description: 'Geofence and location alerts',
          importance: Importance.high,
          playSound: true,
        ),
      );
    }
  }

  /// Initialize Firebase Cloud Messaging
  static Future<void> _initializeFirebaseMessaging() async {
    // Request permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      _handleRemoteMessage(message);
      onPushReceived?.call(message);
    });

    // Handle background/terminated state messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened app: ${message.messageId}');
      onNotificationTapped?.call(message.data['payload']);
    });

    // Check for initial message (app opened from notification)
    final RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      onNotificationTapped?.call(initialMessage.data['payload']);
    }
  }

  /// Handle remote messages
  static Future<void> _handleRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await showNotification(
        id: message.hashCode,
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: message.data['payload'],
        channelId: message.data['channel'] ?? _alertChannelId,
      );
    }
  }

  /// Show a local notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = _reminderChannelId,
    bool persistent = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ongoing: persistent,
      autoCancel: !persistent,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule a notification for a specific time
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String channelId = _reminderChannelId,
    bool repeat = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          repeat ? DateTimeComponents.time : null, // Repeat daily at same time
    );
  }

  /// Schedule medication reminder
  static Future<void> scheduleMedicationReminder({
    required Medication medication,
    required MedicationSchedule schedule,
    required String userName,
  }) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final notificationId = '${medication.id}_${schedule.id}'.hashCode;

    await scheduleNotification(
      id: notificationId,
      title: '💊 Time for ${medication.name}',
      body: '$userName, it\'s time to take your ${medication.dosage ?? "medication"}',
      scheduledTime: scheduledTime,
      payload: 'medication:${medication.id}:${schedule.id}',
      channelId: _medicationChannelId,
      repeat: true,
    );
  }

  /// Schedule general reminder
  static Future<void> scheduleReminder({
    required Reminder reminder,
    required String userName,
  }) async {
    final message = reminder.getSpokenMessage(userName);

    await scheduleNotification(
      id: reminder.id.hashCode,
      title: _getReminderTitle(reminder),
      body: message,
      scheduledTime: reminder.scheduledTime,
      payload: 'reminder:${reminder.id}',
      channelId: _reminderChannelId,
      repeat: reminder.repeatFrequency != RepeatFrequency.once,
    );
  }

  /// Cancel a scheduled notification
  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Get FCM token for push notifications
  static Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Save FCM token to Firestore for a user/caregiver
  static Future<void> saveFCMToken({
    required String id,
    required bool isCaregiver,
  }) async {
    final token = await getFCMToken();
    if (token == null) return;

    final collection = isCaregiver ? 'caregivers' : 'users';

    await _firestore.collection(collection).doc(id).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Send push notification to caregivers
  static Future<void> notifyCaregivers({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Get user's caregivers
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final caregiverIds = List<String>.from(userDoc.data()?['caregiverIds'] ?? []);

    for (final caregiverId in caregiverIds) {
      final caregiverDoc =
          await _firestore.collection('caregivers').doc(caregiverId).get();
      final tokens = List<String>.from(caregiverDoc.data()?['fcmTokens'] ?? []);

      // Store notification in Firestore to trigger Cloud Function
      for (final token in tokens) {
        await _firestore.collection('notifications').add({
          'token': token,
          'title': title,
          'body': body,
          'data': data ?? {},
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static String _getChannelName(String channelId) {
    switch (channelId) {
      case _reminderChannelId:
        return 'Reminders';
      case _medicationChannelId:
        return 'Medications';
      case _alertChannelId:
        return 'Alerts';
      case _geofenceChannelId:
        return 'Location Alerts';
      default:
        return 'Notifications';
    }
  }

  static String _getReminderTitle(Reminder reminder) {
    final icon = _getReminderIcon(reminder.type);
    return '$icon ${reminder.title}';
  }

  static String _getReminderIcon(ReminderType type) {
    switch (type) {
      case ReminderType.medication:
        return '💊';
      case ReminderType.task:
        return '✅';
      case ReminderType.appointment:
        return '📅';
      case ReminderType.mealTime:
        return '🍽️';
      case ReminderType.hydration:
        return '💧';
      case ReminderType.exercise:
        return '🏃';
      case ReminderType.petCare:
        return '🐕';
      case ReminderType.general:
        return '🔔';
    }
  }
}

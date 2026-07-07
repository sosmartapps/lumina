import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../models/reminder.dart';
import '../models/medication.dart';
import '../models/pet_feeding.dart';

/// Top-level handler required by flutter_local_notifications for background responses
@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) {
  // Background notification tapped — handled when app resumes
}

/// Service for handling local and push notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channels
  static const String _reminderChannelId = 'reminder_channel';
  static const String _medicationChannelId = 'medication_channel';
  static const String _petFeedingChannelId = 'pet_feeding_channel';
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
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTapped?.call(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationHandler,
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

      // Pet feeding channel - high importance with sound
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _petFeedingChannelId,
          'Pet Feeding',
          description: 'Pet feeding reminder notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
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
    // Request permission WITHOUT awaiting: on Android 13+ this call blocks
    // until the user answers the system dialog (it hung boot for 15s on
    // 2026-07-06). The dialog resolves whenever the user responds; message
    // listeners below work regardless of the outcome.
    unawaited(_firebaseMessaging
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          criticalAlert: true,
        )
        .then((settings) => debugPrint(
            'FCM permission: ${settings.authorizationStatus.name}'))
        .catchError(
            (e) => debugPrint('FCM permission request failed: $e')));

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
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
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
    DateTimeComponents? matchComponents,
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
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          matchComponents ?? (repeat ? DateTimeComponents.time : null),
    );
  }

  /// Schedule all notifications for one pet feeding schedule.
  ///
  /// For daily schedules, each feeding time repeats every day. For
  /// specific-day schedules, each (time, weekday) pair repeats weekly on that
  /// weekday. Notification IDs are deterministic so [cancelPetFeeding] can
  /// remove exactly these entries when a schedule is edited or deleted.
  static Future<void> schedulePetFeeding({required PetFeeding feeding}) async {
    if (!feeding.isActive) return;

    final title = '${feeding.petType.emoji} Feed ${feeding.petName}';

    for (final time in feeding.feedingTimes) {
      final body = _petFeedingBody(feeding, time);

      if (feeding.isDaily) {
        await scheduleNotification(
          id: _petFeedingId(feeding.id, time.id),
          title: title,
          body: body,
          scheduledTime: _nextDailyOccurrence(time.hour, time.minute),
          payload: 'feeding:${feeding.id}',
          channelId: _petFeedingChannelId,
          matchComponents: DateTimeComponents.time,
        );
      } else {
        for (final weekday in feeding.repeatDays!) {
          await scheduleNotification(
            id: _petFeedingId(feeding.id, time.id, weekday: weekday),
            title: title,
            body: body,
            scheduledTime:
                _nextWeekdayOccurrence(weekday, time.hour, time.minute),
            payload: 'feeding:${feeding.id}',
            channelId: _petFeedingChannelId,
            matchComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
  }

  /// Cancel every notification previously scheduled for [feeding].
  static Future<void> cancelPetFeeding(PetFeeding feeding) async {
    for (final time in feeding.feedingTimes) {
      // Cancel the daily-mode id...
      await cancelNotification(_petFeedingId(feeding.id, time.id));
      // ...and any per-weekday ids (harmless if they were never scheduled).
      for (var weekday = 1; weekday <= 7; weekday++) {
        await cancelNotification(
          _petFeedingId(feeding.id, time.id, weekday: weekday),
        );
      }
    }
  }

  static int _petFeedingId(String feedingId, String timeId, {int? weekday}) {
    final key = weekday == null
        ? 'petfeed_${feedingId}_$timeId'
        : 'petfeed_${feedingId}_${timeId}_$weekday';
    return key.hashCode;
  }

  static String _petFeedingBody(PetFeeding feeding, FeedingTime time) {
    final parts = <String>[];
    if (time.label != null && time.label!.isNotEmpty) parts.add(time.label!);
    if (feeding.amount != null && feeding.amount!.isNotEmpty) {
      parts.add(feeding.amount!);
    }
    if (feeding.foodType != null && feeding.foodType!.isNotEmpty) {
      parts.add('of ${feeding.foodType}');
    }
    if (parts.isEmpty) {
      return 'Time to feed ${feeding.petName}';
    }
    return 'Time to feed ${feeding.petName} — ${parts.join(' ')}';
  }

  /// Next occurrence today (or tomorrow if already past) at [hour]:[minute].
  static DateTime _nextDailyOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// Next occurrence of [weekday] (1=Mon..7=Sun) at [hour]:[minute].
  static DateTime _nextWeekdayOccurrence(int weekday, int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    while (next.weekday != weekday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
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
      title: '\u{1F48A} Time for ${medication.name}',
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
    await _localNotifications.cancel(id: id);
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
    try {
      // Get user's caregivers
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('User doc not found for userId: $userId');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
        debugPrint('User data is null for userId: $userId');
        return;
      }

      final caregiverIds = List<String>.from(userData['caregiverIds'] ?? []);

      for (final caregiverId in caregiverIds) {
        try {
          final caregiverDoc =
              await _firestore.collection('caregivers').doc(caregiverId).get();
          if (!caregiverDoc.exists) {
            debugPrint('Caregiver doc not found for caregiverId: $caregiverId');
            continue;
          }

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
        } catch (e) {
          debugPrint('Error notifying caregiver $caregiverId: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error notifying caregivers: $e');
    }
  }

  /// Send SMS to primary caregiver about a sundown alert
  static Future<void> sendSmsToCaregiver({
    required String userId,
    required String userName,
    required String message,
  }) async {
    try {
      // Get user's primary caregiver
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final primaryCaregiverId = userDoc.data()?['primaryCaregiverId'] as String?;
      final caregiverIds = List<String>.from(userDoc.data()?['caregiverIds'] ?? []);

      final caregiverId = primaryCaregiverId ?? (caregiverIds.isNotEmpty ? caregiverIds.first : null);
      if (caregiverId == null) return;

      final caregiverDoc = await _firestore.collection('caregivers').doc(caregiverId).get();
      final phoneNumber = caregiverDoc.data()?['phoneNumber'] as String?;
      if (phoneNumber == null || phoneNumber.isEmpty) return;

      // Use sms: URI scheme to send text message
      final encodedMessage = Uri.encodeComponent(message);
      final smsUri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (e) {
      debugPrint('Error sending SMS to caregiver: $e');
    }
  }

  static String _getChannelName(String channelId) {
    switch (channelId) {
      case _reminderChannelId:
        return 'Reminders';
      case _medicationChannelId:
        return 'Medications';
      case _petFeedingChannelId:
        return 'Pet Feeding';
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
        return '\u{1F48A}';
      case ReminderType.task:
        return '\u{2705}';
      case ReminderType.appointment:
        return '\u{1F4C5}';
      case ReminderType.mealTime:
        return '\u{1F37D}\u{FE0F}';
      case ReminderType.hydration:
        return '\u{1F4A7}';
      case ReminderType.exercise:
        return '\u{1F3C3}';
      case ReminderType.petCare:
        return '\u{1F415}';
      case ReminderType.general:
        return '\u{1F514}';
    }
  }
}

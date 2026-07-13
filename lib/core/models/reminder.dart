import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a reminder for the user
class Reminder {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? spokenMessage; // Custom TTS message
  final ReminderType type;
  final DateTime scheduledTime;
  final List<int>? repeatDays; // 1-7 for Mon-Sun
  final RepeatFrequency repeatFrequency;
  final bool isActive;
  final bool requiresConfirmation;
  final bool requiresPhoto;
  final String? iconName;
  final String? color;
  final int snoozeMinutes;
  final int maxSnoozeCount;
  final int currentSnoozeCount;
  final DateTime? lastTriggeredAt;
  final DateTime? completedAt;
  final String? completionPhotoUrl;

  /// Photo verification verdict: null (no photo), 'pending', 'verified',
  /// 'failed', 'error'. Set to 'verified' locally when the photo hash
  /// matches [referencePhotoHash] (free), otherwise written by the
  /// verifyTaskCompletionPhoto Cloud Function (Claude vision).
  final String? verificationStatus;
  final String? verificationReason;

  /// dHash of the completion photo (computed on device at capture).
  final String? completionPhotoHash;

  /// dHash of the last AI-verified completion photo — the "known good"
  /// reference future photos are matched against on device.
  final String? referencePhotoHash;
  final bool homeOnly; // Only trigger when user is at home
  final DateTime createdAt;
  final String createdBy; // Caregiver ID

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.spokenMessage,
    required this.type,
    required this.scheduledTime,
    this.repeatDays,
    this.repeatFrequency = RepeatFrequency.daily,
    this.isActive = true,
    this.requiresConfirmation = false,
    this.requiresPhoto = false,
    this.iconName,
    this.color,
    this.snoozeMinutes = 10,
    this.maxSnoozeCount = 3,
    this.currentSnoozeCount = 0,
    this.lastTriggeredAt,
    this.completedAt,
    this.completionPhotoUrl,
    this.verificationStatus,
    this.verificationReason,
    this.completionPhotoHash,
    this.referencePhotoHash,
    bool? homeOnly,
    DateTime? createdAt,
    required this.createdBy,
  }) : homeOnly = homeOnly ?? _defaultHomeOnly(type),
       createdAt = createdAt ?? DateTime.now();

  /// Reminder types that default to home-only triggering
  static bool _defaultHomeOnly(ReminderType type) {
    return type == ReminderType.medication ||
        type == ReminderType.petCare ||
        type == ReminderType.mealTime;
  }

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reminder(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      spokenMessage: data['spokenMessage'],
      type: ReminderType.fromString(data['type'] ?? 'general'),
      scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
      repeatDays: data['repeatDays'] != null
          ? List<int>.from(data['repeatDays'])
          : null,
      repeatFrequency:
          RepeatFrequency.fromString(data['repeatFrequency'] ?? 'daily'),
      isActive: data['isActive'] ?? true,
      requiresConfirmation: data['requiresConfirmation'] ?? false,
      requiresPhoto: data['requiresPhoto'] ?? false,
      iconName: data['iconName'],
      color: data['color'],
      snoozeMinutes: data['snoozeMinutes'] ?? 10,
      maxSnoozeCount: data['maxSnoozeCount'] ?? 3,
      currentSnoozeCount: data['currentSnoozeCount'] ?? 0,
      lastTriggeredAt: (data['lastTriggeredAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completionPhotoUrl: data['completionPhotoUrl'],
      verificationStatus: data['verificationStatus'],
      verificationReason: data['verificationReason'],
      completionPhotoHash: data['completionPhotoHash'],
      referencePhotoHash: data['referencePhotoHash'],
      homeOnly: data['homeOnly'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'spokenMessage': spokenMessage,
      'type': type.value,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'repeatDays': repeatDays,
      'repeatFrequency': repeatFrequency.value,
      'isActive': isActive,
      'requiresConfirmation': requiresConfirmation,
      'requiresPhoto': requiresPhoto,
      'iconName': iconName,
      'color': color,
      'snoozeMinutes': snoozeMinutes,
      'maxSnoozeCount': maxSnoozeCount,
      'currentSnoozeCount': currentSnoozeCount,
      'lastTriggeredAt':
          lastTriggeredAt != null ? Timestamp.fromDate(lastTriggeredAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completionPhotoUrl': completionPhotoUrl,
      'verificationStatus': verificationStatus,
      'verificationReason': verificationReason,
      'completionPhotoHash': completionPhotoHash,
      'referencePhotoHash': referencePhotoHash,
      'homeOnly': homeOnly,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  Reminder copyWith({
    String? title,
    String? description,
    String? spokenMessage,
    ReminderType? type,
    DateTime? scheduledTime,
    List<int>? repeatDays,
    RepeatFrequency? repeatFrequency,
    bool? isActive,
    bool? requiresConfirmation,
    bool? requiresPhoto,
    String? iconName,
    String? color,
    int? snoozeMinutes,
    int? maxSnoozeCount,
    int? currentSnoozeCount,
    DateTime? lastTriggeredAt,
    DateTime? completedAt,
    String? completionPhotoUrl,
    bool? homeOnly,
  }) {
    return Reminder(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      spokenMessage: spokenMessage ?? this.spokenMessage,
      type: type ?? this.type,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatFrequency: repeatFrequency ?? this.repeatFrequency,
      isActive: isActive ?? this.isActive,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      currentSnoozeCount: currentSnoozeCount ?? this.currentSnoozeCount,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      completedAt: completedAt ?? this.completedAt,
      completionPhotoUrl: completionPhotoUrl ?? this.completionPhotoUrl,
      verificationStatus: verificationStatus,
      verificationReason: verificationReason,
      completionPhotoHash: completionPhotoHash,
      referencePhotoHash: referencePhotoHash,
      homeOnly: homeOnly ?? this.homeOnly,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  /// Get the spoken message, falling back to title
  String getSpokenMessage(String userName) {
    if (spokenMessage != null && spokenMessage!.isNotEmpty) {
      return spokenMessage!.replaceAll('{name}', userName);
    }
    return '$userName, $title';
  }
}

enum ReminderType {
  medication('medication'),
  task('task'),
  appointment('appointment'),
  mealTime('meal_time'),
  hydration('hydration'),
  exercise('exercise'),
  petCare('pet_care'),
  general('general');

  final String value;
  const ReminderType(this.value);

  static ReminderType fromString(String value) {
    return ReminderType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReminderType.general,
    );
  }

  String get displayName {
    switch (this) {
      case ReminderType.medication:
        return 'Medication';
      case ReminderType.task:
        return 'Task';
      case ReminderType.appointment:
        return 'Appointment';
      case ReminderType.mealTime:
        return 'Meal Time';
      case ReminderType.hydration:
        return 'Stay Hydrated';
      case ReminderType.exercise:
        return 'Exercise';
      case ReminderType.petCare:
        return 'Pet Care';
      case ReminderType.general:
        return 'Reminder';
    }
  }

  String get defaultIcon {
    switch (this) {
      case ReminderType.medication:
        return 'medication';
      case ReminderType.task:
        return 'check_circle';
      case ReminderType.appointment:
        return 'event';
      case ReminderType.mealTime:
        return 'restaurant';
      case ReminderType.hydration:
        return 'water_drop';
      case ReminderType.exercise:
        return 'fitness_center';
      case ReminderType.petCare:
        return 'pets';
      case ReminderType.general:
        return 'notifications';
    }
  }
}

enum RepeatFrequency {
  once('once'),
  daily('daily'),
  weekly('weekly'),
  custom('custom');

  final String value;
  const RepeatFrequency(this.value);

  static RepeatFrequency fromString(String value) {
    return RepeatFrequency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RepeatFrequency.daily,
    );
  }

  String get displayName {
    switch (this) {
      case RepeatFrequency.once:
        return 'One Time';
      case RepeatFrequency.daily:
        return 'Every Day';
      case RepeatFrequency.weekly:
        return 'Every Week';
      case RepeatFrequency.custom:
        return 'Custom Days';
    }
  }
}

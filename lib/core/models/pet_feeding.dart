import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Kind of pet a feeding schedule belongs to. Used only for iconography and
/// friendly labels — the reminder logic is identical across types.
enum PetType {
  dog('dog'),
  cat('cat'),
  bird('bird'),
  fish('fish'),
  rabbit('rabbit'),
  reptile('reptile'),
  other('other');

  final String value;
  const PetType(this.value);

  static PetType fromString(String value) {
    return PetType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PetType.dog,
    );
  }

  String get displayName {
    switch (this) {
      case PetType.dog:
        return 'Dog';
      case PetType.cat:
        return 'Cat';
      case PetType.bird:
        return 'Bird';
      case PetType.fish:
        return 'Fish';
      case PetType.rabbit:
        return 'Rabbit';
      case PetType.reptile:
        return 'Reptile';
      case PetType.other:
        return 'Other';
    }
  }

  /// Emoji used in notification titles.
  String get emoji {
    switch (this) {
      case PetType.dog:
        return '\u{1F415}'; // 🐕
      case PetType.cat:
        return '\u{1F408}'; // 🐈
      case PetType.bird:
        return '\u{1F426}'; // 🐦
      case PetType.fish:
        return '\u{1F41F}'; // 🐟
      case PetType.rabbit:
        return '\u{1F407}'; // 🐇
      case PetType.reptile:
        return '\u{1F98E}'; // 🦎
      case PetType.other:
        return '\u{1F43E}'; // 🐾
    }
  }

  IconData get icon {
    switch (this) {
      case PetType.dog:
        return Icons.pets;
      case PetType.cat:
        return Icons.pets;
      case PetType.bird:
        return Icons.flutter_dash;
      case PetType.fish:
        return Icons.set_meal;
      case PetType.rabbit:
        return Icons.cruelty_free;
      case PetType.reptile:
        return Icons.bug_report;
      case PetType.other:
        return Icons.pets;
    }
  }
}

/// A single time of day at which a pet should be fed (e.g. "Morning" 7:00 AM).
class FeedingTime {
  final String id;
  final int hour; // 0-23
  final int minute; // 0-59
  final String? label; // e.g. "Breakfast", "Dinner"

  FeedingTime({
    required this.id,
    required this.hour,
    required this.minute,
    this.label,
  });

  factory FeedingTime.fromMap(Map<String, dynamic> map) {
    return FeedingTime(
      id: map['id'] ?? '',
      hour: map['hour'] ?? 8,
      minute: map['minute'] ?? 0,
      label: map['label'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
    };
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get timeString {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

/// A recurring feeding schedule for one pet.
///
/// [repeatDays] is null/empty for "every day", otherwise a list of weekday
/// numbers (1 = Monday ... 7 = Sunday, matching [DateTime.weekday]).
/// [feedingTimes] holds one or more times of day the pet is fed.
class PetFeeding {
  final String id;

  /// The patient (Lumina user) this schedule belongs to.
  final String userId;

  final String petName;
  final PetType petType;

  /// e.g. "Kibble", "Wet food", "Seeds".
  final String? foodType;

  /// e.g. "1 cup", "2 scoops".
  final String? amount;

  /// Photos of the food/portions (e.g. the measuring cup of kibble, the
  /// wet-food container) so whoever feeds the pet sees exactly what to use.
  final List<String> foodPhotoUrls;

  final List<FeedingTime> feedingTimes;

  /// null/empty = every day; otherwise specific weekdays (1=Mon..7=Sun).
  final List<int>? repeatDays;

  final bool isActive;
  final String? notes;

  /// Denormalized timestamp of the most recent feeding, for quick
  /// "last fed" display without querying the logs collection.
  final DateTime? lastFedAt;

  final DateTime createdAt;
  final String createdBy; // Caregiver / user uid who created it.

  PetFeeding({
    required this.id,
    required this.userId,
    required this.petName,
    this.petType = PetType.dog,
    this.foodType,
    this.amount,
    this.foodPhotoUrls = const [],
    this.feedingTimes = const [],
    this.repeatDays,
    this.isActive = true,
    this.notes,
    this.lastFedAt,
    DateTime? createdAt,
    required this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  /// True if this schedule fires every day.
  bool get isDaily => repeatDays == null || repeatDays!.isEmpty;

  /// Human-readable recurrence, e.g. "Every day" or "Mon, Wed, Fri".
  String get repeatDescription {
    if (isDaily) return 'Every day';
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...repeatDays!]..sort();
    return sorted.map((d) => names[d]).join(', ');
  }

  /// Whether this schedule should fire today.
  bool get isScheduledToday {
    if (isDaily) return true;
    return repeatDays!.contains(DateTime.now().weekday);
  }

  factory PetFeeding.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PetFeeding(
      id: doc.id,
      userId: data['userId'] ?? '',
      petName: data['petName'] ?? '',
      petType: PetType.fromString(data['petType'] ?? 'dog'),
      foodType: data['foodType'],
      amount: data['amount'],
      foodPhotoUrls: List<String>.from(data['foodPhotoUrls'] ?? []),
      feedingTimes: (data['feedingTimes'] as List<dynamic>?)
              ?.map((e) => FeedingTime.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      repeatDays:
          data['repeatDays'] != null ? List<int>.from(data['repeatDays']) : null,
      isActive: data['isActive'] ?? true,
      notes: data['notes'],
      lastFedAt: (data['lastFedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'petName': petName,
      'petType': petType.value,
      'foodType': foodType,
      'amount': amount,
      'foodPhotoUrls': foodPhotoUrls,
      'feedingTimes': feedingTimes.map((e) => e.toMap()).toList(),
      'repeatDays': repeatDays,
      'isActive': isActive,
      'notes': notes,
      'lastFedAt': lastFedAt != null ? Timestamp.fromDate(lastFedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  PetFeeding copyWith({
    String? petName,
    PetType? petType,
    String? foodType,
    String? amount,
    List<String>? foodPhotoUrls,
    List<FeedingTime>? feedingTimes,
    List<int>? repeatDays,
    bool? isActive,
    String? notes,
    DateTime? lastFedAt,
  }) {
    return PetFeeding(
      id: id,
      userId: userId,
      petName: petName ?? this.petName,
      petType: petType ?? this.petType,
      foodType: foodType ?? this.foodType,
      amount: amount ?? this.amount,
      foodPhotoUrls: foodPhotoUrls ?? this.foodPhotoUrls,
      feedingTimes: feedingTimes ?? this.feedingTimes,
      repeatDays: repeatDays ?? this.repeatDays,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  /// Today's feeding times as concrete DateTimes (for "next feeding" logic).
  List<DateTime> todayFeedingDateTimes() {
    final now = DateTime.now();
    if (!isScheduledToday) return [];
    final times = feedingTimes
        .map((t) => DateTime(now.year, now.month, now.day, t.hour, t.minute))
        .toList();
    times.sort();
    return times;
  }

  /// The next upcoming feeding time today, or null if none remain today.
  DateTime? get nextFeedingToday {
    final now = DateTime.now();
    for (final t in todayFeedingDateTimes()) {
      if (t.isAfter(now)) return t;
    }
    return null;
  }
}

/// A record of a pet actually being fed.
class FeedingLog {
  final String id;
  final String feedingId;
  final String userId;
  final String petName;

  /// The scheduled slot this feeding satisfied (null for an ad-hoc feeding).
  final DateTime? scheduledTime;

  final DateTime fedAt;

  // Snapshot of what was given, in case the schedule later changes.
  final String? foodType;
  final String? amount;

  /// Display name of whoever marked it fed.
  final String? fedByName;

  final String? notes;

  FeedingLog({
    required this.id,
    required this.feedingId,
    required this.userId,
    required this.petName,
    this.scheduledTime,
    DateTime? fedAt,
    this.foodType,
    this.amount,
    this.fedByName,
    this.notes,
  }) : fedAt = fedAt ?? DateTime.now();

  factory FeedingLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedingLog(
      id: doc.id,
      feedingId: data['feedingId'] ?? '',
      userId: data['userId'] ?? '',
      petName: data['petName'] ?? '',
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      fedAt: (data['fedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      foodType: data['foodType'],
      amount: data['amount'],
      fedByName: data['fedByName'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'feedingId': feedingId,
      'userId': userId,
      'petName': petName,
      'scheduledTime':
          scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'fedAt': Timestamp.fromDate(fedAt),
      'foodType': foodType,
      'amount': amount,
      'fedByName': fedByName,
      'notes': notes,
    };
  }
}

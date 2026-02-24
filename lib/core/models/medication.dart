import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a medication with tracking
class Medication {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String? dosage;
  final String? instructions;
  final List<MedicationSchedule> schedules;
  final String? prescriptionId; // Link to Prescription document
  final String? pillContainerPhotoUrl; // Reference photo of full container
  final String? organizerFilledPhotoUrl; // Reference photo of filled pill organizer
  final String? organizerEmptyPhotoUrl; // Reference photo of empty organizer compartment
  final String? pillCloseUpPhotoUrl; // Reference photo of the actual pills/tablets
  final String? color;
  final String? iconName;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final int refillAlertDays; // Alert when N days of medication left
  final int currentSupply; // Number of doses remaining
  final DateTime createdAt;
  final String createdBy;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.dosage,
    this.instructions,
    this.schedules = const [],
    this.prescriptionId,
    this.pillContainerPhotoUrl,
    this.organizerFilledPhotoUrl,
    this.organizerEmptyPhotoUrl,
    this.pillCloseUpPhotoUrl,
    this.color,
    this.iconName,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.refillAlertDays = 7,
    this.currentSupply = 0,
    DateTime? createdAt,
    required this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Medication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medication(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      dosage: data['dosage'],
      instructions: data['instructions'],
      schedules: (data['schedules'] as List<dynamic>?)
              ?.map((e) => MedicationSchedule.fromMap(e))
              .toList() ??
          [],
      prescriptionId: data['prescriptionId'],
      pillContainerPhotoUrl: data['pillContainerPhotoUrl'],
      organizerFilledPhotoUrl: data['organizerFilledPhotoUrl'],
      organizerEmptyPhotoUrl: data['organizerEmptyPhotoUrl'],
      pillCloseUpPhotoUrl: data['pillCloseUpPhotoUrl'],
      color: data['color'],
      iconName: data['iconName'],
      isActive: data['isActive'] ?? true,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      refillAlertDays: data['refillAlertDays'] ?? 7,
      currentSupply: data['currentSupply'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'dosage': dosage,
      'instructions': instructions,
      'schedules': schedules.map((e) => e.toMap()).toList(),
      'prescriptionId': prescriptionId,
      'pillContainerPhotoUrl': pillContainerPhotoUrl,
      'organizerFilledPhotoUrl': organizerFilledPhotoUrl,
      'organizerEmptyPhotoUrl': organizerEmptyPhotoUrl,
      'pillCloseUpPhotoUrl': pillCloseUpPhotoUrl,
      'color': color,
      'iconName': iconName,
      'isActive': isActive,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'refillAlertDays': refillAlertDays,
      'currentSupply': currentSupply,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  Medication copyWith({
    String? name,
    String? description,
    String? dosage,
    String? instructions,
    List<MedicationSchedule>? schedules,
    String? prescriptionId,
    String? pillContainerPhotoUrl,
    String? organizerFilledPhotoUrl,
    String? organizerEmptyPhotoUrl,
    String? pillCloseUpPhotoUrl,
    String? color,
    String? iconName,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    int? refillAlertDays,
    int? currentSupply,
  }) {
    return Medication(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      schedules: schedules ?? this.schedules,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      pillContainerPhotoUrl:
          pillContainerPhotoUrl ?? this.pillContainerPhotoUrl,
      organizerFilledPhotoUrl:
          organizerFilledPhotoUrl ?? this.organizerFilledPhotoUrl,
      organizerEmptyPhotoUrl:
          organizerEmptyPhotoUrl ?? this.organizerEmptyPhotoUrl,
      pillCloseUpPhotoUrl:
          pillCloseUpPhotoUrl ?? this.pillCloseUpPhotoUrl,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      refillAlertDays: refillAlertDays ?? this.refillAlertDays,
      currentSupply: currentSupply ?? this.currentSupply,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}

/// Schedule for when medication should be taken
class MedicationSchedule {
  final String id;
  final int hour;
  final int minute;
  final List<int>? days; // 1-7 for Mon-Sun, null for every day
  final String? label; // e.g., "Morning", "With Breakfast"

  MedicationSchedule({
    required this.id,
    required this.hour,
    required this.minute,
    this.days,
    this.label,
  });

  factory MedicationSchedule.fromMap(Map<String, dynamic> map) {
    return MedicationSchedule(
      id: map['id'] ?? '',
      hour: map['hour'] ?? 8,
      minute: map['minute'] ?? 0,
      days: map['days'] != null ? List<int>.from(map['days']) : null,
      label: map['label'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'days': days,
      'label': label,
    };
  }

  String get timeString {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

/// Record of medication being taken
class MedicationLog {
  final String id;
  final String medicationId;
  final String userId;
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final MedicationLogStatus status;
  final String? photoUrl;
  final String? notes;
  final bool verifiedByComparison; // Photo comparison verified
  final double? comparisonScore; // Similarity score for photo comparison
  final DateTime createdAt;

  MedicationLog({
    required this.id,
    required this.medicationId,
    required this.userId,
    required this.scheduledTime,
    this.takenTime,
    this.status = MedicationLogStatus.pending,
    this.photoUrl,
    this.notes,
    this.verifiedByComparison = false,
    this.comparisonScore,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MedicationLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicationLog(
      id: doc.id,
      medicationId: data['medicationId'] ?? '',
      userId: data['userId'] ?? '',
      scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
      takenTime: (data['takenTime'] as Timestamp?)?.toDate(),
      status: MedicationLogStatus.fromString(data['status'] ?? 'pending'),
      photoUrl: data['photoUrl'],
      notes: data['notes'],
      verifiedByComparison: data['verifiedByComparison'] ?? false,
      comparisonScore: data['comparisonScore']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'medicationId': medicationId,
      'userId': userId,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'takenTime': takenTime != null ? Timestamp.fromDate(takenTime!) : null,
      'status': status.value,
      'photoUrl': photoUrl,
      'notes': notes,
      'verifiedByComparison': verifiedByComparison,
      'comparisonScore': comparisonScore,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum MedicationLogStatus {
  pending('pending'),
  taken('taken'),
  missed('missed'),
  snoozed('snoozed'),
  skipped('skipped');

  final String value;
  const MedicationLogStatus(this.value);

  static MedicationLogStatus fromString(String value) {
    return MedicationLogStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MedicationLogStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case MedicationLogStatus.pending:
        return 'Pending';
      case MedicationLogStatus.taken:
        return 'Taken';
      case MedicationLogStatus.missed:
        return 'Missed';
      case MedicationLogStatus.snoozed:
        return 'Snoozed';
      case MedicationLogStatus.skipped:
        return 'Skipped';
    }
  }
}

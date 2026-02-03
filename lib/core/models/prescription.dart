import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a prescription
enum PrescriptionStatus {
  active,
  discontinued,
  onHold,
  completed,
}

/// Represents a prescription medication with refill tracking
class Prescription {
  final String id;
  final String userId;
  final String medicationName;
  final String? genericName;
  final String? brandName;
  final String dosage; // e.g., "10mg", "500mg"
  final String frequency; // e.g., "twice daily", "every 8 hours"
  final String? instructions; // e.g., "Take with food"
  final String? prescribedBy; // Doctor name
  final String? prescribedById; // Healthcare provider ID
  final String? pharmacyId;
  final String? pharmacyName;
  final String? rxNumber; // Prescription/Rx number
  final int? totalQuantity; // Total pills per refill
  final int? remainingQuantity; // Estimated remaining pills
  final int? refillsRemaining; // Number of refills left
  final int? refillsTotal; // Total refills prescribed
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? lastFilledDate;
  final DateTime? nextRefillDate; // When refill is due
  final DateTime? expirationDate; // When prescription expires
  final int? daysSupply; // Days each refill lasts
  final String? reason; // Why prescribed (condition it treats)
  final String? sideEffects;
  final String? warnings;
  final String? notes;
  final PrescriptionStatus status;
  final bool refillReminderEnabled;
  final int refillReminderDaysBefore; // Days before running out to remind
  final DateTime createdAt;
  final DateTime updatedAt;

  Prescription({
    required this.id,
    required this.userId,
    required this.medicationName,
    this.genericName,
    this.brandName,
    required this.dosage,
    required this.frequency,
    this.instructions,
    this.prescribedBy,
    this.prescribedById,
    this.pharmacyId,
    this.pharmacyName,
    this.rxNumber,
    this.totalQuantity,
    this.remainingQuantity,
    this.refillsRemaining,
    this.refillsTotal,
    this.startDate,
    this.endDate,
    this.lastFilledDate,
    this.nextRefillDate,
    this.expirationDate,
    this.daysSupply,
    this.reason,
    this.sideEffects,
    this.warnings,
    this.notes,
    this.status = PrescriptionStatus.active,
    this.refillReminderEnabled = true,
    this.refillReminderDaysBefore = 7,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate estimated days until refill needed based on remaining quantity and frequency
  int? get daysUntilRefillNeeded {
    if (remainingQuantity == null || daysSupply == null || totalQuantity == null) {
      return null;
    }
    final pillsPerDay = totalQuantity! / daysSupply!;
    if (pillsPerDay <= 0) return null;
    return (remainingQuantity! / pillsPerDay).floor();
  }

  /// Check if refill is needed soon
  bool get needsRefillSoon {
    final days = daysUntilRefillNeeded;
    if (days == null) {
      // Fall back to nextRefillDate
      if (nextRefillDate != null) {
        final daysUntil = nextRefillDate!.difference(DateTime.now()).inDays;
        return daysUntil <= refillReminderDaysBefore;
      }
      return false;
    }
    return days <= refillReminderDaysBefore;
  }

  /// Check if refill is overdue
  bool get isRefillOverdue {
    final days = daysUntilRefillNeeded;
    if (days != null && days <= 0) return true;
    if (nextRefillDate != null && DateTime.now().isAfter(nextRefillDate!)) {
      return true;
    }
    return false;
  }

  /// Check if prescription has no refills left
  bool get noRefillsRemaining => refillsRemaining != null && refillsRemaining! <= 0;

  /// Check if prescription is expired
  bool get isExpired => expirationDate != null && DateTime.now().isAfter(expirationDate!);

  factory Prescription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Prescription(
      id: doc.id,
      userId: data['userId'] ?? '',
      medicationName: data['medicationName'] ?? '',
      genericName: data['genericName'],
      brandName: data['brandName'],
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      instructions: data['instructions'],
      prescribedBy: data['prescribedBy'],
      prescribedById: data['prescribedById'],
      pharmacyId: data['pharmacyId'],
      pharmacyName: data['pharmacyName'],
      rxNumber: data['rxNumber'],
      totalQuantity: data['totalQuantity'],
      remainingQuantity: data['remainingQuantity'],
      refillsRemaining: data['refillsRemaining'],
      refillsTotal: data['refillsTotal'],
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      lastFilledDate: data['lastFilledDate'] != null
          ? (data['lastFilledDate'] as Timestamp).toDate()
          : null,
      nextRefillDate: data['nextRefillDate'] != null
          ? (data['nextRefillDate'] as Timestamp).toDate()
          : null,
      expirationDate: data['expirationDate'] != null
          ? (data['expirationDate'] as Timestamp).toDate()
          : null,
      daysSupply: data['daysSupply'],
      reason: data['reason'],
      sideEffects: data['sideEffects'],
      warnings: data['warnings'],
      notes: data['notes'],
      status: PrescriptionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PrescriptionStatus.active,
      ),
      refillReminderEnabled: data['refillReminderEnabled'] ?? true,
      refillReminderDaysBefore: data['refillReminderDaysBefore'] ?? 7,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'medicationName': medicationName,
      'genericName': genericName,
      'brandName': brandName,
      'dosage': dosage,
      'frequency': frequency,
      'instructions': instructions,
      'prescribedBy': prescribedBy,
      'prescribedById': prescribedById,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'rxNumber': rxNumber,
      'totalQuantity': totalQuantity,
      'remainingQuantity': remainingQuantity,
      'refillsRemaining': refillsRemaining,
      'refillsTotal': refillsTotal,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lastFilledDate': lastFilledDate != null ? Timestamp.fromDate(lastFilledDate!) : null,
      'nextRefillDate': nextRefillDate != null ? Timestamp.fromDate(nextRefillDate!) : null,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate!) : null,
      'daysSupply': daysSupply,
      'reason': reason,
      'sideEffects': sideEffects,
      'warnings': warnings,
      'notes': notes,
      'status': status.name,
      'refillReminderEnabled': refillReminderEnabled,
      'refillReminderDaysBefore': refillReminderDaysBefore,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Prescription copyWith({
    String? id,
    String? userId,
    String? medicationName,
    String? genericName,
    String? brandName,
    String? dosage,
    String? frequency,
    String? instructions,
    String? prescribedBy,
    String? prescribedById,
    String? pharmacyId,
    String? pharmacyName,
    String? rxNumber,
    int? totalQuantity,
    int? remainingQuantity,
    int? refillsRemaining,
    int? refillsTotal,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastFilledDate,
    DateTime? nextRefillDate,
    DateTime? expirationDate,
    int? daysSupply,
    String? reason,
    String? sideEffects,
    String? warnings,
    String? notes,
    PrescriptionStatus? status,
    bool? refillReminderEnabled,
    int? refillReminderDaysBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicationName: medicationName ?? this.medicationName,
      genericName: genericName ?? this.genericName,
      brandName: brandName ?? this.brandName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      instructions: instructions ?? this.instructions,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      prescribedById: prescribedById ?? this.prescribedById,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      rxNumber: rxNumber ?? this.rxNumber,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      refillsTotal: refillsTotal ?? this.refillsTotal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastFilledDate: lastFilledDate ?? this.lastFilledDate,
      nextRefillDate: nextRefillDate ?? this.nextRefillDate,
      expirationDate: expirationDate ?? this.expirationDate,
      daysSupply: daysSupply ?? this.daysSupply,
      reason: reason ?? this.reason,
      sideEffects: sideEffects ?? this.sideEffects,
      warnings: warnings ?? this.warnings,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      refillReminderEnabled: refillReminderEnabled ?? this.refillReminderEnabled,
      refillReminderDaysBefore: refillReminderDaysBefore ?? this.refillReminderDaysBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Record of a prescription being filled
class RefillRecord {
  final String id;
  final String prescriptionId;
  final DateTime filledDate;
  final String? pharmacyId;
  final String? pharmacyName;
  final int? quantity;
  final double? cost;
  final String? notes;

  RefillRecord({
    required this.id,
    required this.prescriptionId,
    required this.filledDate,
    this.pharmacyId,
    this.pharmacyName,
    this.quantity,
    this.cost,
    this.notes,
  });

  factory RefillRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RefillRecord(
      id: doc.id,
      prescriptionId: data['prescriptionId'] ?? '',
      filledDate: (data['filledDate'] as Timestamp).toDate(),
      pharmacyId: data['pharmacyId'],
      pharmacyName: data['pharmacyName'],
      quantity: data['quantity'],
      cost: data['cost']?.toDouble(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'prescriptionId': prescriptionId,
      'filledDate': Timestamp.fromDate(filledDate),
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'quantity': quantity,
      'cost': cost,
      'notes': notes,
    };
  }
}

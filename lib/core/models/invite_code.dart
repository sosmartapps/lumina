import 'package:cloud_firestore/cloud_firestore.dart';
import 'caregiver.dart';

/// Represents an invite code for linking a new caregiver to a patient
class InviteCode {
  final String id;
  final String code;
  final String patientId;
  final String createdBy;
  final CaregiverRole assignedRole;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedAt;

  InviteCode({
    required this.id,
    required this.code,
    required this.patientId,
    required this.createdBy,
    required this.assignedRole,
    DateTime? createdAt,
    DateTime? expiresAt,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;

  factory InviteCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteCode(
      id: doc.id,
      code: data['code'] ?? '',
      patientId: data['patientId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      assignedRole: CaregiverRole.fromString(data['assignedRole'] ?? 'caregiver'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'patientId': patientId,
      'createdBy': createdBy,
      'assignedRole': assignedRole.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
    };
  }
}

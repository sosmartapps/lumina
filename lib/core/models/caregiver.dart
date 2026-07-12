import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a caregiver who manages the app user
class Caregiver {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final List<String> managedUserIds;
  final CaregiverRole role;
  final Map<String, CaregiverRole> roleOverrides;

  /// Multi-role support (2026-07-08): a person can hold several roles for
  /// one patient (e.g. Family Member + Fiduciary). Stored in Firestore as
  /// multiRoleOverrides.{patientId}: [role, ...]. When absent, falls back
  /// to the legacy single roleOverrides/role.
  final Map<String, List<CaregiverRole>> multiRoleOverrides;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  Caregiver({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    this.managedUserIds = const [],
    this.role = CaregiverRole.caregiver,
    this.roleOverrides = const {},
    this.multiRoleOverrides = const {},
    this.isVerified = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastLoginAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Get effective role for a specific patient
  CaregiverRole roleForPatient(String patientId) {
    return roleOverrides[patientId] ?? role;
  }

  /// All roles this caregiver holds for a patient (multi-role aware).
  List<CaregiverRole> rolesForPatient(String patientId) {
    final multi = multiRoleOverrides[patientId];
    if (multi != null && multi.isNotEmpty) return multi;
    return [roleForPatient(patientId)];
  }

  factory Caregiver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse roleOverrides map
    final rawOverrides = data['roleOverrides'] as Map<String, dynamic>? ?? {};
    final overrides = rawOverrides.map(
      (key, value) => MapEntry(key, CaregiverRole.fromString(value as String)),
    );

    final rawMulti = data['multiRoleOverrides'] as Map<String, dynamic>? ?? {};
    final multiOverrides = rawMulti.map(
      (key, value) => MapEntry(
        key,
        (value as List)
            .map((v) => CaregiverRole.fromString(v as String))
            .toList(),
      ),
    );

    return Caregiver(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      managedUserIds: List<String>.from(data['managedUserIds'] ?? []),
      role: CaregiverRole.fromString(data['role'] ?? 'caregiver'),
      roleOverrides: overrides,
      multiRoleOverrides: multiOverrides,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'managedUserIds': managedUserIds,
      'role': role.value,
      'roleOverrides': roleOverrides.map((key, value) => MapEntry(key, value.value)),
      'multiRoleOverrides': multiRoleOverrides.map(
          (key, value) => MapEntry(key, value.map((r) => r.value).toList())),
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  Caregiver copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    List<String>? managedUserIds,
    CaregiverRole? role,
    Map<String, CaregiverRole>? roleOverrides,
    Map<String, List<CaregiverRole>>? multiRoleOverrides,
    bool? isVerified,
    DateTime? lastLoginAt,
  }) {
    return Caregiver(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      managedUserIds: managedUserIds ?? this.managedUserIds,
      role: role ?? this.role,
      roleOverrides: roleOverrides ?? this.roleOverrides,
      multiRoleOverrides: multiRoleOverrides ?? this.multiRoleOverrides,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

enum CaregiverRole {
  primaryCaregiver('primary_caregiver'),
  caregiver('caregiver'),
  familyMember('family_member'),
  healthcare('healthcare'),
  financeManager('finance_manager');

  final String value;
  const CaregiverRole(this.value);

  static CaregiverRole fromString(String value) {
    return CaregiverRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CaregiverRole.caregiver,
    );
  }

  String get displayName {
    switch (this) {
      case CaregiverRole.primaryCaregiver:
        return 'Primary Caregiver';
      case CaregiverRole.caregiver:
        return 'Caregiver';
      case CaregiverRole.familyMember:
        return 'Family Member';
      case CaregiverRole.healthcare:
        return 'Healthcare Provider';
      case CaregiverRole.financeManager:
        return 'Fiduciary (Financial)';
    }
  }
}

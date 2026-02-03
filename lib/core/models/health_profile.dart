import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a health condition or diagnosis
class HealthCondition {
  final String id;
  final String name;
  final String? description;
  final DateTime? diagnosisDate;
  final String? diagnosedBy; // Doctor/specialist name
  final String? severity; // mild, moderate, severe
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  HealthCondition({
    required this.id,
    required this.name,
    this.description,
    this.diagnosisDate,
    this.diagnosedBy,
    this.severity,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthCondition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthCondition(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      diagnosisDate: data['diagnosisDate'] != null
          ? (data['diagnosisDate'] as Timestamp).toDate()
          : null,
      diagnosedBy: data['diagnosedBy'],
      severity: data['severity'],
      notes: data['notes'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'diagnosisDate': diagnosisDate != null ? Timestamp.fromDate(diagnosisDate!) : null,
      'diagnosedBy': diagnosedBy,
      'severity': severity,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  HealthCondition copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? diagnosisDate,
    String? diagnosedBy,
    String? severity,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthCondition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      diagnosisDate: diagnosisDate ?? this.diagnosisDate,
      diagnosedBy: diagnosedBy ?? this.diagnosedBy,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an allergy
class Allergy {
  final String id;
  final String allergen;
  final String? reaction;
  final String severity; // mild, moderate, severe, life-threatening
  final DateTime? discoveredDate;
  final String? notes;
  final DateTime createdAt;

  Allergy({
    required this.id,
    required this.allergen,
    this.reaction,
    required this.severity,
    this.discoveredDate,
    this.notes,
    required this.createdAt,
  });

  factory Allergy.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Allergy(
      id: doc.id,
      allergen: data['allergen'] ?? '',
      reaction: data['reaction'],
      severity: data['severity'] ?? 'moderate',
      discoveredDate: data['discoveredDate'] != null
          ? (data['discoveredDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'allergen': allergen,
      'reaction': reaction,
      'severity': severity,
      'discoveredDate': discoveredDate != null ? Timestamp.fromDate(discoveredDate!) : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Represents a healthcare provider (doctor, specialist, etc.)
class HealthcareProvider {
  final String id;
  final String name;
  final String? specialty;
  final String? practice; // Hospital/clinic name
  final String? phone;
  final String? fax;
  final String? email;
  final String? address;
  final String? notes;
  final bool isPrimaryCare;
  final DateTime createdAt;

  HealthcareProvider({
    required this.id,
    required this.name,
    this.specialty,
    this.practice,
    this.phone,
    this.fax,
    this.email,
    this.address,
    this.notes,
    this.isPrimaryCare = false,
    required this.createdAt,
  });

  factory HealthcareProvider.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthcareProvider(
      id: doc.id,
      name: data['name'] ?? '',
      specialty: data['specialty'],
      practice: data['practice'],
      phone: data['phone'],
      fax: data['fax'],
      email: data['email'],
      address: data['address'],
      notes: data['notes'],
      isPrimaryCare: data['isPrimaryCare'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'specialty': specialty,
      'practice': practice,
      'phone': phone,
      'fax': fax,
      'email': email,
      'address': address,
      'notes': notes,
      'isPrimaryCare': isPrimaryCare,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Represents a pharmacy
class Pharmacy {
  final String id;
  final String name;
  final String? phone;
  final String? fax;
  final String? address;
  final String? hours;
  final bool isPrimary;
  final String? notes;
  final DateTime createdAt;

  Pharmacy({
    required this.id,
    required this.name,
    this.phone,
    this.fax,
    this.address,
    this.hours,
    this.isPrimary = false,
    this.notes,
    required this.createdAt,
  });

  factory Pharmacy.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Pharmacy(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'],
      fax: data['fax'],
      address: data['address'],
      hours: data['hours'],
      isPrimary: data['isPrimary'] ?? false,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'fax': fax,
      'address': address,
      'hours': hours,
      'isPrimary': isPrimary,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Comprehensive health profile for a user
class HealthProfile {
  final String id;
  final String userId;
  final String? bloodType;
  final double? height; // in cm
  final double? weight; // in kg
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final String? insuranceGroupNumber;
  final String? emergencyNotes; // Important info for ER
  final String? advanceDirectives; // Living will, DNR, etc.
  final DateTime? lastUpdated;

  HealthProfile({
    required this.id,
    required this.userId,
    this.bloodType,
    this.height,
    this.weight,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.insuranceGroupNumber,
    this.emergencyNotes,
    this.advanceDirectives,
    this.lastUpdated,
  });

  factory HealthProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthProfile(
      id: doc.id,
      userId: data['userId'] ?? '',
      bloodType: data['bloodType'],
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      insuranceProvider: data['insuranceProvider'],
      insurancePolicyNumber: data['insurancePolicyNumber'],
      insuranceGroupNumber: data['insuranceGroupNumber'],
      emergencyNotes: data['emergencyNotes'],
      advanceDirectives: data['advanceDirectives'],
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bloodType': bloodType,
      'height': height,
      'weight': weight,
      'insuranceProvider': insuranceProvider,
      'insurancePolicyNumber': insurancePolicyNumber,
      'insuranceGroupNumber': insuranceGroupNumber,
      'emergencyNotes': emergencyNotes,
      'advanceDirectives': advanceDirectives,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }

  HealthProfile copyWith({
    String? id,
    String? userId,
    String? bloodType,
    double? height,
    double? weight,
    String? insuranceProvider,
    String? insurancePolicyNumber,
    String? insuranceGroupNumber,
    String? emergencyNotes,
    String? advanceDirectives,
    DateTime? lastUpdated,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodType: bloodType ?? this.bloodType,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
      insuranceGroupNumber: insuranceGroupNumber ?? this.insuranceGroupNumber,
      emergencyNotes: emergencyNotes ?? this.emergencyNotes,
      advanceDirectives: advanceDirectives ?? this.advanceDirectives,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

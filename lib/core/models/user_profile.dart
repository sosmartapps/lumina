import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive user profile for identification and lost person reports
class UserProfile {
  final String id;
  final String userId;

  // Basic Identity
  final String? legalFirstName;
  final String? legalMiddleName;
  final String? legalLastName;
  final String? preferredName; // What they respond to
  final String? nickname;
  final DateTime? dateOfBirth;
  final String? gender;

  // Physical Description
  final double? heightCm;
  final double? weightKg;
  final String? hairColor;
  final String? eyeColor;
  final String? race;
  final String? skinTone;
  final String? buildType; // slim, average, heavy, etc.
  final String? distinguishingMarks; // scars, tattoos, birthmarks
  final String? usualClothing; // What they typically wear
  final String? glasses; // none, reading, always wears, etc.
  final String? mobilityAids; // walker, cane, wheelchair, etc.

  // Address & Location
  final String? streetAddress;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;

  // Identification Documents
  final String? driversLicenseNumber;
  final String? driversLicenseState;
  final DateTime? driversLicenseExpiration;
  final String? ssnLast4; // Only last 4 digits for safety
  final String? passportNumber;
  final String? medicareNumber;
  final String? medicaidNumber;

  // Medical Alert Info (for lost person reports)
  final String? primaryDiagnosis;
  final String? cognitiveStatus; // e.g., "May not know name, non-verbal"
  final String? wanderingHistory; // e.g., "Has wandered 3 times in past year"
  final String? communicationAbility; // e.g., "Can state first name only"
  final String? behaviorWhenLost; // e.g., "May appear confused, will follow strangers"
  final String? medicalAlertInfo; // Critical medical info for first responders

  // Photos
  final List<UserPhoto> photos;

  // Frequently Visited Places (for search)
  final List<FrequentPlace> frequentPlaces;

  // Emergency Behavior
  final String? responseToName; // Does/doesn't respond to name
  final String? responseToStrangers; // Fearful, friendly, etc.
  final String? calmingTechniques; // What helps calm them
  final String? triggersToAvoid; // What upsets them

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    this.legalFirstName,
    this.legalMiddleName,
    this.legalLastName,
    this.preferredName,
    this.nickname,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.hairColor,
    this.eyeColor,
    this.race,
    this.skinTone,
    this.buildType,
    this.distinguishingMarks,
    this.usualClothing,
    this.glasses,
    this.mobilityAids,
    this.streetAddress,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.driversLicenseNumber,
    this.driversLicenseState,
    this.driversLicenseExpiration,
    this.ssnLast4,
    this.passportNumber,
    this.medicareNumber,
    this.medicaidNumber,
    this.primaryDiagnosis,
    this.cognitiveStatus,
    this.wanderingHistory,
    this.communicationAbility,
    this.behaviorWhenLost,
    this.medicalAlertInfo,
    this.photos = const [],
    this.frequentPlaces = const [],
    this.responseToName,
    this.responseToStrangers,
    this.calmingTechniques,
    this.triggersToAvoid,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get full legal name
  String get fullLegalName {
    final parts = [legalFirstName, legalMiddleName, legalLastName]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  /// Calculate age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  /// Get height in feet and inches
  String? get heightImperial {
    if (heightCm == null) return null;
    final totalInches = heightCm! / 2.54;
    final feet = (totalInches / 12).floor();
    final inches = (totalInches % 12).round();
    return "$feet'$inches\"";
  }

  /// Get weight in pounds
  double? get weightLbs {
    if (weightKg == null) return null;
    return weightKg! * 2.205;
  }

  /// Get full address
  String get fullAddress {
    final parts = [streetAddress, city, state, zipCode, country]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  /// Get most recent photo
  UserPhoto? get mostRecentPhoto {
    if (photos.isEmpty) return null;
    final sorted = List<UserPhoto>.from(photos)
      ..sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
    return sorted.first;
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      userId: data['userId'] ?? '',
      legalFirstName: data['legalFirstName'],
      legalMiddleName: data['legalMiddleName'],
      legalLastName: data['legalLastName'],
      preferredName: data['preferredName'],
      nickname: data['nickname'],
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      gender: data['gender'],
      heightCm: data['heightCm']?.toDouble(),
      weightKg: data['weightKg']?.toDouble(),
      hairColor: data['hairColor'],
      eyeColor: data['eyeColor'],
      race: data['race'],
      skinTone: data['skinTone'],
      buildType: data['buildType'],
      distinguishingMarks: data['distinguishingMarks'],
      usualClothing: data['usualClothing'],
      glasses: data['glasses'],
      mobilityAids: data['mobilityAids'],
      streetAddress: data['streetAddress'],
      city: data['city'],
      state: data['state'],
      zipCode: data['zipCode'],
      country: data['country'],
      driversLicenseNumber: data['driversLicenseNumber'],
      driversLicenseState: data['driversLicenseState'],
      driversLicenseExpiration: data['driversLicenseExpiration'] != null
          ? (data['driversLicenseExpiration'] as Timestamp).toDate()
          : null,
      ssnLast4: data['ssnLast4'],
      passportNumber: data['passportNumber'],
      medicareNumber: data['medicareNumber'],
      medicaidNumber: data['medicaidNumber'],
      primaryDiagnosis: data['primaryDiagnosis'],
      cognitiveStatus: data['cognitiveStatus'],
      wanderingHistory: data['wanderingHistory'],
      communicationAbility: data['communicationAbility'],
      behaviorWhenLost: data['behaviorWhenLost'],
      medicalAlertInfo: data['medicalAlertInfo'],
      photos: (data['photos'] as List<dynamic>?)
              ?.map((p) => UserPhoto.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      frequentPlaces: (data['frequentPlaces'] as List<dynamic>?)
              ?.map((p) => FrequentPlace.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      responseToName: data['responseToName'],
      responseToStrangers: data['responseToStrangers'],
      calmingTechniques: data['calmingTechniques'],
      triggersToAvoid: data['triggersToAvoid'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'legalFirstName': legalFirstName,
      'legalMiddleName': legalMiddleName,
      'legalLastName': legalLastName,
      'preferredName': preferredName,
      'nickname': nickname,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'hairColor': hairColor,
      'eyeColor': eyeColor,
      'race': race,
      'skinTone': skinTone,
      'buildType': buildType,
      'distinguishingMarks': distinguishingMarks,
      'usualClothing': usualClothing,
      'glasses': glasses,
      'mobilityAids': mobilityAids,
      'streetAddress': streetAddress,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'driversLicenseNumber': driversLicenseNumber,
      'driversLicenseState': driversLicenseState,
      'driversLicenseExpiration': driversLicenseExpiration != null
          ? Timestamp.fromDate(driversLicenseExpiration!)
          : null,
      'ssnLast4': ssnLast4,
      'passportNumber': passportNumber,
      'medicareNumber': medicareNumber,
      'medicaidNumber': medicaidNumber,
      'primaryDiagnosis': primaryDiagnosis,
      'cognitiveStatus': cognitiveStatus,
      'wanderingHistory': wanderingHistory,
      'communicationAbility': communicationAbility,
      'behaviorWhenLost': behaviorWhenLost,
      'medicalAlertInfo': medicalAlertInfo,
      'photos': photos.map((p) => p.toMap()).toList(),
      'frequentPlaces': frequentPlaces.map((p) => p.toMap()).toList(),
      'responseToName': responseToName,
      'responseToStrangers': responseToStrangers,
      'calmingTechniques': calmingTechniques,
      'triggersToAvoid': triggersToAvoid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    String? legalFirstName,
    String? legalMiddleName,
    String? legalLastName,
    String? preferredName,
    String? nickname,
    DateTime? dateOfBirth,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? hairColor,
    String? eyeColor,
    String? race,
    String? skinTone,
    String? buildType,
    String? distinguishingMarks,
    String? usualClothing,
    String? glasses,
    String? mobilityAids,
    String? streetAddress,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? driversLicenseNumber,
    String? driversLicenseState,
    DateTime? driversLicenseExpiration,
    String? ssnLast4,
    String? passportNumber,
    String? medicareNumber,
    String? medicaidNumber,
    String? primaryDiagnosis,
    String? cognitiveStatus,
    String? wanderingHistory,
    String? communicationAbility,
    String? behaviorWhenLost,
    String? medicalAlertInfo,
    List<UserPhoto>? photos,
    List<FrequentPlace>? frequentPlaces,
    String? responseToName,
    String? responseToStrangers,
    String? calmingTechniques,
    String? triggersToAvoid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      legalFirstName: legalFirstName ?? this.legalFirstName,
      legalMiddleName: legalMiddleName ?? this.legalMiddleName,
      legalLastName: legalLastName ?? this.legalLastName,
      preferredName: preferredName ?? this.preferredName,
      nickname: nickname ?? this.nickname,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      race: race ?? this.race,
      skinTone: skinTone ?? this.skinTone,
      buildType: buildType ?? this.buildType,
      distinguishingMarks: distinguishingMarks ?? this.distinguishingMarks,
      usualClothing: usualClothing ?? this.usualClothing,
      glasses: glasses ?? this.glasses,
      mobilityAids: mobilityAids ?? this.mobilityAids,
      streetAddress: streetAddress ?? this.streetAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      driversLicenseNumber: driversLicenseNumber ?? this.driversLicenseNumber,
      driversLicenseState: driversLicenseState ?? this.driversLicenseState,
      driversLicenseExpiration:
          driversLicenseExpiration ?? this.driversLicenseExpiration,
      ssnLast4: ssnLast4 ?? this.ssnLast4,
      passportNumber: passportNumber ?? this.passportNumber,
      medicareNumber: medicareNumber ?? this.medicareNumber,
      medicaidNumber: medicaidNumber ?? this.medicaidNumber,
      primaryDiagnosis: primaryDiagnosis ?? this.primaryDiagnosis,
      cognitiveStatus: cognitiveStatus ?? this.cognitiveStatus,
      wanderingHistory: wanderingHistory ?? this.wanderingHistory,
      communicationAbility: communicationAbility ?? this.communicationAbility,
      behaviorWhenLost: behaviorWhenLost ?? this.behaviorWhenLost,
      medicalAlertInfo: medicalAlertInfo ?? this.medicalAlertInfo,
      photos: photos ?? this.photos,
      frequentPlaces: frequentPlaces ?? this.frequentPlaces,
      responseToName: responseToName ?? this.responseToName,
      responseToStrangers: responseToStrangers ?? this.responseToStrangers,
      calmingTechniques: calmingTechniques ?? this.calmingTechniques,
      triggersToAvoid: triggersToAvoid ?? this.triggersToAvoid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A photo of the user for identification
class UserPhoto {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final DateTime dateTaken;
  final String? description; // e.g., "Full face, no glasses"
  final String? photoType; // face, full_body, profile
  final bool isPrimary;

  UserPhoto({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.dateTaken,
    this.description,
    this.photoType,
    this.isPrimary = false,
  });

  factory UserPhoto.fromMap(Map<String, dynamic> map) {
    return UserPhoto(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      dateTaken: map['dateTaken'] != null
          ? (map['dateTaken'] as Timestamp).toDate()
          : DateTime.now(),
      description: map['description'],
      photoType: map['photoType'],
      isPrimary: map['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'dateTaken': Timestamp.fromDate(dateTaken),
      'description': description,
      'photoType': photoType,
      'isPrimary': isPrimary,
    };
  }
}

/// A place the user frequently visits (useful for search)
class FrequentPlace {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? notes; // e.g., "Often found in back garden area"

  FrequentPlace({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.notes,
  });

  factory FrequentPlace.fromMap(Map<String, dynamic> map) {
    return FrequentPlace(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      address: map['address'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
    };
  }
}

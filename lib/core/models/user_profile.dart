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

  // Vehicle Information
  final String? vehicleMake;       // e.g., "Toyota"
  final String? vehicleModel;      // e.g., "Camry"
  final int? vehicleYear;          // e.g., 2020
  final String? vehicleColor;      // e.g., "Silver"
  final String? vehicleLicensePlate; // e.g., "ABC1234"
  final String? vehicleLicenseState; // e.g., "AZ"
  final String? vehicleVin;        // VIN number
  final String? vehicleNotes;      // e.g., "Has dent on rear bumper, Lumina sticker on rear window"

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

  // Vehicles (for missing-person flyers — supports multiple vehicles, each
  // with its own photos). The legacy single-vehicle fields above are kept
  // for backward compatibility and are surfaced as the first vehicle when
  // no structured vehicles exist.
  final List<Vehicle> vehicles;

  // Social media accounts (caregivers can quickly pull recent photos for
  // missing-person flyers; the public can reference the handles).
  final List<SocialMediaLink> socialMediaLinks;

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
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehicleLicensePlate,
    this.vehicleLicenseState,
    this.vehicleVin,
    this.vehicleNotes,
    this.primaryDiagnosis,
    this.cognitiveStatus,
    this.wanderingHistory,
    this.communicationAbility,
    this.behaviorWhenLost,
    this.medicalAlertInfo,
    this.photos = const [],
    this.frequentPlaces = const [],
    this.vehicles = const [],
    this.socialMediaLinks = const [],
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

  /// All vehicles, folding the legacy single-vehicle fields into the list
  /// when no structured vehicles have been added yet. Used by flyer/report
  /// generation so older profiles still show their vehicle.
  List<Vehicle> get allVehicles {
    if (vehicles.isNotEmpty) return vehicles;
    final hasLegacy = [
      vehicleMake,
      vehicleModel,
      vehicleColor,
      vehicleLicensePlate,
      vehicleVin,
      vehicleNotes,
    ].any((v) => v != null && v.isNotEmpty) ||
        vehicleYear != null;
    if (!hasLegacy) return const [];
    return [
      Vehicle(
        id: 'legacy',
        make: vehicleMake,
        model: vehicleModel,
        year: vehicleYear,
        color: vehicleColor,
        licensePlate: vehicleLicensePlate,
        licenseState: vehicleLicenseState,
        vin: vehicleVin,
        notes: vehicleNotes,
      ),
    ];
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
      vehicleMake: data['vehicleMake'],
      vehicleModel: data['vehicleModel'],
      vehicleYear: data['vehicleYear'],
      vehicleColor: data['vehicleColor'],
      vehicleLicensePlate: data['vehicleLicensePlate'],
      vehicleLicenseState: data['vehicleLicenseState'],
      vehicleVin: data['vehicleVin'],
      vehicleNotes: data['vehicleNotes'],
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
      vehicles: (data['vehicles'] as List<dynamic>?)
              ?.map((v) => Vehicle.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      socialMediaLinks: (data['socialMediaLinks'] as List<dynamic>?)
              ?.map((s) => SocialMediaLink.fromMap(s as Map<String, dynamic>))
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
      'vehicleMake': vehicleMake,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'vehicleColor': vehicleColor,
      'vehicleLicensePlate': vehicleLicensePlate,
      'vehicleLicenseState': vehicleLicenseState,
      'vehicleVin': vehicleVin,
      'vehicleNotes': vehicleNotes,
      'primaryDiagnosis': primaryDiagnosis,
      'cognitiveStatus': cognitiveStatus,
      'wanderingHistory': wanderingHistory,
      'communicationAbility': communicationAbility,
      'behaviorWhenLost': behaviorWhenLost,
      'medicalAlertInfo': medicalAlertInfo,
      'photos': photos.map((p) => p.toMap()).toList(),
      'frequentPlaces': frequentPlaces.map((p) => p.toMap()).toList(),
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'socialMediaLinks': socialMediaLinks.map((s) => s.toMap()).toList(),
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
    String? vehicleMake,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? vehicleLicensePlate,
    String? vehicleLicenseState,
    String? vehicleVin,
    String? vehicleNotes,
    String? primaryDiagnosis,
    String? cognitiveStatus,
    String? wanderingHistory,
    String? communicationAbility,
    String? behaviorWhenLost,
    String? medicalAlertInfo,
    List<UserPhoto>? photos,
    List<FrequentPlace>? frequentPlaces,
    List<Vehicle>? vehicles,
    List<SocialMediaLink>? socialMediaLinks,
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
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleLicensePlate: vehicleLicensePlate ?? this.vehicleLicensePlate,
      vehicleLicenseState: vehicleLicenseState ?? this.vehicleLicenseState,
      vehicleVin: vehicleVin ?? this.vehicleVin,
      vehicleNotes: vehicleNotes ?? this.vehicleNotes,
      primaryDiagnosis: primaryDiagnosis ?? this.primaryDiagnosis,
      cognitiveStatus: cognitiveStatus ?? this.cognitiveStatus,
      wanderingHistory: wanderingHistory ?? this.wanderingHistory,
      communicationAbility: communicationAbility ?? this.communicationAbility,
      behaviorWhenLost: behaviorWhenLost ?? this.behaviorWhenLost,
      medicalAlertInfo: medicalAlertInfo ?? this.medicalAlertInfo,
      photos: photos ?? this.photos,
      frequentPlaces: frequentPlaces ?? this.frequentPlaces,
      vehicles: vehicles ?? this.vehicles,
      socialMediaLinks: socialMediaLinks ?? this.socialMediaLinks,
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

/// A vehicle associated with the user, used for identification and
/// missing-person flyers. Supports multiple photos per vehicle.
class Vehicle {
  final String id;
  final String? make; // e.g., "Toyota"
  final String? model; // e.g., "Camry"
  final int? year; // e.g., 2020
  final String? color; // e.g., "Silver"
  final String? licensePlate; // e.g., "ABC1234"
  final String? licenseState; // e.g., "AZ"
  final String? vin; // optional VIN number
  final String? notes; // e.g., "Dent on rear bumper"
  final List<String> photoUrls; // Firebase Storage download URLs

  Vehicle({
    required this.id,
    this.make,
    this.model,
    this.year,
    this.color,
    this.licensePlate,
    this.licenseState,
    this.vin,
    this.notes,
    this.photoUrls = const [],
  });

  /// Human-readable one-line description, e.g. "2020 Silver Toyota Camry".
  String get displayName {
    final parts = [
      if (year != null) year.toString(),
      if (color != null && color!.isNotEmpty) color,
      if (make != null && make!.isNotEmpty) make,
      if (model != null && model!.isNotEmpty) model,
    ];
    final name = parts.join(' ').trim();
    return name.isEmpty ? 'Vehicle' : name;
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] ?? '',
      make: map['make'],
      model: map['model'],
      year: map['year'] is int
          ? map['year'] as int
          : (map['year'] != null
              ? int.tryParse(map['year'].toString())
              : null),
      color: map['color'],
      licensePlate: map['licensePlate'],
      licenseState: map['licenseState'],
      vin: map['vin'],
      notes: map['notes'],
      photoUrls: (map['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'licensePlate': licensePlate,
      'licenseState': licenseState,
      'vin': vin,
      'notes': notes,
      'photoUrls': photoUrls,
    };
  }

  Vehicle copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? color,
    String? licensePlate,
    String? licenseState,
    String? vin,
    String? notes,
    List<String>? photoUrls,
  }) {
    return Vehicle(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      licensePlate: licensePlate ?? this.licensePlate,
      licenseState: licenseState ?? this.licenseState,
      vin: vin ?? this.vin,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }
}

/// Known social-media platforms a caregiver can link for a patient.
enum SocialPlatform { facebook, instagram, twitter, tiktok, other }

extension SocialPlatformInfo on SocialPlatform {
  /// Stable key stored in Firestore.
  String get key => name;

  /// Label shown in the UI.
  String get label {
    switch (this) {
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.twitter:
        return 'Twitter / X';
      case SocialPlatform.tiktok:
        return 'TikTok';
      case SocialPlatform.other:
        return 'Other';
    }
  }

  static SocialPlatform fromKey(String? key) {
    return SocialPlatform.values.firstWhere(
      (p) => p.name == key,
      orElse: () => SocialPlatform.other,
    );
  }
}

/// A social-media account link for the user. `url` is a full, tappable URL;
/// `handle` is an optional display handle (e.g. "@janedoe").
class SocialMediaLink {
  final String platform; // one of SocialPlatform.key
  final String url;
  final String? handle;

  SocialMediaLink({
    required this.platform,
    required this.url,
    this.handle,
  });

  SocialPlatform get platformEnum => SocialPlatformInfo.fromKey(platform);

  factory SocialMediaLink.fromMap(Map<String, dynamic> map) {
    return SocialMediaLink(
      platform: map['platform'] ?? SocialPlatform.other.key,
      url: map['url'] ?? '',
      handle: map['handle'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'url': url,
      'handle': handle,
    };
  }

  SocialMediaLink copyWith({
    String? platform,
    String? url,
    String? handle,
  }) {
    return SocialMediaLink(
      platform: platform ?? this.platform,
      url: url ?? this.url,
      handle: handle ?? this.handle,
    );
  }
}

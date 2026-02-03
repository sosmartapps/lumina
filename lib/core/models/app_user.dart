import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the main user (person with Alzheimer's/developmental issues)
class AppUser {
  final String id;
  final String name;
  final String? photoUrl;
  final String? phoneNumber;
  final List<String> caregiverIds;
  final String? primaryCaregiverId;
  final GeoPoint? homeLocation;
  final String? homeAddress;
  final List<SavedLocation> savedLocations;
  final List<EmergencyContact> emergencyContacts;
  final UserSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.name,
    this.photoUrl,
    this.phoneNumber,
    this.caregiverIds = const [],
    this.primaryCaregiverId,
    this.homeLocation,
    this.homeAddress,
    this.savedLocations = const [],
    this.emergencyContacts = const [],
    UserSettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : settings = settings ?? UserSettings(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      caregiverIds: List<String>.from(data['caregiverIds'] ?? []),
      primaryCaregiverId: data['primaryCaregiverId'],
      homeLocation: data['homeLocation'],
      homeAddress: data['homeAddress'],
      savedLocations: (data['savedLocations'] as List<dynamic>?)
              ?.map((e) => SavedLocation.fromMap(e))
              .toList() ??
          [],
      emergencyContacts: (data['emergencyContacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromMap(e))
              .toList() ??
          [],
      settings: UserSettings.fromMap(data['settings'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'caregiverIds': caregiverIds,
      'primaryCaregiverId': primaryCaregiverId,
      'homeLocation': homeLocation,
      'homeAddress': homeAddress,
      'savedLocations': savedLocations.map((e) => e.toMap()).toList(),
      'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
      'settings': settings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  AppUser copyWith({
    String? name,
    String? photoUrl,
    String? phoneNumber,
    List<String>? caregiverIds,
    String? primaryCaregiverId,
    GeoPoint? homeLocation,
    String? homeAddress,
    List<SavedLocation>? savedLocations,
    List<EmergencyContact>? emergencyContacts,
    UserSettings? settings,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      caregiverIds: caregiverIds ?? this.caregiverIds,
      primaryCaregiverId: primaryCaregiverId ?? this.primaryCaregiverId,
      homeLocation: homeLocation ?? this.homeLocation,
      homeAddress: homeAddress ?? this.homeAddress,
      savedLocations: savedLocations ?? this.savedLocations,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      settings: settings ?? this.settings,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// A saved/favorite location for quick navigation
class SavedLocation {
  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final String? iconName;
  final String? color;
  final int orderIndex;

  SavedLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.iconName,
    this.color,
    this.orderIndex = 0,
  });

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      location: map['location'] ?? const GeoPoint(0, 0),
      iconName: map['iconName'],
      color: map['color'],
      orderIndex: map['orderIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'location': location,
      'iconName': iconName,
      'color': color,
      'orderIndex': orderIndex,
    };
  }
}

/// Emergency contact for quick calling
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final String? photoUrl;
  final String? color;
  final int orderIndex;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.photoUrl,
    this.color,
    this.orderIndex = 0,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      relationship: map['relationship'],
      photoUrl: map['photoUrl'],
      color: map['color'],
      orderIndex: map['orderIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'photoUrl': photoUrl,
      'color': color,
      'orderIndex': orderIndex,
    };
  }
}

/// User-specific settings
class UserSettings {
  final bool highContrastMode;
  final double textScale;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool voicePromptsEnabled;
  final int reminderVolume; // 0-100
  final String voiceLanguage;

  UserSettings({
    this.highContrastMode = false,
    this.textScale = 1.2,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.voicePromptsEnabled = true,
    this.reminderVolume = 80,
    this.voiceLanguage = 'en-US',
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      highContrastMode: map['highContrastMode'] ?? false,
      textScale: (map['textScale'] ?? 1.2).toDouble(),
      soundEnabled: map['soundEnabled'] ?? true,
      vibrationEnabled: map['vibrationEnabled'] ?? true,
      voicePromptsEnabled: map['voicePromptsEnabled'] ?? true,
      reminderVolume: map['reminderVolume'] ?? 80,
      voiceLanguage: map['voiceLanguage'] ?? 'en-US',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'highContrastMode': highContrastMode,
      'textScale': textScale,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'voicePromptsEnabled': voicePromptsEnabled,
      'reminderVolume': reminderVolume,
      'voiceLanguage': voiceLanguage,
    };
  }

  UserSettings copyWith({
    bool? highContrastMode,
    double? textScale,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? voicePromptsEnabled,
    int? reminderVolume,
    String? voiceLanguage,
  }) {
    return UserSettings(
      highContrastMode: highContrastMode ?? this.highContrastMode,
      textScale: textScale ?? this.textScale,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      voicePromptsEnabled: voicePromptsEnabled ?? this.voicePromptsEnabled,
      reminderVolume: reminderVolume ?? this.reminderVolume,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
    );
  }
}

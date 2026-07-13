
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';
import '../models/health_profile.dart';
import '../models/prescription.dart';
import 'medical_info_service.dart';

/// Service for managing user profiles and generating lost person reports
class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============================================================================
  // USER PROFILE CRUD
  // ============================================================================

  /// Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_profile')
          .doc('profile')
          .get();

      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Save or update user profile
  static Future<bool> saveUserProfile(String userId, UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_profile')
          .doc('profile')
          .set(profile.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      return false;
    }
  }

  // ============================================================================
  // PHOTO MANAGEMENT
  // ============================================================================

  /// Upload a new photo
  static Future<UserPhoto?> uploadPhoto(
    String userId,
    Uint8List imageBytes, {
    String? description,
    String? photoType,
    bool isPrimary = false,
  }) async {
    try {
      final photoId = const Uuid().v4();
      final filename = 'photo_$photoId.jpg';
      final ref = _storage
          .ref()
          .child('user_photos')
          .child(userId)
          .child(filename);

      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      final photo = UserPhoto(
        id: photoId,
        url: url,
        dateTaken: DateTime.now(),
        description: description,
        photoType: photoType,
        isPrimary: isPrimary,
      );

      // Add photo to profile
      final profile = await getUserProfile(userId);
      if (profile != null) {
        List<UserPhoto> updatedPhotos = List.from(profile.photos);

        // If this is primary, unset other primaries
        if (isPrimary) {
          updatedPhotos = updatedPhotos
              .map((p) => UserPhoto(
                    id: p.id,
                    url: p.url,
                    thumbnailUrl: p.thumbnailUrl,
                    dateTaken: p.dateTaken,
                    description: p.description,
                    photoType: p.photoType,
                    isPrimary: false,
                  ))
              .toList();
        }

        updatedPhotos.add(photo);

        await saveUserProfile(
          userId,
          profile.copyWith(
            photos: updatedPhotos,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        // Create new profile with just this photo
        await saveUserProfile(
          userId,
          UserProfile(
            id: 'profile',
            userId: userId,
            photos: [photo],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      return photo;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  /// Delete a photo
  static Future<bool> deletePhoto(String userId, String photoId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) return false;

      // Find the photo
      final photo = profile.photos.firstWhere(
        (p) => p.id == photoId,
        orElse: () => throw Exception('Photo not found'),
      );

      // Delete from storage
      try {
        final ref = _storage.refFromURL(photo.url);
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting photo from storage: $e');
      }

      // Remove from profile
      final updatedPhotos =
          profile.photos.where((p) => p.id != photoId).toList();
      await saveUserProfile(
        userId,
        profile.copyWith(
          photos: updatedPhotos,
          updatedAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  /// Set a photo as primary
  static Future<bool> setPrimaryPhoto(String userId, String photoId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) return false;

      final updatedPhotos = profile.photos.map((p) {
        return UserPhoto(
          id: p.id,
          url: p.url,
          thumbnailUrl: p.thumbnailUrl,
          dateTaken: p.dateTaken,
          description: p.description,
          photoType: p.photoType,
          isPrimary: p.id == photoId,
        );
      }).toList();

      await saveUserProfile(
        userId,
        profile.copyWith(
          photos: updatedPhotos,
          updatedAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Error setting primary photo: $e');
      return false;
    }
  }

  // ============================================================================
  // VEHICLE PHOTO MANAGEMENT
  // ============================================================================

  /// Upload a vehicle photo to Storage and return its download URL. The
  /// caller is responsible for attaching the URL to the relevant [Vehicle]
  /// and persisting the profile. Stored under
  /// `vehicle_photos/{userId}/photo_{uuid}.jpg`.
  static Future<String?> uploadVehiclePhoto(
    String userId,
    Uint8List imageBytes,
  ) async {
    try {
      final photoId = const Uuid().v4();
      final filename = 'photo_$photoId.jpg';
      final ref = _storage
          .ref()
          .child('vehicle_photos')
          .child(userId)
          .child(filename);

      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading vehicle photo: $e');
      return null;
    }
  }

  /// Delete a vehicle photo from Storage by its download URL. Failures are
  /// swallowed (the URL may already be gone); the caller still removes it
  /// from the profile.
  static Future<void> deleteVehiclePhoto(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Error deleting vehicle photo from storage: $e');
    }
  }

  // ============================================================================
  // LOST PERSON REPORT GENERATION
  // ============================================================================

  /// Generate a comprehensive lost person report
  static Future<LostPersonReport> generateLostPersonReport(String userId) async {
    // Get user profile
    final profile = await getUserProfile(userId);

    // Get basic user info
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    // Get health profile
    final healthProfile = await MedicalInfoService.getHealthProfile(userId);

    // Get allergies
    final allergiesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('allergies')
        .get();
    final allergies = allergiesSnapshot.docs
        .map((doc) => Allergy.fromFirestore(doc))
        .toList();

    // Get active medications
    final medicationsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('prescriptions')
        .where('status', isEqualTo: PrescriptionStatus.active.name)
        .get();
    final medications = medicationsSnapshot.docs
        .map((doc) => Prescription.fromFirestore(doc))
        .toList();

    // Get emergency contacts
    final emergencyContacts = (userData['emergencyContacts'] as List<dynamic>?)
            ?.map((c) => c as Map<String, dynamic>)
            .toList() ??
        [];

    return LostPersonReport(
      generatedAt: DateTime.now(),
      profile: profile,
      userName: userData['name'] ?? profile?.preferredName ?? 'Unknown',
      healthProfile: healthProfile,
      allergies: allergies,
      medications: medications,
      emergencyContacts: emergencyContacts,
    );
  }

  /// Format lost person report as shareable text
  static String formatLostPersonReportAsText(LostPersonReport report) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final profile = report.profile;

    buffer.writeln('╔══════════════════════════════════════════════════════════╗');
    buffer.writeln('║              ⚠️  MISSING PERSON REPORT  ⚠️              ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════╝');
    buffer.writeln();
    buffer.writeln('Report Generated: ${dateFormat.format(report.generatedAt)} at ${timeFormat.format(report.generatedAt)}');
    buffer.writeln();

    // IDENTIFICATION
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  IDENTIFICATION');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (profile != null) {
      if (profile.fullLegalName.isNotEmpty) {
        buffer.writeln('Legal Name: ${profile.fullLegalName}');
      }
      if (profile.preferredName != null) {
        buffer.writeln('Goes By: ${profile.preferredName}');
      }
      if (profile.nickname != null) {
        buffer.writeln('Also Responds To: ${profile.nickname}');
      }
      if (profile.age != null && profile.dateOfBirth != null) {
        buffer.writeln('Age: ${profile.age} (DOB: ${dateFormat.format(profile.dateOfBirth!)})');
      }
      if (profile.gender != null) {
        buffer.writeln('Gender: ${profile.gender}');
      }
    } else {
      buffer.writeln('Name: ${report.userName}');
    }

    buffer.writeln();

    // PHYSICAL DESCRIPTION
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  PHYSICAL DESCRIPTION');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (profile != null) {
      if (profile.race != null) buffer.writeln('Race: ${profile.race}');
      if (profile.gender != null) buffer.writeln('Gender: ${profile.gender}');
      if (profile.heightImperial != null || profile.heightCm != null) {
        final height = profile.heightImperial ?? '${profile.heightCm} cm';
        buffer.writeln('Height: $height');
      }
      if (profile.weightLbs != null || profile.weightKg != null) {
        final weight = profile.weightLbs != null
            ? '${profile.weightLbs!.round()} lbs'
            : '${profile.weightKg} kg';
        buffer.writeln('Weight: $weight');
      }
      if (profile.buildType != null) buffer.writeln('Build: ${profile.buildType}');
      if (profile.hairColor != null) buffer.writeln('Hair: ${profile.hairColor}');
      if (profile.eyeColor != null) buffer.writeln('Eyes: ${profile.eyeColor}');
      if (profile.skinTone != null) buffer.writeln('Skin Tone: ${profile.skinTone}');
      if (profile.glasses != null) buffer.writeln('Glasses: ${profile.glasses}');
      if (profile.mobilityAids != null) {
        buffer.writeln('Mobility Aids: ${profile.mobilityAids}');
      }
      if (profile.distinguishingMarks != null) {
        buffer.writeln('Distinguishing Marks: ${profile.distinguishingMarks}');
      }
      if (profile.usualClothing != null) {
        buffer.writeln('Usually Wears: ${profile.usualClothing}');
      }
    } else {
      buffer.writeln('(No physical description on file)');
    }

    buffer.writeln();

    // MEDICAL ALERT - CRITICAL INFO
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  ⚠️  MEDICAL ALERT - CRITICAL INFO');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (profile?.primaryDiagnosis != null) {
      buffer.writeln('Primary Diagnosis: ${profile!.primaryDiagnosis}');
    }
    if (profile?.cognitiveStatus != null) {
      buffer.writeln('Cognitive Status: ${profile!.cognitiveStatus}');
    }
    if (profile?.communicationAbility != null) {
      buffer.writeln('Communication: ${profile!.communicationAbility}');
    }
    if (profile?.medicalAlertInfo != null) {
      buffer.writeln('Medical Alert: ${profile!.medicalAlertInfo}');
    }

    // Allergies
    if (report.allergies.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('⚠️ ALLERGIES:');
      for (final allergy in report.allergies) {
        buffer.writeln('  • ${allergy.allergen} (${allergy.severity})');
        if (allergy.reaction != null) {
          buffer.writeln('    Reaction: ${allergy.reaction}');
        }
      }
    }

    // Medications
    if (report.medications.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💊 CURRENT MEDICATIONS:');
      for (final med in report.medications) {
        buffer.writeln('  • ${med.medicationName} ${med.dosage} - ${med.frequency}');
      }
    }

    buffer.writeln();

    // BEHAVIOR WHEN LOST
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  BEHAVIOR WHEN LOST');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (profile != null) {
      if (profile.responseToName != null) {
        buffer.writeln('Response to Name: ${profile.responseToName}');
      }
      if (profile.responseToStrangers != null) {
        buffer.writeln('Response to Strangers: ${profile.responseToStrangers}');
      }
      if (profile.behaviorWhenLost != null) {
        buffer.writeln('When Lost: ${profile.behaviorWhenLost}');
      }
      if (profile.wanderingHistory != null) {
        buffer.writeln('Wandering History: ${profile.wanderingHistory}');
      }
      if (profile.calmingTechniques != null) {
        buffer.writeln('How to Calm: ${profile.calmingTechniques}');
      }
      if (profile.triggersToAvoid != null) {
        buffer.writeln('Triggers to Avoid: ${profile.triggersToAvoid}');
      }
    } else {
      buffer.writeln('(No behavior information on file)');
    }

    buffer.writeln();

    // ADDRESS & PLACES TO CHECK
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  ADDRESS & PLACES TO CHECK');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (profile?.fullAddress.isNotEmpty == true) {
      buffer.writeln('Home Address: ${profile!.fullAddress}');
    }

    if (profile?.frequentPlaces.isNotEmpty == true) {
      buffer.writeln();
      buffer.writeln('Known Frequent Locations:');
      for (final place in profile!.frequentPlaces) {
        buffer.writeln('  • ${place.name}');
        if (place.address != null) buffer.writeln('    ${place.address}');
        if (place.notes != null) buffer.writeln('    Note: ${place.notes}');
      }
    }

    buffer.writeln();

    // VEHICLE(S)
    final vehicles = profile?.allVehicles ?? const [];
    if (vehicles.isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('  VEHICLE(S)');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      for (final v in vehicles) {
        buffer.writeln('• ${v.displayName}');
        if (v.licensePlate != null && v.licensePlate!.isNotEmpty) {
          final plate = v.licenseState != null && v.licenseState!.isNotEmpty
              ? '${v.licensePlate} (${v.licenseState})'
              : v.licensePlate;
          buffer.writeln('    Plate: $plate');
        }
        if (v.vin != null && v.vin!.isNotEmpty) {
          buffer.writeln('    VIN: ${v.vin}');
        }
        if (v.notes != null && v.notes!.isNotEmpty) {
          buffer.writeln('    Note: ${v.notes}');
        }
        if (v.photoUrls.isNotEmpty) {
          buffer.writeln('    Photo: ${v.photoUrls.first}');
        }
      }
      buffer.writeln();
    }

    // SOCIAL MEDIA
    final socials = profile?.socialMediaLinks ?? const [];
    if (socials.isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('  SOCIAL MEDIA (for recent photos / reference)');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      for (final s in socials) {
        if (s.url.isEmpty) continue;
        final label = s.platformEnum.label;
        final handle =
            s.handle != null && s.handle!.isNotEmpty ? ' ${s.handle}' : '';
        buffer.writeln('$label:$handle ${s.url}');
      }
      buffer.writeln();
    }

    // EMERGENCY CONTACTS
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  EMERGENCY CONTACTS');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (report.emergencyContacts.isNotEmpty) {
      for (final contact in report.emergencyContacts) {
        buffer.writeln('${contact['name']} (${contact['relationship'] ?? 'Contact'})');
        buffer.writeln('  📞 ${contact['phoneNumber']}');
      }
    } else {
      buffer.writeln('(No emergency contacts on file)');
    }

    buffer.writeln();

    // IDENTIFICATION DOCUMENTS
    if (profile != null &&
        (profile.driversLicenseNumber != null || profile.medicareNumber != null)) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('  IDENTIFICATION DOCUMENTS');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (profile.driversLicenseNumber != null) {
        buffer.writeln("Driver's License: ${profile.driversLicenseNumber}");
        if (profile.driversLicenseState != null) {
          buffer.writeln('  State: ${profile.driversLicenseState}');
        }
      }
      if (profile.medicareNumber != null) {
        buffer.writeln('Medicare #: ${profile.medicareNumber}');
      }
      if (profile.ssnLast4 != null) {
        buffer.writeln('SSN (last 4): XXX-XX-${profile.ssnLast4}');
      }
      buffer.writeln();
    }

    // PHOTOS
    if (profile?.photos.isNotEmpty == true) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('  PHOTOS');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('${profile!.photos.length} photo(s) on file');
      final mostRecent = profile.mostRecentPhoto;
      if (mostRecent != null) {
        buffer.writeln('Most recent: ${dateFormat.format(mostRecent.dateTaken)}');
        buffer.writeln('Photo URL: ${mostRecent.url}');
      }
      buffer.writeln();
    }

    buffer.writeln('╔══════════════════════════════════════════════════════════╗');
    buffer.writeln('║  If found, please contact the numbers listed above or    ║');
    buffer.writeln('║  call local law enforcement immediately.                  ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════╝');
    buffer.writeln();
    buffer.writeln('Generated by Lumina Care App');

    return buffer.toString();
  }
}

/// Data class for a lost person report
class LostPersonReport {
  final DateTime generatedAt;
  final UserProfile? profile;
  final String userName;
  final HealthProfile? healthProfile;
  final List<Allergy> allergies;
  final List<Prescription> medications;
  final List<Map<String, dynamic>> emergencyContacts;

  LostPersonReport({
    required this.generatedAt,
    this.profile,
    required this.userName,
    this.healthProfile,
    this.allergies = const [],
    this.medications = const [],
    this.emergencyContacts = const [],
  });
}

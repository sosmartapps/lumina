import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/user_profile.dart';
import 'package:lumina/core/services/missing_person_flyer_service.dart';
import 'package:lumina/core/services/user_profile_service.dart';

void main() {
  test('generateFlyer lays out a full profile without throwing', () async {
    final now = DateTime.now();
    final profile = UserProfile(
      id: 'profile',
      userId: 'u1',
      legalFirstName: 'Jane',
      legalLastName: 'Doe',
      preferredName: 'Janie',
      dateOfBirth: DateTime(1950, 3, 12),
      gender: 'Female',
      race: 'White',
      heightCm: 165,
      weightKg: 60,
      hairColor: 'Gray',
      eyeColor: 'Blue',
      buildType: 'Slim',
      distinguishingMarks: 'Scar on left hand',
      usualClothing: 'Floral dresses',
      primaryDiagnosis: "Alzheimer's",
      cognitiveStatus: 'May not know her name',
      behaviorWhenLost: 'Follows strangers',
      streetAddress: '123 Main St',
      city: 'Tucson',
      state: 'AZ',
      frequentPlaces: [
        FrequentPlace(id: '1', name: 'Reid Park', notes: 'Loves the ducks'),
      ],
      vehicles: [
        Vehicle(
          id: 'v1',
          make: 'Toyota',
          model: 'Camry',
          year: 2018,
          color: 'Silver',
          licensePlate: 'ABC1234',
          licenseState: 'AZ',
          vin: '1HGCM82633A004352',
          notes: 'Dent on rear bumper',
        ),
      ],
      socialMediaLinks: [
        SocialMediaLink(
            platform: 'facebook',
            url: 'https://facebook.com/janedoe',
            handle: 'Jane Doe'),
        SocialMediaLink(
            platform: 'instagram', url: 'https://instagram.com/janed'),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final report = LostPersonReport(
      generatedAt: now,
      profile: profile,
      userName: 'Jane Doe',
      emergencyContacts: [
        {'name': 'John Doe', 'relationship': 'Son', 'phoneNumber': '520-555-0100'},
      ],
    );

    final bytes = await MissingPersonFlyerService.generateFlyer(
      report,
      options: const FlyerOptions(
        lastSeenLocation: 'Reid Park, Tucson',
        lastSeenWearing: 'Blue jacket',
        contactName: 'John Doe',
        contactPhone: '520-555-0100',
        additionalInfo: 'Diabetic — needs medication.',
      ),
    );

    // A valid PDF starts with "%PDF" and should be non-trivial in size.
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('generateFlyer handles an empty profile', () async {
    final now = DateTime.now();
    final report = LostPersonReport(
      generatedAt: now,
      profile: null,
      userName: 'Unknown Person',
    );
    final bytes = await MissingPersonFlyerService.generateFlyer(report);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}

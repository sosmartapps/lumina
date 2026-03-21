import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/models/subscription.dart';

void main() {
  group('SubscriptionTier', () {
    test('fromString parses known tiers', () {
      expect(SubscriptionTier.fromString('free'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString('premium'), SubscriptionTier.premium);
    });

    test('fromString defaults to free for unknown', () {
      expect(SubscriptionTier.fromString('enterprise'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString(''), SubscriptionTier.free);
    });
  });

  group('PatientSubscription', () {
    test('free tier is always active', () {
      final sub = PatientSubscription(patientId: 'p1');
      expect(sub.isActive, true);
      expect(sub.isPremium, false);
    });

    test('premium with future expiry is active', () {
      final sub = PatientSubscription(
        patientId: 'p1',
        tier: SubscriptionTier.premium,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(sub.isActive, true);
      expect(sub.isPremium, true);
    });

    test('premium with past expiry is inactive', () {
      final sub = PatientSubscription(
        patientId: 'p1',
        tier: SubscriptionTier.premium,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(sub.isActive, false);
      expect(sub.isPremium, false);
    });

    test('premium with null expiry is inactive', () {
      final sub = PatientSubscription(
        patientId: 'p1',
        tier: SubscriptionTier.premium,
      );
      expect(sub.isActive, false);
      expect(sub.isPremium, false);
    });

    group('feature gates', () {
      late PatientSubscription freeSub;
      late PatientSubscription premiumSub;

      setUp(() {
        freeSub = PatientSubscription(patientId: 'p1');
        premiumSub = PatientSubscription(
          patientId: 'p1',
          tier: SubscriptionTier.premium,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        );
      });

      test('free user cannot use premium features', () {
        expect(freeSub.canUseGeofencing, false);
        expect(freeSub.canUseVehicleTracking, false);
        expect(freeSub.canInviteCaregivers, false);
        expect(freeSub.canUseMedicationPhotos, false);
      });

      test('premium user can use all features', () {
        expect(premiumSub.canUseGeofencing, true);
        expect(premiumSub.canUseVehicleTracking, true);
        expect(premiumSub.canInviteCaregivers, true);
        expect(premiumSub.canUseMedicationPhotos, true);
      });

      test('free user has limited counts', () {
        expect(freeSub.maxReminders, 5);
        expect(freeSub.maxMedications, 3);
        expect(freeSub.maxSavedLocations, 3);
      });

      test('premium user has unlimited counts', () {
        expect(premiumSub.maxReminders, -1);
        expect(premiumSub.maxMedications, -1);
        expect(premiumSub.maxSavedLocations, -1);
      });
    });

    group('canAdd', () {
      test('returns true when under limit', () {
        final sub = PatientSubscription(patientId: 'p1');
        expect(sub.canAdd(currentCount: 2, limit: 5), true);
      });

      test('returns false when at limit', () {
        final sub = PatientSubscription(patientId: 'p1');
        expect(sub.canAdd(currentCount: 5, limit: 5), false);
      });

      test('returns false when over limit', () {
        final sub = PatientSubscription(patientId: 'p1');
        expect(sub.canAdd(currentCount: 6, limit: 5), false);
      });

      test('returns true for unlimited (-1)', () {
        final sub = PatientSubscription(patientId: 'p1');
        expect(sub.canAdd(currentCount: 999, limit: -1), true);
      });
    });

    test('copyWith preserves and overrides', () {
      final sub = PatientSubscription(
        patientId: 'p1',
        tier: SubscriptionTier.free,
      );

      final updated = sub.copyWith(
        tier: SubscriptionTier.premium,
        expiresAt: DateTime(2027, 1, 1),
      );

      expect(updated.patientId, 'p1'); // Preserved
      expect(updated.tier, SubscriptionTier.premium);
      expect(updated.expiresAt, DateTime(2027, 1, 1));
    });
  });
}

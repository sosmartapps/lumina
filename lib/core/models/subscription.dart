/// Subscription tier for a patient's care plan
enum SubscriptionTier {
  free('free'),
  premium('premium');

  final String value;
  const SubscriptionTier(this.value);

  factory SubscriptionTier.fromString(String s) {
    return SubscriptionTier.values.firstWhere(
      (t) => t.value == s,
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// Subscription details tied to a patient record
class PatientSubscription {
  final String patientId;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final String? revenueCatCustomerId;

  PatientSubscription({
    required this.patientId,
    this.tier = SubscriptionTier.free,
    this.expiresAt,
    this.revenueCatCustomerId,
  });

  bool get isActive {
    if (tier == SubscriptionTier.free) return true;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  bool get isPremium => tier == SubscriptionTier.premium && isActive;

  // Feature gates
  bool get canUseGeofencing => isPremium;
  bool get canUseVehicleTracking => isPremium;
  bool get canInviteCaregivers => isPremium;
  bool get canUseMedicationPhotos => isPremium;

  int get maxReminders => isPremium ? -1 : 5; // -1 = unlimited
  int get maxMedications => isPremium ? -1 : 3;
  int get maxSavedLocations => isPremium ? -1 : 3;

  /// Check if adding one more of a limited resource is allowed
  bool canAdd({required int currentCount, required int limit}) {
    if (limit == -1) return true;
    return currentCount < limit;
  }

  PatientSubscription copyWith({
    SubscriptionTier? tier,
    DateTime? expiresAt,
    String? revenueCatCustomerId,
  }) {
    return PatientSubscription(
      patientId: patientId,
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      revenueCatCustomerId: revenueCatCustomerId ?? this.revenueCatCustomerId,
    );
  }
}

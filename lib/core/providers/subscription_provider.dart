import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

/// ChangeNotifier that exposes subscription state for the current patient.
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service;
  PatientSubscription? _subscription;

  SubscriptionProvider(this._service);

  PatientSubscription? get subscription => _subscription;
  bool get isPremium => _subscription?.isPremium ?? false;
  SubscriptionTier get tier => _subscription?.tier ?? SubscriptionTier.free;

  // Feature gate helpers
  bool get canUseGeofencing => _subscription?.canUseGeofencing ?? false;
  bool get canUseVehicleTracking => _subscription?.canUseVehicleTracking ?? false;
  bool get canInviteCaregivers => _subscription?.canInviteCaregivers ?? false;
  bool get canUseMedicationPhotos => _subscription?.canUseMedicationPhotos ?? false;

  int get maxReminders => _subscription?.maxReminders ?? 5;
  int get maxMedications => _subscription?.maxMedications ?? 3;
  int get maxSavedLocations => _subscription?.maxSavedLocations ?? 3;

  bool canAddReminder(int currentCount) =>
      _subscription?.canAdd(currentCount: currentCount, limit: maxReminders) ?? true;

  bool canAddMedication(int currentCount) =>
      _subscription?.canAdd(currentCount: currentCount, limit: maxMedications) ?? true;

  bool canAddSavedLocation(int currentCount) =>
      _subscription?.canAdd(currentCount: currentCount, limit: maxSavedLocations) ?? true;

  /// Load subscription status for a patient.
  Future<void> loadSubscription(String patientId) async {
    _subscription = await _service.getSubscriptionStatus(patientId);
    notifyListeners();
  }

  /// Update after a purchase or restore.
  void updateSubscription(PatientSubscription sub) {
    _subscription = sub;
    notifyListeners();
  }
}

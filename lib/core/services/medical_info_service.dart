import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/health_profile.dart';
import '../models/prescription.dart';
import 'notification_service.dart';

/// Service for managing medical information, prescriptions, and health profiles
class MedicalInfoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // HEALTH PROFILE
  // ============================================================================

  /// Get or create health profile for a user
  static Future<HealthProfile?> getHealthProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_profile')
          .doc('profile')
          .get();

      if (doc.exists) {
        return HealthProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting health profile: $e');
      return null;
    }
  }

  /// Save or update health profile
  static Future<bool> saveHealthProfile(String userId, HealthProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_profile')
          .doc('profile')
          .set(profile.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error saving health profile: $e');
      return false;
    }
  }

  // ============================================================================
  // HEALTH CONDITIONS
  // ============================================================================

  /// Get all health conditions for a user
  static Stream<List<HealthCondition>> getHealthConditions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('health_conditions')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HealthCondition.fromFirestore(doc)).toList());
  }

  /// Add a health condition
  static Future<String?> addHealthCondition(String userId, HealthCondition condition) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_conditions')
          .add(condition.toFirestore());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding health condition: $e');
      return null;
    }
  }

  /// Update a health condition
  static Future<bool> updateHealthCondition(
      String userId, String conditionId, HealthCondition condition) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_conditions')
          .doc(conditionId)
          .update(condition.toFirestore());
      return true;
    } catch (e) {
      debugPrint('Error updating health condition: $e');
      return false;
    }
  }

  /// Delete a health condition
  static Future<bool> deleteHealthCondition(String userId, String conditionId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_conditions')
          .doc(conditionId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting health condition: $e');
      return false;
    }
  }

  // ============================================================================
  // ALLERGIES
  // ============================================================================

  /// Get all allergies for a user
  static Stream<List<Allergy>> getAllergies(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('allergies')
        .orderBy('allergen')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Allergy.fromFirestore(doc)).toList());
  }

  /// Add an allergy
  static Future<String?> addAllergy(String userId, Allergy allergy) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('allergies')
          .add(allergy.toFirestore());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding allergy: $e');
      return null;
    }
  }

  /// Delete an allergy
  static Future<bool> deleteAllergy(String userId, String allergyId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('allergies')
          .doc(allergyId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting allergy: $e');
      return false;
    }
  }

  // ============================================================================
  // HEALTHCARE PROVIDERS
  // ============================================================================

  /// Get all healthcare providers for a user
  static Stream<List<HealthcareProvider>> getHealthcareProviders(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('healthcare_providers')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HealthcareProvider.fromFirestore(doc)).toList());
  }

  /// Add a healthcare provider
  static Future<String?> addHealthcareProvider(
      String userId, HealthcareProvider provider) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('healthcare_providers')
          .add(provider.toFirestore());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding healthcare provider: $e');
      return null;
    }
  }

  /// Update a healthcare provider
  static Future<bool> updateHealthcareProvider(
      String userId, String providerId, HealthcareProvider provider) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('healthcare_providers')
          .doc(providerId)
          .update(provider.toFirestore());
      return true;
    } catch (e) {
      debugPrint('Error updating healthcare provider: $e');
      return false;
    }
  }

  /// Delete a healthcare provider
  static Future<bool> deleteHealthcareProvider(String userId, String providerId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('healthcare_providers')
          .doc(providerId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting healthcare provider: $e');
      return false;
    }
  }

  // ============================================================================
  // PHARMACIES
  // ============================================================================

  /// Get all pharmacies for a user
  static Stream<List<Pharmacy>> getPharmacies(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('pharmacies')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Pharmacy.fromFirestore(doc)).toList());
  }

  /// Add a pharmacy
  static Future<String?> addPharmacy(String userId, Pharmacy pharmacy) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('pharmacies')
          .add(pharmacy.toFirestore());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding pharmacy: $e');
      return null;
    }
  }

  /// Update a pharmacy
  static Future<bool> updatePharmacy(
      String userId, String pharmacyId, Pharmacy pharmacy) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('pharmacies')
          .doc(pharmacyId)
          .update(pharmacy.toFirestore());
      return true;
    } catch (e) {
      debugPrint('Error updating pharmacy: $e');
      return false;
    }
  }

  /// Delete a pharmacy
  static Future<bool> deletePharmacy(String userId, String pharmacyId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('pharmacies')
          .doc(pharmacyId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting pharmacy: $e');
      return false;
    }
  }

  // ============================================================================
  // PRESCRIPTIONS
  // ============================================================================

  /// Get all prescriptions for a user
  static Stream<List<Prescription>> getPrescriptions(String userId,
      {bool activeOnly = false}) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('prescriptions')
        .orderBy('medicationName');

    if (activeOnly) {
      query = query.where('status', isEqualTo: PrescriptionStatus.active.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList());
  }

  /// Get prescriptions needing refill
  static Future<List<Prescription>> getPrescriptionsNeedingRefill(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .where('status', isEqualTo: PrescriptionStatus.active.name)
          .where('refillReminderEnabled', isEqualTo: true)
          .get();

      final prescriptions = snapshot.docs
          .map((doc) => Prescription.fromFirestore(doc))
          .where((p) => p.needsRefillSoon || p.isRefillOverdue)
          .toList();

      return prescriptions;
    } catch (e) {
      debugPrint('Error getting prescriptions needing refill: $e');
      return [];
    }
  }

  /// Add a prescription
  static Future<String?> addPrescription(String userId, Prescription prescription) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .add(prescription.toFirestore());

      // Schedule refill reminder if enabled
      if (prescription.refillReminderEnabled && prescription.nextRefillDate != null) {
        await _scheduleRefillReminder(userId, doc.id, prescription);
      }

      return doc.id;
    } catch (e) {
      debugPrint('Error adding prescription: $e');
      return null;
    }
  }

  /// Update a prescription
  static Future<bool> updatePrescription(
      String userId, String prescriptionId, Prescription prescription) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .update(prescription.toFirestore());

      // Update refill reminder
      if (prescription.refillReminderEnabled && prescription.nextRefillDate != null) {
        await _scheduleRefillReminder(userId, prescriptionId, prescription);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating prescription: $e');
      return false;
    }
  }

  /// Delete a prescription
  static Future<bool> deletePrescription(String userId, String prescriptionId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting prescription: $e');
      return false;
    }
  }

  /// Record a prescription being filled
  static Future<bool> recordRefill(
      String userId, String prescriptionId, RefillRecord refill) async {
    try {
      final batch = _firestore.batch();

      // Add refill record
      final refillRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .collection('refill_history')
          .doc();
      batch.set(refillRef, refill.toFirestore());

      // Get current prescription
      final prescriptionDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .get();

      if (prescriptionDoc.exists) {
        final prescription = Prescription.fromFirestore(prescriptionDoc);

        // Calculate next refill date
        DateTime? nextRefillDate;
        if (prescription.daysSupply != null) {
          nextRefillDate = refill.filledDate.add(Duration(days: prescription.daysSupply!));
        }

        // Update prescription
        final prescriptionRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('prescriptions')
            .doc(prescriptionId);

        batch.update(prescriptionRef, {
          'lastFilledDate': Timestamp.fromDate(refill.filledDate),
          'nextRefillDate': nextRefillDate != null
              ? Timestamp.fromDate(nextRefillDate)
              : null,
          'remainingQuantity': refill.quantity ?? prescription.totalQuantity,
          'refillsRemaining': prescription.refillsRemaining != null
              ? prescription.refillsRemaining! - 1
              : null,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error recording refill: $e');
      return false;
    }
  }

  /// Get refill history for a prescription
  static Stream<List<RefillRecord>> getRefillHistory(
      String userId, String prescriptionId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('prescriptions')
        .doc(prescriptionId)
        .collection('refill_history')
        .orderBy('filledDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RefillRecord.fromFirestore(doc)).toList());
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  /// Schedule a refill reminder notification
  static Future<void> _scheduleRefillReminder(
      String userId, String prescriptionId, Prescription prescription) async {
    try {
      final reminderDate = prescription.nextRefillDate!.subtract(
        Duration(days: prescription.refillReminderDaysBefore),
      );

      if (reminderDate.isAfter(DateTime.now())) {
        await NotificationService.scheduleNotification(
          id: prescriptionId.hashCode,
          title: '💊 Prescription Refill Reminder',
          body: '${prescription.medicationName} needs to be refilled soon.',
          scheduledTime: reminderDate,
          payload: 'prescription:$prescriptionId',
        );
      }
    } catch (e) {
      debugPrint('Error scheduling refill reminder: $e');
    }
  }

  /// Check all prescriptions and send notifications for those needing refill
  static Future<void> checkRefillReminders(String userId) async {
    try {
      final prescriptions = await getPrescriptionsNeedingRefill(userId);

      for (final prescription in prescriptions) {
        if (prescription.isRefillOverdue) {
          await NotificationService.showNotification(
            id: prescription.id.hashCode,
            title: '⚠️ Prescription Refill Overdue',
            body: '${prescription.medicationName} needs to be refilled immediately.',
            payload: 'prescription:${prescription.id}',
          );
        } else if (prescription.needsRefillSoon) {
          await NotificationService.showNotification(
            id: prescription.id.hashCode + 1,
            title: '💊 Prescription Refill Needed',
            body: '${prescription.medicationName} will need a refill in ${prescription.daysUntilRefillNeeded ?? "a few"} days.',
            payload: 'prescription:${prescription.id}',
          );
        }

        // Check if no refills remaining
        if (prescription.noRefillsRemaining) {
          await NotificationService.showNotification(
            id: prescription.id.hashCode + 2,
            title: '📋 Prescription Renewal Needed',
            body: '${prescription.medicationName} has no refills remaining. Contact your doctor.',
            payload: 'prescription:${prescription.id}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking refill reminders: $e');
    }
  }

  // ============================================================================
  // MEDICAL SUMMARY GENERATION
  // ============================================================================

  /// Generate a complete medical summary for sharing with medical personnel
  static Future<Map<String, dynamic>> generateMedicalSummary(String userId) async {
    try {
      // Get health profile
      final profile = await getHealthProfile(userId);

      // Get conditions
      final conditionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_conditions')
          .where('isActive', isEqualTo: true)
          .get();
      final conditions = conditionsSnapshot.docs
          .map((doc) => HealthCondition.fromFirestore(doc))
          .toList();

      // Get allergies
      final allergiesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('allergies')
          .get();
      final allergies = allergiesSnapshot.docs
          .map((doc) => Allergy.fromFirestore(doc))
          .toList();

      // Get active prescriptions
      final prescriptionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .where('status', isEqualTo: PrescriptionStatus.active.name)
          .get();
      final prescriptions = prescriptionsSnapshot.docs
          .map((doc) => Prescription.fromFirestore(doc))
          .toList();

      // Get healthcare providers
      final providersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('healthcare_providers')
          .get();
      final providers = providersSnapshot.docs
          .map((doc) => HealthcareProvider.fromFirestore(doc))
          .toList();

      // Get user info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      return {
        'generatedAt': DateTime.now().toIso8601String(),
        'patient': {
          'name': userData['name'],
          'dateOfBirth': userData['dateOfBirth'],
          'bloodType': profile?.bloodType,
          'height': profile?.height,
          'weight': profile?.weight,
          'insuranceProvider': profile?.insuranceProvider,
          'insurancePolicyNumber': profile?.insurancePolicyNumber,
          'insuranceGroupNumber': profile?.insuranceGroupNumber,
        },
        'emergencyNotes': profile?.emergencyNotes,
        'advanceDirectives': profile?.advanceDirectives,
        'conditions': conditions.map((c) => {
          'name': c.name,
          'description': c.description,
          'diagnosisDate': c.diagnosisDate?.toIso8601String(),
          'diagnosedBy': c.diagnosedBy,
          'severity': c.severity,
          'notes': c.notes,
        }).toList(),
        'allergies': allergies.map((a) => {
          'allergen': a.allergen,
          'reaction': a.reaction,
          'severity': a.severity,
        }).toList(),
        'medications': prescriptions.map((p) => {
          'name': p.medicationName,
          'genericName': p.genericName,
          'dosage': p.dosage,
          'frequency': p.frequency,
          'instructions': p.instructions,
          'prescribedBy': p.prescribedBy,
          'reason': p.reason,
          'startDate': p.startDate?.toIso8601String(),
        }).toList(),
        'healthcareProviders': providers.map((p) => {
          'name': p.name,
          'specialty': p.specialty,
          'practice': p.practice,
          'phone': p.phone,
          'isPrimaryCare': p.isPrimaryCare,
        }).toList(),
      };
    } catch (e) {
      debugPrint('Error generating medical summary: $e');
      return {};
    }
  }
}

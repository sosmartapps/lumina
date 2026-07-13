import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/reminder.dart';
import '../models/medication.dart';
import '../models/prescription.dart';
import 'notification_service.dart';
import 'photo_match_service.dart';

/// Service for managing reminders and medications
class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reminders

  /// Create a new reminder
  Future<Reminder> createReminder(Reminder reminder) async {
    final docRef = _firestore.collection('reminders').doc();
    final newReminder = Reminder(
      id: docRef.id,
      userId: reminder.userId,
      title: reminder.title,
      description: reminder.description,
      spokenMessage: reminder.spokenMessage,
      type: reminder.type,
      scheduledTime: reminder.scheduledTime,
      repeatDays: reminder.repeatDays,
      repeatFrequency: reminder.repeatFrequency,
      isActive: reminder.isActive,
      requiresConfirmation: reminder.requiresConfirmation,
      requiresPhoto: reminder.requiresPhoto,
      iconName: reminder.iconName,
      color: reminder.color,
      snoozeMinutes: reminder.snoozeMinutes,
      maxSnoozeCount: reminder.maxSnoozeCount,
      createdBy: reminder.createdBy,
    );

    await docRef.set(newReminder.toFirestore());

    return newReminder;
  }

  /// Update an existing reminder. Editing RE-ARMS it for today: clears
  /// completion/trigger state so a caregiver moving the time later in
  /// the day gets a fresh fire (edited alarm silently never fired,
  /// 2026-07-12).
  Future<void> updateReminder(Reminder reminder) async {
    final data = reminder.toFirestore();
    data['completedAt'] = null;
    data['lastTriggeredAt'] = null;
    data['completionPhotoUrl'] = null;
    data['completionPhotoHash'] = null;
    data['verificationStatus'] = null;
    data['verificationReason'] = null;
    await _firestore
        .collection('reminders')
        .doc(reminder.id)
        .update(data);
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection('reminders').doc(reminderId).delete();
    await NotificationService.cancelNotification(reminderId.hashCode);
  }

  /// Get reminders for a user
  Stream<List<Reminder>> getReminders(String userId) {
    return _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Reminder.fromFirestore(doc)).toList());
  }

  /// Get reminders for today.
  ///
  /// Includes both one-time reminders scheduled for today AND recurring
  /// reminders that repeat daily/weekly/custom. Recurring reminders keep
  /// their original scheduledTime (from creation), so we can't filter by
  /// today's date range alone — we fetch all active reminders and filter
  /// client-side for recurring ones.
  Stream<List<Reminder>> getTodayReminders(String userId) {
    final now = DateTime.now();

    return _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) {
      final allReminders =
          snapshot.docs.map((doc) => Reminder.fromFirestore(doc)).toList();

      // Single source of truth for repeat logic: Reminder.occursOn
      return allReminders.where((r) => r.occursOn(now)).toList();
    });
  }

  /// Mark reminder as completed.
  ///
  /// Match-first verification (cost design, 2026-07-12): if the photo's
  /// on-device hash matches the reminder's reference hash, it verifies
  /// locally for FREE and the AI Cloud Function skips it. Only photos
  /// without a reference yet (first time) or that don't match go
  /// 'pending' for Claude vision.
  Future<void> completeReminder(
    String reminderId, {
    String? photoUrl,
    String? photoHash,
  }) async {
    String? status;
    String? reason;
    Map<String, dynamic>? reminderData;
    try {
      final doc =
          await _firestore.collection('reminders').doc(reminderId).get();
      reminderData = doc.data() as Map<String, dynamic>?;
    } catch (_) {}
    if (photoUrl != null) {
      status = 'pending';
      final referenceHash = reminderData?['referencePhotoHash'] as String?;
      if (PhotoMatchService.matches(photoHash, referenceHash)) {
        status = 'verified';
        reason = 'Matched previous verified photo';
      }
    }
    await _firestore.collection('reminders').doc(reminderId).update({
      'completedAt': FieldValue.serverTimestamp(),
      'completionPhotoUrl': photoUrl,
      'completionPhotoHash': photoHash,
      'currentSnoozeCount': 0,
      'verificationStatus': status,
      'verificationReason': reason,
    });
    // Permanent history trail — the reminder doc only holds the LATEST
    // completion (recurring reminders overwrite daily). The verification
    // Cloud Function updates this log doc's verdict when it lands.
    await _firestore.collection('task_completions').add({
      'userId': reminderData?['userId'],
      'reminderId': reminderId,
      'title': reminderData?['title'] ?? 'Task',
      'type': reminderData?['type'] ?? 'general',
      'completedAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'verificationStatus': status,
      'verificationReason': reason,
    });
    // Pet-feeding bridge: completing a linked reminder IS the feeding —
    // log it so the caregiver's Pet Feeding screen shows "fed".
    final sourceFeedingId = reminderData?['sourceFeedingId'] as String?;
    if (sourceFeedingId != null) {
      try {
        await _firestore.collection('feeding_logs').add({
          'feedingId': sourceFeedingId,
          'userId': reminderData?['userId'],
          'petName': (reminderData?['title'] as String? ?? '')
              .replaceFirst('Feed ', '')
              .replaceAll(RegExp(r' \(.*\)$'), ''),
          'scheduledTime': reminderData?['scheduledTime'],
          'fedAt': FieldValue.serverTimestamp(),
          'fedByName': 'Patient',
          'notes': photoUrl != null
              ? 'Completed via reminder (photo)'
              : 'Completed via reminder',
        });
        await _firestore
            .collection('pet_feedings')
            .doc(sourceFeedingId)
            .update({'lastFedAt': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('feeding log from reminder failed: $e');
      }
    }
  }

  /// Caregiver override of a photo verification verdict — the human is
  /// always the authority over the AI. Approving also TEACHES the
  /// reference hash, so future photos of this family's setup verify
  /// on-device for free. Rejecting un-learns a wrongly-taught reference.
  Future<void> overrideVerification(
    Reminder reminder, {
    required bool approved,
  }) async {
    final update = <String, dynamic>{
      'verificationStatus': approved ? 'verified' : 'failed',
      'verificationReason':
          approved ? 'Approved by caregiver' : 'Rejected by caregiver',
    };
    if (approved && reminder.completionPhotoHash != null) {
      update['referencePhotoHash'] = reminder.completionPhotoHash;
    } else if (!approved &&
        reminder.referencePhotoHash != null &&
        reminder.referencePhotoHash == reminder.completionPhotoHash) {
      update['referencePhotoHash'] = FieldValue.delete();
    }
    await _firestore.collection('reminders').doc(reminder.id).update(update);
  }

  /// Snooze a reminder.
  ///
  /// Uses `lastTriggeredAt` + snooze offset to track when the snoozed
  /// reminder should re-fire, instead of permanently modifying
  /// `scheduledTime` (which would drift recurring reminders).
  Future<void> snoozeReminder(String reminderId, int snoozeMinutes) async {
    final doc = await _firestore.collection('reminders').doc(reminderId).get();
    final reminder = Reminder.fromFirestore(doc);

    if (reminder.currentSnoozeCount < reminder.maxSnoozeCount) {
      await _firestore.collection('reminders').doc(reminderId).update({
        'lastTriggeredAt': FieldValue.serverTimestamp(),
        'currentSnoozeCount': FieldValue.increment(1),
      });
      // Note: The UI/notification system should use lastTriggeredAt +
      // snoozeMinutes to determine the next re-fire time, while
      // scheduledTime stays as the original daily schedule.
    }
  }

  // Medications

  /// Create a new medication
  Future<Medication> createMedication(Medication medication) async {
    final docRef = _firestore.collection('medications').doc();
    final newMedication = Medication(
      id: docRef.id,
      userId: medication.userId,
      name: medication.name,
      description: medication.description,
      dosage: medication.dosage,
      instructions: medication.instructions,
      schedules: medication.schedules,
      pillContainerPhotoUrl: medication.pillContainerPhotoUrl,
      color: medication.color,
      iconName: medication.iconName,
      isActive: medication.isActive,
      startDate: medication.startDate,
      endDate: medication.endDate,
      refillAlertDays: medication.refillAlertDays,
      currentSupply: medication.currentSupply,
      createdBy: medication.createdBy,
    );

    await docRef.set(newMedication.toFirestore());

    return newMedication;
  }

  /// Update medication
  Future<void> updateMedication(Medication medication) async {
    await _firestore
        .collection('medications')
        .doc(medication.id)
        .update(medication.toFirestore());
  }

  /// Delete medication
  Future<void> deleteMedication(String medicationId) async {
    await _firestore.collection('medications').doc(medicationId).delete();
  }

  /// Get medications for a user
  Stream<List<Medication>> getMedications(String userId) {
    return _firestore
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Medication.fromFirestore(doc)).toList());
  }

  /// Log medication taken
  Future<MedicationLog> logMedicationTaken({
    required String medicationId,
    required String userId,
    required DateTime scheduledTime,
    String? photoUrl,
    String? notes,
    bool verifiedByComparison = false,
    double? comparisonScore,
  }) async {
    final docRef = _firestore.collection('medication_logs').doc();
    final log = MedicationLog(
      id: docRef.id,
      medicationId: medicationId,
      userId: userId,
      scheduledTime: scheduledTime,
      takenTime: DateTime.now(),
      status: MedicationLogStatus.taken,
      photoUrl: photoUrl,
      notes: notes,
      verifiedByComparison: verifiedByComparison,
      comparisonScore: comparisonScore,
    );

    await docRef.set(log.toFirestore());

    // Decrement supply count
    await _firestore.collection('medications').doc(medicationId).update({
      'currentSupply': FieldValue.increment(-1),
    });

    return log;
  }

  /// Log medication missed
  Future<void> logMedicationMissed({
    required String medicationId,
    required String userId,
    required DateTime scheduledTime,
  }) async {
    final docRef = _firestore.collection('medication_logs').doc();
    final log = MedicationLog(
      id: docRef.id,
      medicationId: medicationId,
      userId: userId,
      scheduledTime: scheduledTime,
      status: MedicationLogStatus.missed,
    );

    await docRef.set(log.toFirestore());

    // Notify caregivers
    await NotificationService.notifyCaregivers(
      userId: userId,
      title: '⚠️ Medication Missed',
      body: 'Medication was not taken at the scheduled time',
      data: {
        'type': 'medication_missed',
        'medicationId': medicationId,
        'scheduledTime': scheduledTime.toIso8601String(),
      },
    );
  }

  /// Get medication logs
  Stream<List<MedicationLog>> getMedicationLogs(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? medicationId,
  }) {
    Query query = _firestore
        .collection('medication_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledTime', descending: true);

    if (startDate != null) {
      query = query.where('scheduledTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('scheduledTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (medicationId != null) {
      query = query.where('medicationId', isEqualTo: medicationId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MedicationLog.fromFirestore(doc)).toList());
  }

  /// Get today's medication schedule
  List<DateTime> getTodayMedicationTimes(Medication medication) {
    final now = DateTime.now();
    final times = <DateTime>[];

    for (final schedule in medication.schedules) {
      // Check if medication is scheduled for today
      if (schedule.days == null ||
          schedule.days!.contains(now.weekday)) {
        times.add(DateTime(
          now.year,
          now.month,
          now.day,
          schedule.hour,
          schedule.minute,
        ));
      }
    }

    times.sort();
    return times;
  }

  // Prescriptions

  /// Create a new prescription
  Future<Prescription> createPrescription(Prescription prescription) async {
    final docRef = _firestore.collection('prescriptions').doc();
    final now = DateTime.now();
    final newPrescription = prescription.copyWith(
      id: docRef.id,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(newPrescription.toFirestore());
    return newPrescription;
  }

  /// Update a prescription
  Future<void> updatePrescription(Prescription prescription) async {
    final updated = prescription.copyWith(updatedAt: DateTime.now());
    await _firestore
        .collection('prescriptions')
        .doc(prescription.id)
        .update(updated.toFirestore());
  }

  /// Delete a prescription
  Future<void> deletePrescription(String prescriptionId) async {
    await _firestore.collection('prescriptions').doc(prescriptionId).delete();
  }

  /// Get prescriptions for a user
  Stream<List<Prescription>> getPrescriptions(String userId) {
    return _firestore
        .collection('prescriptions')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList());
  }

  /// Log a refill for a prescription
  Future<void> logRefill({
    required String prescriptionId,
    required DateTime filledDate,
    String? pharmacyName,
    int? quantity,
    double? cost,
    String? notes,
  }) async {
    final docRef = _firestore
        .collection('prescriptions')
        .doc(prescriptionId)
        .collection('refills')
        .doc();

    final record = RefillRecord(
      id: docRef.id,
      prescriptionId: prescriptionId,
      filledDate: filledDate,
      pharmacyName: pharmacyName,
      quantity: quantity,
      cost: cost,
      notes: notes,
    );

    await docRef.set(record.toFirestore());

    // Update prescription with latest fill info
    final updates = <String, dynamic>{
      'lastFilledDate': Timestamp.fromDate(filledDate),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (quantity != null) updates['remainingQuantity'] = quantity;

    await _firestore
        .collection('prescriptions')
        .doc(prescriptionId)
        .update(updates);
  }

  /// Get refill history for a prescription
  Stream<List<RefillRecord>> getRefillHistory(String prescriptionId) {
    return _firestore
        .collection('prescriptions')
        .doc(prescriptionId)
        .collection('refills')
        .orderBy('filledDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RefillRecord.fromFirestore(doc)).toList());
  }

  /// Schedule all notifications for a user
  Future<void> scheduleAllNotifications(
    String userId,
    String userName,
  ) async {
    try {
      // Cancel existing notifications
      await NotificationService.cancelAllNotifications();

      // Schedule reminders
      final remindersSnapshot = await _firestore
          .collection('reminders')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in remindersSnapshot.docs) {
        final reminder = Reminder.fromFirestore(doc);
        await NotificationService.scheduleReminder(
          reminder: reminder,
          userName: userName,
        );
      }

      // Schedule medications
      final medicationsSnapshot = await _firestore
          .collection('medications')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in medicationsSnapshot.docs) {
        final medication = Medication.fromFirestore(doc);
        for (final schedule in medication.schedules) {
          await NotificationService.scheduleMedicationReminder(
            medication: medication,
            schedule: schedule,
            userName: userName,
          );
        }
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }
}

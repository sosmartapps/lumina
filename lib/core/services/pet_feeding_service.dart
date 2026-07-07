import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_feeding.dart';
import 'notification_service.dart';

/// Service for managing pet feeding schedules and feeding history.
///
/// Feeding schedules live in the `pet_feedings` collection; every time a pet
/// is marked fed a record is written to `feeding_logs` and the parent
/// schedule's `lastFedAt` is updated for quick "last fed" display.
class PetFeedingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _feedings => _firestore.collection('pet_feedings');
  CollectionReference get _logs => _firestore.collection('feeding_logs');

  // ---------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------

  /// Create a new feeding schedule and (re)schedule its notifications.
  Future<PetFeeding> createFeeding(PetFeeding feeding) async {
    final docRef = _feedings.doc();
    final withId = PetFeeding(
      id: docRef.id,
      userId: feeding.userId,
      petName: feeding.petName,
      petType: feeding.petType,
      foodType: feeding.foodType,
      amount: feeding.amount,
      feedingTimes: feeding.feedingTimes,
      repeatDays: feeding.repeatDays,
      isActive: feeding.isActive,
      notes: feeding.notes,
      lastFedAt: feeding.lastFedAt,
      createdAt: feeding.createdAt,
      createdBy: feeding.createdBy,
    );
    await docRef.set(withId.toFirestore());
    if (withId.isActive) {
      await NotificationService.schedulePetFeeding(feeding: withId);
    }
    return withId;
  }

  /// Update a feeding schedule and refresh its notifications.
  Future<void> updateFeeding(PetFeeding feeding) async {
    // Cancel notifications based on the *previous* times/days — otherwise a
    // removed feeding time would leave an orphaned notification behind.
    final oldDoc = await _feedings.doc(feeding.id).get();
    if (oldDoc.exists) {
      await NotificationService.cancelPetFeeding(PetFeeding.fromFirestore(oldDoc));
    }

    await _feedings.doc(feeding.id).update(feeding.toFirestore());

    if (feeding.isActive) {
      await NotificationService.schedulePetFeeding(feeding: feeding);
    }
  }

  /// Delete a feeding schedule and cancel its notifications.
  Future<void> deleteFeeding(PetFeeding feeding) async {
    await NotificationService.cancelPetFeeding(feeding);
    await _feedings.doc(feeding.id).delete();
  }

  // ---------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------

  /// All active feeding schedules for a patient.
  Stream<List<PetFeeding>> getFeedings(String userId) {
    return _feedings
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(PetFeeding.fromFirestore).toList()
          ..sort((a, b) => a.petName.toLowerCase().compareTo(b.petName.toLowerCase())));
  }

  /// Feeding history for a patient, newest first.
  Stream<List<FeedingLog>> getFeedingLogs(String userId, {int limit = 100}) {
    return _logs
        .where('userId', isEqualTo: userId)
        .orderBy('fedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(FeedingLog.fromFirestore).toList());
  }

  /// Feeding history for a single schedule, newest first.
  Stream<List<FeedingLog>> getLogsForFeeding(String feedingId, {int limit = 50}) {
    return _logs
        .where('feedingId', isEqualTo: feedingId)
        .orderBy('fedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(FeedingLog.fromFirestore).toList());
  }

  // ---------------------------------------------------------------------
  // Feeding actions
  // ---------------------------------------------------------------------

  /// Record that a pet was fed. Writes a [FeedingLog] and bumps the
  /// schedule's `lastFedAt`.
  Future<FeedingLog> markFed({
    required PetFeeding feeding,
    DateTime? scheduledSlot,
    String? fedByName,
    String? notes,
  }) async {
    final now = DateTime.now();
    final docRef = _logs.doc();
    final log = FeedingLog(
      id: docRef.id,
      feedingId: feeding.id,
      userId: feeding.userId,
      petName: feeding.petName,
      scheduledTime: scheduledSlot,
      fedAt: now,
      foodType: feeding.foodType,
      amount: feeding.amount,
      fedByName: fedByName,
      notes: notes,
    );

    await docRef.set(log.toFirestore());
    await _feedings.doc(feeding.id).update({'lastFedAt': Timestamp.fromDate(now)});
    return log;
  }

  /// Delete a single history entry.
  Future<void> deleteLog(String logId) async {
    await _logs.doc(logId).delete();
  }

  // ---------------------------------------------------------------------
  // Notification scheduling
  // ---------------------------------------------------------------------

  /// (Re)schedule notifications for every active feeding of a patient.
  /// Called on app launch as part of the full notification refresh.
  Future<void> scheduleAllFeedingNotifications(String userId) async {
    final snap = await _feedings
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    for (final doc in snap.docs) {
      await NotificationService.schedulePetFeeding(
        feeding: PetFeeding.fromFirestore(doc),
      );
    }
  }
}

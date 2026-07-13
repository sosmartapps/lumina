import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pet_feeding.dart';
import 'notification_service.dart';

/// Service for managing pet feeding schedules and feeding history.
///
/// Feeding schedules live in the `pet_feedings` collection; every time a pet
/// is marked fed a record is written to `feeding_logs` and the parent
/// schedule's `lastFedAt` is updated for quick "last fed" display.
class PetFeedingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

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
      foodPhotoUrls: feeding.foodPhotoUrls,
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
    await _syncPatientReminders(withId);
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
    await _syncPatientReminders(feeding);
  }

  /// Delete a feeding schedule, cancel its notifications, and remove the
  /// linked patient reminders.
  Future<void> deleteFeeding(PetFeeding feeding) async {
    await NotificationService.cancelPetFeeding(feeding);
    await _feedings.doc(feeding.id).delete();
    final linked = await _firestore
        .collection('reminders')
        .where('sourceFeedingId', isEqualTo: feeding.id)
        .get();
    for (final doc in linked.docs) {
      await doc.reference.delete();
    }
  }

  /// PET FEEDING → PATIENT REMINDERS bridge (2026-07-13).
  ///
  /// The PATIENT feeds the pet — feeding times must surface as patient
  /// reminders (popup, photo of food in bowls, AI verification, history),
  /// not as a caregiver-side button. One reminder per feeding time with a
  /// deterministic id (petfeed_{feedingId}_{timeId}) so sync is idempotent:
  /// removed/renamed times delete their reminder, edits update in place
  /// (preserving today's completion state).
  Future<void> _syncPatientReminders(PetFeeding feeding) async {
    final reminders = _firestore.collection('reminders');
    final existing = await reminders
        .where('sourceFeedingId', isEqualTo: feeding.id)
        .get();
    final wantedIds = {
      for (final t in feeding.feedingTimes) 'petfeed_${feeding.id}_${t.id}',
    };
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      if (!feeding.isActive || !wantedIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    if (feeding.isActive) {
      final now = DateTime.now();
      final existingIds = existing.docs.map((d) => d.id).toSet();
      final hasDays =
          feeding.repeatDays != null && feeding.repeatDays!.isNotEmpty;
      for (final t in feeding.feedingTimes) {
        final id = 'petfeed_${feeding.id}_${t.id}';
        final data = <String, dynamic>{
          'userId': feeding.userId,
          'title':
              'Feed ${feeding.petName}${t.label != null ? ' (${t.label})' : ''}',
          'description': [feeding.amount, feeding.foodType]
              .whereType<String>()
              .join(' of '),
          'spokenMessage':
              '{name}, time to feed ${feeding.petName}',
          'type': 'pet_care',
          'scheduledTime': Timestamp.fromDate(
              DateTime(now.year, now.month, now.day, t.hour, t.minute)),
          'repeatDays': feeding.repeatDays,
          'repeatFrequency': hasDays ? 'custom' : 'daily',
          'isActive': true,
          'requiresConfirmation': false,
          'requiresPhoto': true,
          'homeOnly': true,
          'snoozeMinutes': 10,
          'maxSnoozeCount': 3,
          'createdBy': feeding.createdBy,
          'sourceFeedingId': feeding.id,
        };
        if (existingIds.contains(id)) {
          batch.update(reminders.doc(id), data);
        } else {
          data['createdAt'] = Timestamp.now();
          data['currentSnoozeCount'] = 0;
          batch.set(reminders.doc(id), data);
        }
      }
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------
  // Food photos (e.g. the measuring cup of kibble, the wet-food can)
  // ---------------------------------------------------------------------

  Future<File?> captureFoodPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;
    return File(image.path);
  }

  Future<File?> pickFoodPhotoFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;
    return File(image.path);
  }

  /// Upload a food photo; returns the download URL.
  /// Storage path: pet_food_photos/{patientUserId}/{timestamp}.jpg
  Future<String> uploadFoodPhoto({
    required File file,
    required String userId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('pet_food_photos/$userId/$timestamp.jpg');
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  /// Best-effort delete of an uploaded food photo.
  Future<void> deleteFoodPhoto(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
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

    // Complete the most-recently-due linked patient reminder for today so
    // the patient isn't nagged for a pet the caregiver already fed.
    try {
      final linked = await _firestore
          .collection('reminders')
          .where('sourceFeedingId', isEqualTo: feeding.id)
          .get();
      DocumentReference? target;
      DateTime? best;
      for (final d in linked.docs) {
        final st = (d.data()['scheduledTime'] as Timestamp?)?.toDate();
        if (st == null) continue;
        final occ = DateTime(now.year, now.month, now.day, st.hour, st.minute);
        if (!occ.isAfter(now) && (best == null || occ.isAfter(best))) {
          best = occ;
          target = d.reference;
        }
      }
      target ??= linked.docs.isNotEmpty ? linked.docs.first.reference : null;
      await target?.update({
        'completedAt': Timestamp.fromDate(now),
        'verificationStatus': 'verified',
        'verificationReason': 'Marked fed by ${fedByName ?? 'caregiver'}',
      });
    } catch (_) {}
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Handles account deletion with cascading Firestore cleanup.
///
/// Each app provides its own list of writable and read-only subcollections
/// since different apps store different data under the user's document.
///
/// ```dart
/// await SSAAccountDeletion.deleteCurrentUser(
///   writableCollections: ['profile', 'dailyData', 'goals'],
///   readOnlyCollections: ['briefings', 'chatMessages'],
/// );
/// ```
class SSAAccountDeletion {
  SSAAccountDeletion._();

  /// Delete the current user's account and all associated Firestore data.
  ///
  /// [writableCollections] — subcollections the client has write access to.
  /// [readOnlyCollections] — subcollections with write:false rules (best-effort).
  ///
  /// Deletes Firestore data first, then the Firebase Auth account
  /// (which invalidates the token, so it must be last).
  static Future<void> deleteCurrentUser({
    List<String> writableCollections = const [],
    List<String> readOnlyCollections = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated user');

    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    // Delete writable subcollections
    for (final sub in writableCollections) {
      try {
        final snap = await db.collection('users/$uid/$sub').limit(500).get();
        if (snap.docs.isNotEmpty) {
          final batch = db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Could not delete $sub: $e');
      }
    }

    // Best-effort on read-only collections
    for (final sub in readOnlyCollections) {
      try {
        final snap = await db.collection('users/$uid/$sub').limit(500).get();
        if (snap.docs.isNotEmpty) {
          final batch = db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (_) {
        // Expected — these are Cloud Functions–only collections
      }
    }

    // Delete the user document itself
    try {
      await db.doc('users/$uid').delete();
    } catch (e) {
      debugPrint('Could not delete user doc: $e');
    }

    // Delete Firebase Auth account (must be last — invalidates token)
    await user.delete();
  }
}

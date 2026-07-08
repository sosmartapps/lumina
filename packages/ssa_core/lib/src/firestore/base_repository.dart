import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_helpers.dart';

/// Base repository providing standard Firestore CRUD and streaming patterns.
///
/// Apps extend this class and define their collection path:
///
/// ```dart
/// class GoalRepository extends BaseRepository {
///   GoalRepository(String userId)
///       : super(collectionPath: 'users/$userId/goals');
/// }
/// ```
abstract class BaseRepository {
  BaseRepository({required this.collectionPath});

  /// The Firestore collection path this repository operates on.
  final String collectionPath;

  /// Firestore instance (override in tests).
  @protected
  FirebaseFirestore get db => FirebaseFirestore.instance;

  /// Reference to the collection.
  @protected
  CollectionReference<Map<String, dynamic>> get collection =>
      db.collection(collectionPath);

  /// Get a single document by ID.
  Future<Map<String, dynamic>?> getById(String id) async {
    final doc = await collection.doc(id).get();
    if (!doc.exists) return null;
    return doc.dataWithId;
  }

  /// Stream a single document by ID.
  Stream<Map<String, dynamic>?> watchById(String id) {
    return collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.dataWithId;
    });
  }

  /// Get all documents in the collection.
  Future<List<Map<String, dynamic>>> getAll({
    int? limit,
    String? orderBy,
    bool descending = false,
  }) async {
    Query<Map<String, dynamic>> query = collection;
    if (orderBy != null) query = query.orderBy(orderBy, descending: descending);
    if (limit != null) query = query.limit(limit);
    final snap = await query.get();
    return snap.dataWithIds;
  }

  /// Stream all documents in the collection.
  Stream<List<Map<String, dynamic>>> watchAll({
    int? limit,
    String? orderBy,
    bool descending = false,
  }) {
    Query<Map<String, dynamic>> query = collection;
    if (orderBy != null) query = query.orderBy(orderBy, descending: descending);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map((snap) => snap.dataWithIds);
  }

  /// Create a new document with an auto-generated ID.
  /// Returns the generated document ID.
  Future<String> create(Map<String, dynamic> data) async {
    final doc = await collection.add(data);
    return doc.id;
  }

  /// Create or overwrite a document with a specific ID.
  Future<void> set(String id, Map<String, dynamic> data) async {
    await collection.doc(id).set(data);
  }

  /// Merge-update a document (only overwrites specified fields).
  Future<void> update(String id, Map<String, dynamic> data) async {
    await collection.doc(id).set(data, SetOptions(merge: true));
  }

  /// Delete a document by ID.
  Future<void> delete(String id) async {
    await collection.doc(id).delete();
  }

  /// Delete all documents in the collection (batch, up to [limit]).
  Future<int> deleteAll({int limit = 500}) async {
    return batchDeleteCollection(collectionPath, limit: limit);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Safely parse a Firestore date field that may be a [Timestamp],
/// ISO 8601 string, or null.
///
/// Returns null if [value] is null or unparseable.
DateTime? tryParseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Like [tryParseFirestoreDate] but returns [DateTime.now()] if null.
DateTime parseFirestoreDate(dynamic value) {
  return tryParseFirestoreDate(value) ?? DateTime.now();
}

/// Convert a [DateTime] to a Firestore-safe ISO 8601 string.
String dateToFirestore(DateTime date) => date.toUtc().toIso8601String();

/// Extension methods on [DocumentSnapshot] for convenient data access.
extension DocumentSnapshotX on DocumentSnapshot<Map<String, dynamic>> {
  /// Get the document data as a map, with the document ID injected as 'id'.
  Map<String, dynamic> get dataWithId {
    final data = this.data() ?? {};
    data['id'] = id;
    return data;
  }
}

/// Extension methods on [QuerySnapshot] for convenient data access.
extension QuerySnapshotX on QuerySnapshot<Map<String, dynamic>> {
  /// Convert all documents to maps with IDs injected.
  List<Map<String, dynamic>> get dataWithIds {
    return docs.map((doc) => doc.dataWithId).toList();
  }
}

/// Batch-delete all documents in a collection path (up to [limit] per call).
///
/// Returns the number of documents deleted.
Future<int> batchDeleteCollection(
  String path, {
  int limit = 500,
}) async {
  final db = FirebaseFirestore.instance;
  final snap = await db.collection(path).limit(limit).get();
  if (snap.docs.isEmpty) return 0;

  final batch = db.batch();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
  return snap.docs.length;
}

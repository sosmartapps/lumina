import 'package:cloud_firestore/cloud_firestore.dart';

/// A family's Bouncie account link for one patient.
///
/// Stored at `bouncie_connections/{patientUserId}`. The durable credential
/// is the OAuth [authCode] — Bouncie lets it be re-exchanged for fresh
/// access tokens, which is exactly how [BouncieService] refreshes. The
/// app-level client id/secret stay in app config; only the user-specific
/// authorization and vehicle choice live here.
class BouncieConnection {
  /// Patient (Lumina user) this vehicle belongs to. Also the doc id.
  final String userId;

  /// OAuth authorization code from the family's own Bouncie login.
  final String authCode;

  /// IMEI of the vehicle selected during connect.
  final String imei;

  /// e.g. "Jack" (Bouncie nickname).
  final String? nickName;

  /// e.g. "2014 FORD F-150".
  final String? model;

  final String connectedBy; // caregiver uid
  final DateTime connectedAt;

  BouncieConnection({
    required this.userId,
    required this.authCode,
    required this.imei,
    this.nickName,
    this.model,
    required this.connectedBy,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  factory BouncieConnection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BouncieConnection(
      userId: doc.id,
      authCode: data['authCode'] ?? '',
      imei: data['imei'] ?? '',
      nickName: data['nickName'],
      model: data['model'],
      connectedBy: data['connectedBy'] ?? '',
      connectedAt:
          (data['connectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authCode': authCode,
      'imei': imei,
      'nickName': nickName,
      'model': model,
      'connectedBy': connectedBy,
      'connectedAt': Timestamp.fromDate(connectedAt),
    };
  }
}

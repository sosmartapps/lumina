import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invite_code.dart';
import '../models/caregiver.dart';
import '../models/app_user.dart';

/// Service for managing invite codes to link caregivers to patients
class InviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Characters excluding ambiguous ones (0/O, 1/I/L)
  static const _chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _codeLength = 6;

  String _generateCode() {
    final random = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _chars[random.nextInt(_chars.length)],
    ).join();
  }

  /// Create an invite code (only primary caregiver should call this)
  Future<InviteCode> createInviteCode({
    required String patientId,
    required String caregiverId,
    required List<CaregiverRole> assignedRoles,
    Duration expiry = const Duration(hours: 24),
  }) async {
    assert(assignedRoles.isNotEmpty);
    // Generate a unique code, retry on collision
    String code;
    bool exists;
    do {
      code = _generateCode();
      final query = await _firestore
          .collection('invite_codes')
          .where('code', isEqualTo: code)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();
      exists = query.docs.isNotEmpty;
    } while (exists);

    final now = DateTime.now();
    final docRef = _firestore.collection('invite_codes').doc();

    final invite = InviteCode(
      id: docRef.id,
      code: code,
      patientId: patientId,
      createdBy: caregiverId,
      assignedRole: assignedRoles.first,
      assignedRoles: assignedRoles,
      createdAt: now,
      expiresAt: now.add(expiry),
    );

    await docRef.set(invite.toFirestore());
    return invite;
  }

  /// Redeem an invite code to link a caregiver to a patient
  Future<AppUser> redeemInviteCode({
    required String code,
    required String caregiverId,
  }) async {
    // Find the invite code
    final query = await _firestore
        .collection('invite_codes')
        .where('code', isEqualTo: code.toUpperCase().trim())
        .where('isUsed', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid or expired invite code');
    }

    final invite = InviteCode.fromFirestore(query.docs.first);

    if (invite.isExpired) {
      throw Exception('This invite code has expired');
    }

    if (invite.createdBy == caregiverId) {
      throw Exception('You cannot redeem your own invite code');
    }

    // Batch write: mark used + bidirectional link
    final batch = _firestore.batch();

    // Mark invite as used
    batch.update(
      _firestore.collection('invite_codes').doc(invite.id),
      {
        'isUsed': true,
        'usedBy': caregiverId,
        'usedAt': FieldValue.serverTimestamp(),
      },
    );

    // Add caregiverId to patient's caregiverIds
    batch.update(
      _firestore.collection('users').doc(invite.patientId),
      {
        'caregiverIds': FieldValue.arrayUnion([caregiverId]),
      },
    );

    // Add patientId to caregiver's managedUserIds + set role
    batch.update(
      _firestore.collection('caregivers').doc(caregiverId),
      {
        'managedUserIds': FieldValue.arrayUnion([invite.patientId]),
        'roleOverrides.${invite.patientId}': invite.assignedRole.value,
        'multiRoleOverrides.${invite.patientId}':
            invite.assignedRoles.map((r) => r.value).toList(),
      },
    );

    await batch.commit();

    // Return the linked patient
    final userDoc = await _firestore.collection('users').doc(invite.patientId).get();
    return AppUser.fromFirestore(userDoc);
  }

  /// Get active (unused, unexpired) invites for a patient
  Stream<List<InviteCode>> getActiveInvites(String patientId) {
    return _firestore
        .collection('invite_codes')
        .where('patientId', isEqualTo: patientId)
        .where('isUsed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InviteCode.fromFirestore(doc))
            .where((invite) => !invite.isExpired)
            .toList());
  }

  /// Revoke an invite code
  Future<void> revokeInviteCode(String codeId) async {
    await _firestore.collection('invite_codes').doc(codeId).delete();
  }

  /// Generate a share link for an invite code
  String generateShareLink(InviteCode invite) {
    return 'https://lumina.app/invite?code=${invite.code}';
  }
}

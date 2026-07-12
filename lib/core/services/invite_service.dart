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

  /// Create an invite code (only primary caregiver should call this).
  ///
  /// [patientIds] may contain several patients ("share all my patients",
  /// 2026-07-12): ONE code is generated and a separate invite doc is
  /// written per patient, so firestore.rules validates premium +
  /// primary-caregiver on each patient individually. Patients whose doc
  /// write is rejected by rules are reported back in `skippedPatientIds`
  /// (not premium / caller not their primary caregiver); throws only if
  /// no patient could be invited.
  Future<({InviteCode invite, List<String> skippedPatientIds})>
      createInviteCode({
    required List<String> patientIds,
    required String caregiverId,
    required List<CaregiverRole> assignedRoles,
    Duration expiry = const Duration(hours: 24),
  }) async {
    assert(assignedRoles.isNotEmpty && patientIds.isNotEmpty);
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
    InviteCode? first;
    final skipped = <String>[];
    for (final patientId in patientIds) {
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
      try {
        await docRef.set(invite.toFirestore());
        first ??= invite;
      } catch (_) {
        // Rules rejected: caregiver is not this patient's primary
        // caregiver, or patient is not premium.
        skipped.add(patientId);
      }
    }
    if (first == null) {
      throw Exception(
          'Could not create invite — you must be the primary caregiver '
          'of a premium patient.');
    }
    return (invite: first, skippedPatientIds: skipped);
  }

  /// Redeem an invite code, linking the caregiver to EVERY patient the
  /// code covers (multi-patient codes share one code across several
  /// invite docs). Returns the linked patients (at least one).
  Future<List<AppUser>> redeemInviteCode({
    required String code,
    required String caregiverId,
  }) async {
    // Find every unused invite doc bearing this code
    final query = await _firestore
        .collection('invite_codes')
        .where('code', isEqualTo: code.toUpperCase().trim())
        .where('isUsed', isEqualTo: false)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid or expired invite code');
    }

    final invites = query.docs
        .map(InviteCode.fromFirestore)
        .where((invite) => !invite.isExpired)
        .toList();

    if (invites.isEmpty) {
      throw Exception('This invite code has expired');
    }

    if (invites.first.createdBy == caregiverId) {
      throw Exception('You cannot redeem your own invite code');
    }

    // Batch write: mark all used + bidirectional links
    final batch = _firestore.batch();
    final caregiverUpdate = <String, dynamic>{
      'managedUserIds':
          FieldValue.arrayUnion(invites.map((i) => i.patientId).toList()),
    };

    for (final invite in invites) {
      batch.update(
        _firestore.collection('invite_codes').doc(invite.id),
        {
          'isUsed': true,
          'usedBy': caregiverId,
          'usedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.update(
        _firestore.collection('users').doc(invite.patientId),
        {
          'caregiverIds': FieldValue.arrayUnion([caregiverId]),
        },
      );
      caregiverUpdate['roleOverrides.${invite.patientId}'] =
          invite.assignedRole.value;
      caregiverUpdate['multiRoleOverrides.${invite.patientId}'] =
          invite.assignedRoles.map((r) => r.value).toList();
    }

    batch.update(
      _firestore.collection('caregivers').doc(caregiverId),
      caregiverUpdate,
    );

    await batch.commit();

    // Return the linked patients
    final patients = <AppUser>[];
    for (final invite in invites) {
      final userDoc =
          await _firestore.collection('users').doc(invite.patientId).get();
      if (userDoc.exists) {
        patients.add(AppUser.fromFirestore(userDoc));
      }
    }
    return patients;
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

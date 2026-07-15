import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/legal_terms.dart';

/// Gatekeeper for the Terms of Use / liability waiver.
///
/// THE APP MUST NOT BE USABLE BEFORE ACCEPTANCE. Enforcement point:
/// SplashScreen._navigateTo() routes EVERY destination (first-run setup,
/// patient home, caregiver login/dashboard) through [needsAcceptance];
/// if true, LegalGateScreen is shown instead and only continues after
/// [recordAcceptance] succeeds locally.
///
/// Acceptance is stored three ways:
///  1. LOCAL (authoritative for gating): SharedPreferences
///     `legal.acceptedVersion` — offline-safe, checked every launch.
///  2. AUDIT LOG: Firestore top-level `legal_acceptances` collection —
///     immutable record (who/when/version/checkboxes) for legal defense.
///  3. ACCOUNT STAMP: `legalAcceptance` map merged onto the caregiver doc
///     and (from caregiver devices) the patient user doc, so a re-installed
///     or second device can pass the gate without re-prompting a patient
///     after a caregiver has already accepted the current version.
///
/// Bumping [kTermsVersion] in legal_terms.dart re-triggers the gate for
/// everyone. Full documentation: docs/legal/LEGAL-IMPLEMENTATION.md
class LegalService {
  static const _prefsVersionKey = 'legal.acceptedVersion';
  static const _prefsAcceptedAtKey = 'legal.acceptedAtIso';
  static const _prefsSyncedKey = 'legal.remoteSyncedVersion';
  // Account stamp tracked SEPARATELY from the audit doc: on a true first
  // run the audit doc succeeds while ids are still null, and the
  // caregiver/user doc stamps must still be back-filled on a later launch
  // once accounts exist (gap found in device test 2026-07-15 — audit doc
  // had caregiverId: null and sync was marked done).
  static const _prefsStampedKey = 'legal.stampedVersion';

  /// True if the blocking gate must be shown before the app can be used.
  ///
  /// Local record wins (works offline). If the local record is missing or
  /// stale, we try the account stamp on Firestore (covers reinstalls and
  /// patient devices after a caregiver accepted a new version elsewhere).
  /// Any failure/timeout defaults to REQUIRING acceptance — the gate can
  /// never be skipped by being offline.
  static Future<bool> needsAcceptance({
    String? userId,
    String? caregiverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefsVersionKey) == kTermsVersion) {
        return false;
      }

      // Remote fallback — account already accepted current version?
      final firestore = FirebaseFirestore.instance;
      for (final ref in [
        if (caregiverId != null)
          firestore.collection('caregivers').doc(caregiverId),
        if (userId != null) firestore.collection('users').doc(userId),
      ]) {
        try {
          final snap = await ref.get().timeout(const Duration(seconds: 8));
          final legal = snap.data()?['legalAcceptance'];
          if (legal is Map && legal['version'] == kTermsVersion) {
            // Cache locally so future launches gate offline-safely.
            await prefs.setString(_prefsVersionKey, kTermsVersion);
            await prefs.setString(_prefsAcceptedAtKey,
                legal['acceptedAtLocal']?.toString() ?? '');
            await prefs.setString(_prefsSyncedKey, kTermsVersion);
            return false;
          }
        } catch (e) {
          debugPrint('LEGAL: remote acceptance check failed for $ref: $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('LEGAL: needsAcceptance failed ($e) — requiring acceptance');
      return true;
    }
  }

  /// Records acceptance. LOCAL write must succeed (throws otherwise — the
  /// gate stays up). Remote audit log + account stamps are attempted now
  /// and retried on later launches via [ensureRemoteSync] if offline.
  static Future<void> recordAcceptance({
    String? userId,
    String? caregiverId,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    // 1. Local — authoritative for the gate. Failure here throws so the
    // gate screen shows an error instead of letting the user through.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsVersionKey, kTermsVersion);
    await prefs.setString(_prefsAcceptedAtKey, nowIso);
    await prefs.remove(_prefsSyncedKey); // audit doc pending
    await prefs.remove(_prefsStampedKey); // account stamp pending

    // 2. Remote audit log + account stamps (best-effort now, retried later).
    await _syncRemote(
      prefs: prefs,
      userId: userId,
      caregiverId: caregiverId,
      acceptedAtLocal: nowIso,
    );
  }

  /// Fire-and-forget: called on every successful gate pass (see
  /// SplashScreen) so an acceptance recorded offline eventually reaches
  /// Firestore, and account stamps appear once user/caregiver ids exist
  /// (first-run acceptance happens BEFORE accounts are created).
  static Future<void> ensureRemoteSync({
    String? userId,
    String? caregiverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefsVersionKey) != kTermsVersion) return;
      final auditDone = prefs.getString(_prefsSyncedKey) == kTermsVersion;
      final stampDone = prefs.getString(_prefsStampedKey) == kTermsVersion;
      // Nothing to do only when the audit doc exists AND either the stamp
      // is done or there's still no account to stamp.
      if (auditDone && (stampDone || caregiverId == null)) return;
      await _syncRemote(
        prefs: prefs,
        userId: userId,
        caregiverId: caregiverId,
        acceptedAtLocal: prefs.getString(_prefsAcceptedAtKey) ?? '',
      );
    } catch (e) {
      debugPrint('LEGAL: ensureRemoteSync failed: $e');
    }
  }

  static Future<void> _syncRemote({
    required SharedPreferences prefs,
    required String? userId,
    required String? caregiverId,
    required String acceptedAtLocal,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final authUid = FirebaseAuth.instance.currentUser?.uid;

      final stamp = {
        'version': kTermsVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedAtLocal': acceptedAtLocal,
        'authUid': authUid,
      };

      // Immutable audit record (rules: create-only). Written once per
      // acceptance — guarded so stamp back-fills don't duplicate it.
      if (prefs.getString(_prefsSyncedKey) != kTermsVersion) {
        await firestore.collection('legal_acceptances').add({
          ...stamp,
          'caregiverId': caregiverId,
          'patientUserId': userId,
          'platform': defaultTargetPlatform.name,
          'acknowledgments': kRequiredAcknowledgments,
        }).timeout(const Duration(seconds: 10));
        await prefs.setString(_prefsSyncedKey, kTermsVersion);
      }

      // Account stamps. Patient-doc stamp only from a caregiver context —
      // users/{id} update rules require the writer to be in caregiverIds.
      // Tracked separately so it back-fills once accounts exist.
      if (caregiverId != null &&
          prefs.getString(_prefsStampedKey) != kTermsVersion) {
        await firestore
            .collection('caregivers')
            .doc(caregiverId)
            .set({'legalAcceptance': stamp}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
        if (userId != null) {
          await firestore
              .collection('users')
              .doc(userId)
              .set({'legalAcceptance': stamp}, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
        }
        await prefs.setString(_prefsStampedKey, kTermsVersion);
      }

      debugPrint('LEGAL: remote acceptance sync complete');
    } catch (e) {
      // Offline is fine — local record gates the app; retried next launch.
      debugPrint('LEGAL: remote acceptance sync deferred: $e');
    }
  }

  /// For the settings "Terms of Use" row — when this device accepted.
  static Future<String?> localAcceptanceDateIso() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefsVersionKey) != kTermsVersion) return null;
    return prefs.getString(_prefsAcceptedAtKey);
  }
}

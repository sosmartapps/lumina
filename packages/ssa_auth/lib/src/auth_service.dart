import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'sign_in_result.dart';

/// Unified authentication service for all So Smart Apps.
///
/// Supports email/password, Google Sign-In, Apple Sign-In, and TOTP MFA.
/// Apps use a single instance of this service instead of each implementing
/// their own auth logic.
///
/// ```dart
/// final authService = SSAAuthService();
/// final result = await authService.signInWithGoogle();
/// if (result.requiresMfa) {
///   // Show MFA verification screen
/// }
/// ```
class SSAAuthService {
  SSAAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The currently signed-in user (null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Email / Password ──────────────────────────────────

  /// Sign in with email and password.
  /// Returns [SignInResult] — may require MFA if TOTP is enrolled.
  Future<SignInResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return SignInResult.success(credential);
    } on FirebaseAuthMultiFactorException catch (e) {
      return SignInResult.mfaRequired(e.resolver);
    }
  }

  /// Create a new account with email, password, and display name.
  Future<UserCredential> createAccount(
    String email,
    String password,
    String name,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    return credential;
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─── Google Sign-In ────────────────────────────────────

  /// Sign in with Google.
  /// On web, uses Firebase's popup flow. On mobile, uses the google_sign_in
  /// v7 API — GoogleSignIn.instance must be initialized (serverClientId/
  /// clientId) before calling.
  Future<SignInResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final userCredential =
            await _auth.signInWithPopup(GoogleAuthProvider());
        return SignInResult.success(userCredential);
      }
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return SignInResult.success(userCredential);
    } on FirebaseAuthMultiFactorException catch (e) {
      return SignInResult.mfaRequired(e.resolver);
    }
  }

  // ─── Apple Sign-In ─────────────────────────────────────

  /// Sign in with Apple.
  /// Uses a SHA-256 nonce for secure credential exchange with Firebase.
  /// Captures the user's name on first authorization (Apple only returns it
  /// once) and writes it to the Firebase displayName if not already set.
  Future<SignInResult> signInWithApple() async {
    try {
      if (kIsWeb) {
        // Web uses Firebase's popup flow (requires the Apple provider's OAuth
        // code-flow config — Services ID, Team ID, Key — in the Firebase
        // Console). Native nonce/credential building doesn't apply on web.
        final provider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        final userCredential = await _auth.signInWithPopup(provider);
        return SignInResult.success(userCredential);
      }
      final apple = await _buildAppleCredential();
      final userCredential =
          await _auth.signInWithCredential(apple.credential);
      await _applyAppleDisplayName(userCredential.user, apple.displayName);
      return SignInResult.success(userCredential);
    } on FirebaseAuthMultiFactorException catch (e) {
      return SignInResult.mfaRequired(e.resolver);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) rethrow;
      debugPrint('Apple Sign-In error: ${e.code} – ${e.message}');
      rethrow;
    }
  }

  /// Link the current (typically anonymous) account to Apple, upgrading it
  /// to a permanent account. If the Apple identity already belongs to another
  /// account, falls back to signing in to that account.
  ///
  /// Use this — not [signInWithApple] — when upgrading a guest/anonymous
  /// session, since plain sign-in would abandon the anonymous uid.
  ///
  /// Returns the [SignInResult] for the resulting (linked or existing) user.
  /// Note: on the credential-already-in-use fallback the original anonymous
  /// uid is discarded by Firebase; callers that stored guest data under that
  /// uid must migrate it themselves.
  Future<SignInResult> linkWithApple() async {
    try {
      final apple = await _buildAppleCredential();
      final result = await _linkOrSignIn(apple.credential);
      await _applyAppleDisplayName(result.credential?.user, apple.displayName);
      return result;
    } on FirebaseAuthMultiFactorException catch (e) {
      return SignInResult.mfaRequired(e.resolver);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) rethrow;
      debugPrint('Apple link error: ${e.code} – ${e.message}');
      rethrow;
    }
  }

  /// Builds the Firebase OAuth credential for Apple.
  ///
  /// CRITICAL (flutterfire #17466): the credential is built from `idToken` +
  /// `rawNonce` ONLY. Never pass `appleCredential.authorizationCode` as
  /// `accessToken` — doing so makes firebase_auth throw
  /// `[firebase_auth/invalid-credential] ... malformed` on iOS.
  Future<
      ({
        OAuthCredential credential,
        String? displayName,
        String? authorizationCode,
      })> _buildAppleCredential() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.failed,
        message: 'Apple Sign-In did not return an identity token. '
            'Please try again.',
      );
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      signInMethod: 'apple.com',
    );

    // Apple returns the name only on the first authorization.
    final displayName = [appleCredential.givenName, appleCredential.familyName]
        .whereType<String>()
        .join(' ')
        .trim();

    return (
      credential: credential,
      displayName: displayName.isEmpty ? null : displayName,
      // Needed to revoke the Apple token on account deletion (Apple requirement).
      authorizationCode: appleCredential.authorizationCode,
    );
  }

  /// Writes [displayName] to the Firebase user if one was returned by Apple
  /// and the user doesn't already have a display name set.
  Future<void> _applyAppleDisplayName(User? user, String? displayName) async {
    if (user == null || displayName == null || displayName.isEmpty) return;
    final existing = user.displayName;
    if (existing == null || existing.isEmpty) {
      await user.updateDisplayName(displayName);
    }
  }

  /// Links [credential] to the current user, falling back to sign-in if the
  /// credential is already attached to an account or already linked.
  Future<SignInResult> _linkOrSignIn(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      return SignInResult.success(
        await _auth.signInWithCredential(credential),
      );
    }
    try {
      return SignInResult.success(await user.linkWithCredential(credential));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'credential-already-in-use':
        case 'email-already-in-use':
        case 'provider-already-linked':
          // Identity belongs to (or is already on) an account — sign in to it.
          final fallback =
              (e.credential as OAuthCredential?) ?? credential;
          return SignInResult.success(
            await _auth.signInWithCredential(fallback),
          );
        default:
          rethrow;
      }
    }
  }

  // ─── Anonymous ─────────────────────────────────────────

  /// Sign in anonymously (for initial data sync before account creation).
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Link the current (typically anonymous) account to Google, upgrading it
  /// to a permanent account. Falls back to signing in if the Google identity
  /// already belongs to another account. See [linkWithApple] for the uid note.
  Future<SignInResult> linkWithGoogle() async {
    try {
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return await _linkOrSignIn(credential);
    } on FirebaseAuthMultiFactorException catch (e) {
      return SignInResult.mfaRequired(e.resolver);
    }
  }

  // ─── MFA: TOTP ─────────────────────────────────────────

  /// Check if the current user has TOTP MFA enrolled.
  Future<bool> isMfaEnrolled() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final enrolledFactors = await user.multiFactor.getEnrolledFactors();
    return enrolledFactors.any((f) => f.factorId == 'totp');
  }

  /// Begin TOTP enrollment. Returns a [TotpSecret] with the shared secret
  /// and QR code URI for the authenticator app.
  Future<TotpSecret> startMfaEnrollment() async {
    final session = await _auth.currentUser!.multiFactor.getSession();
    final totpSecret = await TotpMultiFactorGenerator.generateSecret(session);
    return totpSecret;
  }

  /// Finalize TOTP enrollment by verifying a code from the authenticator app.
  Future<void> finalizeMfaEnrollment(
    TotpSecret secret,
    String verificationCode,
  ) async {
    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      secret,
      verificationCode,
    );
    await _auth.currentUser!.multiFactor.enroll(
      assertion,
      displayName: 'Authenticator App',
    );
  }

  /// Verify a TOTP code during sign-in (MFA challenge).
  Future<UserCredential> verifyMfaCode(
    MultiFactorResolver resolver,
    String verificationCode,
  ) async {
    final totpHint = resolver.hints.firstWhere(
      (hint) => hint is TotpMultiFactorInfo,
    );
    final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
      totpHint.uid,
      verificationCode,
    );
    return await resolver.resolveSignIn(assertion);
  }

  /// Unenroll TOTP MFA for the current user.
  Future<void> unenrollMfa() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final factors = await user.multiFactor.getEnrolledFactors();
    final totpFactor = factors.where((f) => f.factorId == 'totp').firstOrNull;
    if (totpFactor != null) {
      await user.multiFactor.unenroll(multiFactorInfo: totpFactor);
    }
  }

  // ─── Re-authentication ──────────────────────────────────

  /// True when the current user signs in with email/password (so a sensitive
  /// action like account deletion must collect their password to re-auth).
  bool get isPasswordUser =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  /// Re-authenticate the current user before a sensitive action (e.g. account
  /// deletion). Picks the provider the user signed in with. [password] is
  /// required only for email/password accounts.
  ///
  /// Apple re-auth uses the same #17466-safe credential builder as sign-in.
  /// Returns the Apple authorization code when the user re-authenticated with
  /// Apple (needed to revoke the token on deletion), otherwise null.
  Future<String?> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final providers = user.providerData.map((p) => p.providerId).toSet();

    if (providers.contains('apple.com')) {
      final apple = await _buildAppleCredential();
      await user.reauthenticateWithCredential(apple.credential);
      return apple.authorizationCode;
    } else if (providers.contains('google.com')) {
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleAccount.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: googleAuth.idToken),
      );
    } else if (providers.contains('password') &&
        password != null &&
        user.email != null) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    }
    return null;
  }

  // ─── Account Deletion ───────────────────────────────────

  /// Delete the current user's account and associated Firestore data.
  ///
  /// [writableCollections] — subcollections under `users/{uid}/` that the
  /// client has write access to and should delete before removing the account.
  /// Collections not in this list are attempted best-effort (may fail due to
  /// Firestore rules — that's expected for Cloud Functions–only collections).
  /// Delete the current user's account and Firestore data. Does NOT
  /// re-authenticate — for Apple/Google accounts use [deleteAccountWithReauth],
  /// which Firebase requires before deletion (and which revokes the Apple token).
  Future<void> deleteAccount({
    List<String> writableCollections = const [],
    List<String> readOnlyCollections = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user');
    await _deleteFirestoreData(
        user.uid, writableCollections, readOnlyCollections);
    // Delete Firebase Auth account (must be last — invalidates token)
    await user.delete();
  }

  /// App Store–compliant account deletion (Guideline 5.1.1(v)): re-authenticates,
  /// revokes the Apple token when the user signed in with Apple (required since
  /// iOS 16), removes Firestore data, then deletes the Firebase user.
  /// [password] is only needed for email/password accounts.
  Future<void> deleteAccountWithReauth({
    String? password,
    List<String> writableCollections = const [],
    List<String> readOnlyCollections = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user');

    // Fresh re-auth — user.delete() throws requires-recent-login otherwise.
    final appleAuthCode = await reauthenticate(password: password);

    // Remove Firestore data while still authenticated (rules allow it).
    await _deleteFirestoreData(
        user.uid, writableCollections, readOnlyCollections);

    // Apple requires the token to be revoked when the account is deleted.
    if (appleAuthCode != null) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthCode);
      } catch (_) {/* best-effort — don't block deletion */}
    }

    await user.delete();
  }

  /// Best-effort deletion of `users/{uid}` data. Collections the client can't
  /// write (Cloud Functions–only) fail silently — that's expected.
  Future<void> _deleteFirestoreData(
    String uid,
    List<String> writableCollections,
    List<String> readOnlyCollections,
  ) async {
    final db = FirebaseFirestore.instance;
    for (final sub in [...writableCollections, ...readOnlyCollections]) {
      try {
        final snap = await db.collection('users/$uid/$sub').limit(500).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
    try {
      await db.doc('users/$uid').delete();
    } catch (_) {}
  }

  // ─── Sign Out ──────────────────────────────────────────

  /// Sign out from Firebase and Google.
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  // ─── Private Helpers ───────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

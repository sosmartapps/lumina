import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ssa_auth/ssa_auth.dart' show SSAAuthService, SignInResult;

import '../models/caregiver.dart';
import '../models/app_user.dart';

/// Authentication service for caregivers
/// Users (patients) don't need to login - app opens directly
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Shared SSA auth (Apple + Google flows, correct nonce handling).
  final SSAAuthService _ssaAuth = SSAAuthService();

  // Current Firebase user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password (for caregivers)
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time
      if (credential.user != null) {
        await _firestore.collection('caregivers').doc(credential.user!.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Register new caregiver with email
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create caregiver profile
      if (credential.user != null) {
        final caregiver = Caregiver(
          id: credential.user!.uid,
          name: name,
          email: email,
          phoneNumber: phoneNumber,
        );

        await _firestore
            .collection('caregivers')
            .doc(credential.user!.uid)
            .set(caregiver.toFirestore());

        // Send email verification
        await credential.user!.sendEmailVerification();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in (or sign up) with Apple. Creates the caregiver profile on
  /// first sign-in. Works for both the "New" and "Sign In" flows.
  Future<UserCredential> signInWithApple({String? fallbackName}) async {
    final result = await _ssaAuth.signInWithApple();
    return _finishOAuthSignIn(result, fallbackName: fallbackName);
  }

  /// Sign in (or sign up) with Google. Creates the caregiver profile on
  /// first sign-in. Works for both the "New" and "Sign In" flows.
  Future<UserCredential> signInWithGoogle({String? fallbackName}) async {
    final result = await _ssaAuth.signInWithGoogle();
    return _finishOAuthSignIn(result, fallbackName: fallbackName);
  }

  Future<UserCredential> _finishOAuthSignIn(
    SignInResult result, {
    String? fallbackName,
  }) async {
    if (result.requiresMfa || result.credential == null) {
      throw const AuthException(
        'Sign-in could not be completed. Please try again.',
        code: 'oauth-incomplete',
      );
    }
    final user = result.credential!.user!;
    await _ensureCaregiverProfile(user, fallbackName: fallbackName);
    return result.credential!;
  }

  /// Create the caregiver Firestore doc on first OAuth sign-in, or bump
  /// lastLoginAt on subsequent ones.
  Future<void> _ensureCaregiverProfile(
    User user, {
    String? fallbackName,
  }) async {
    final docRef = _firestore.collection('caregivers').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.update({'lastLoginAt': FieldValue.serverTimestamp()});
      return;
    }

    // Apple only shares the name on the very first authorization; ssa_auth
    // applies it to displayName when available.
    final name = user.displayName?.trim();
    final caregiver = Caregiver(
      id: user.uid,
      name: (name != null && name.isNotEmpty)
          ? name
          : (fallbackName?.trim().isNotEmpty == true
              ? fallbackName!.trim()
              : 'Caregiver'),
      email: user.email ?? '',
      phoneNumber: user.phoneNumber,
    );
    await docRef.set(caregiver.toFirestore());
  }

  /// Sign in with phone number (for caregivers)
  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  /// Verify phone code
  Future<UserCredential> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
    String? name,
    String? email,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Check if caregiver profile exists, create if not
      if (userCredential.user != null) {
        final doc = await _firestore
            .collection('caregivers')
            .doc(userCredential.user!.uid)
            .get();

        if (!doc.exists && name != null) {
          final caregiver = Caregiver(
            id: userCredential.user!.uid,
            name: name,
            email: email ?? '',
            phoneNumber: userCredential.user!.phoneNumber,
          );

          await _firestore
              .collection('caregivers')
              .doc(userCredential.user!.uid)
              .set(caregiver.toFirestore());
        } else if (doc.exists) {
          await _firestore
              .collection('caregivers')
              .doc(userCredential.user!.uid)
              .update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Get caregiver profile
  Future<Caregiver?> getCaregiverProfile() async {
    if (currentUser == null) return null;

    final doc =
        await _firestore.collection('caregivers').doc(currentUser!.uid).get();

    if (doc.exists) {
      return Caregiver.fromFirestore(doc);
    }
    return null;
  }

  /// Update caregiver profile
  Future<void> updateCaregiverProfile(Caregiver caregiver) async {
    await _firestore
        .collection('caregivers')
        .doc(caregiver.id)
        .update(caregiver.toFirestore());
  }

  /// Link caregiver to user
  Future<void> linkCaregiverToUser({
    required String caregiverId,
    required String userId,
    bool asPrimary = false,
  }) async {
    final batch = _firestore.batch();

    // Add user to caregiver's managed users
    batch.update(
      _firestore.collection('caregivers').doc(caregiverId),
      {
        'managedUserIds': FieldValue.arrayUnion([userId]),
      },
    );

    // Add caregiver to user's caregivers
    final userUpdate = <String, dynamic>{
      'caregiverIds': FieldValue.arrayUnion([caregiverId]),
    };
    if (asPrimary) {
      userUpdate['primaryCaregiverId'] = caregiverId;
    }
    batch.update(
      _firestore.collection('users').doc(userId),
      userUpdate,
    );

    await batch.commit();
  }

  /// Create new user (patient) - called during initial setup
  Future<AppUser> createUser({
    required String name,
    String? preferredName,
    String? phoneNumber,
    required String primaryCaregiverId,
  }) async {
    final docRef = _firestore.collection('users').doc();

    final user = AppUser(
      id: docRef.id,
      name: name,
      preferredName: preferredName,
      phoneNumber: phoneNumber,
      caregiverIds: [primaryCaregiverId],
      primaryCaregiverId: primaryCaregiverId,
    );

    await docRef.set(user.toFirestore());

    // Link caregiver
    await linkCaregiverToUser(
      caregiverId: primaryCaregiverId,
      userId: docRef.id,
      asPrimary: true,
    );

    return user;
  }

  /// Get user by ID
  Future<AppUser?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }
    return null;
  }

  /// Update user profile
  Future<void> updateUser(AppUser user) async {
    await _firestore.collection('users').doc(user.id).update(user.toFirestore());
  }

  /// Get users managed by caregiver
  Stream<List<AppUser>> getManagedUsers(String caregiverId) {
    return _firestore
        .collection('users')
        .where('caregiverIds', arrayContains: caregiverId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Handle Firebase auth exceptions by wrapping in a typed Exception
  /// so callers can `catch (AuthException e)` cleanly.
  AuthException _handleAuthException(FirebaseAuthException e) {
    final message = switch (e.code) {
      'weak-password' => 'The password provided is too weak.',
      'email-already-in-use' => 'An account already exists for this email.',
      'user-not-found' => 'No account found for this email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-email' => 'Please enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'invalid-verification-code' => 'Invalid verification code.',
      _ => e.message ?? 'An error occurred. Please try again.',
    };
    return AuthException(message, code: e.code);
  }
}

/// Typed exception for authentication errors
class AuthException implements Exception {
  final String message;
  final String code;

  const AuthException(this.message, {required this.code});

  @override
  String toString() => 'AuthException($code): $message';
}

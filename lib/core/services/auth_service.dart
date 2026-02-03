import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caregiver.dart';
import '../models/app_user.dart';

/// Authentication service for caregivers
/// Users (patients) don't need to login - app opens directly
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    String? phoneNumber,
    required String primaryCaregiverId,
  }) async {
    final docRef = _firestore.collection('users').doc();

    final user = AppUser(
      id: docRef.id,
      name: name,
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

  /// Handle Firebase auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}

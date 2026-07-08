import 'package:firebase_auth/firebase_auth.dart';

/// Possible authentication states.
enum AuthStatus {
  /// No user is signed in.
  unauthenticated,

  /// Sign-in succeeded but TOTP MFA verification is required.
  mfaPending,

  /// User is fully authenticated.
  authenticated,
}

/// Immutable representation of the current authentication state.
///
/// Used by [AuthNotifier] and consumed by the UI to decide which
/// screen to show (sign-in, MFA, or main app).
class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.userId,
    this.displayName,
    this.email,
    this.photoUrl,
    this.mfaResolver,
  });

  final AuthStatus status;
  final String? userId;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final MultiFactorResolver? mfaResolver;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isMfaPending => status == AuthStatus.mfaPending;

  /// Create an authenticated state from a Firebase [User].
  factory AuthState.fromFirebaseUser(User? user) {
    if (user == null) return const AuthState();
    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? displayName,
    String? email,
    String? photoUrl,
    MultiFactorResolver? mfaResolver,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      mfaResolver: mfaResolver ?? this.mfaResolver,
    );
  }
}

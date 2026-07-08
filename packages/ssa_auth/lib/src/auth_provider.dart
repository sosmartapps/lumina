import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'auth_state.dart';
import 'secure_storage_service.dart';

/// Provides the shared [SSAAuthService] instance.
final ssaAuthServiceProvider = Provider<SSAAuthService>((ref) {
  return SSAAuthService();
});

/// Provides the shared [SSASecureStorage] instance.
final ssaSecureStorageProvider = Provider<SSASecureStorage>((ref) {
  return SSASecureStorage();
});

/// Manages authentication state for any SSA app.
///
/// Listens to Firebase auth state changes and exposes [AuthState] which
/// the app's router can use to decide which screen to show.
///
/// ```dart
/// // In your router:
/// final auth = ref.watch(ssaAuthProvider);
/// if (!auth.isAuthenticated) return '/sign-in';
/// if (auth.isMfaPending) return '/mfa-verify';
/// return '/home';
/// ```
final ssaAuthProvider =
    NotifierProvider<SSAAuthNotifier, AuthState>(SSAAuthNotifier.new);

/// Convenience provider for checking if a user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(ssaAuthProvider).isAuthenticated;
});

/// Convenience provider for the current user's ID.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(ssaAuthProvider).userId;
});

/// Notifier that manages auth state transitions.
///
/// Handles the full auth lifecycle: sign-in (with optional MFA),
/// account creation, sign-out, and account deletion.
class SSAAuthNotifier extends Notifier<AuthState> {
  late SSAAuthService _authService;
  late SSASecureStorage _secureStorage;
  StreamSubscription<User?>? _authSubscription;

  @override
  AuthState build() {
    _authService = ref.watch(ssaAuthServiceProvider);
    _secureStorage = ref.watch(ssaSecureStorageProvider);

    _listenToAuthChanges();

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    // Use the synchronous currentUser if already available (e.g. after
    // sign-out → sign-in cycle where Firebase Auth restores the session
    // before Riverpod rebuilds). This prevents downstream providers from
    // seeing a transient unauthenticated state and clearing/resetting data.
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      return AuthState.fromFirebaseUser(currentUser);
    }

    return const AuthState();
  }

  void _listenToAuthChanges() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      // Don't override MFA pending state — auth stream fires before
      // MFA is resolved for social sign-ins.
      if (state.status != AuthStatus.mfaPending) {
        state = AuthState.fromFirebaseUser(user);
      }
    });
  }

  /// Sign in with Google. May transition to MFA pending.
  Future<void> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    if (result.requiresMfa) {
      state = AuthState(
        status: AuthStatus.mfaPending,
        mfaResolver: result.resolver,
      );
    } else if (result.credential?.user != null) {
      state = AuthState.fromFirebaseUser(result.credential!.user!);
    }
  }

  /// Sign in with Apple. May transition to MFA pending.
  Future<void> signInWithApple() async {
    final result = await _authService.signInWithApple();
    if (result.requiresMfa) {
      state = AuthState(
        status: AuthStatus.mfaPending,
        mfaResolver: result.resolver,
      );
    } else if (result.credential?.user != null) {
      state = AuthState.fromFirebaseUser(result.credential!.user!);
    }
  }

  /// Link the current (anonymous) account to Apple, upgrading it to a
  /// permanent account. May transition to MFA pending.
  Future<void> linkWithApple() async {
    final result = await _authService.linkWithApple();
    if (result.requiresMfa) {
      state = AuthState(
        status: AuthStatus.mfaPending,
        mfaResolver: result.resolver,
      );
    } else if (result.credential?.user != null) {
      state = AuthState.fromFirebaseUser(result.credential!.user!);
    }
  }

  /// Link the current (anonymous) account to Google, upgrading it to a
  /// permanent account. May transition to MFA pending.
  Future<void> linkWithGoogle() async {
    final result = await _authService.linkWithGoogle();
    if (result.requiresMfa) {
      state = AuthState(
        status: AuthStatus.mfaPending,
        mfaResolver: result.resolver,
      );
    } else if (result.credential?.user != null) {
      state = AuthState.fromFirebaseUser(result.credential!.user!);
    }
  }

  /// Sign in with email and password. May transition to MFA pending.
  Future<void> signInWithEmail(String email, String password) async {
    final result = await _authService.signInWithEmail(email, password);
    if (result.requiresMfa) {
      state = AuthState(
        status: AuthStatus.mfaPending,
        mfaResolver: result.resolver,
      );
    } else if (result.credential?.user != null) {
      state = AuthState.fromFirebaseUser(result.credential!.user!);
    }
  }

  /// Verify TOTP code during MFA challenge.
  Future<void> verifyMfaCode(String code) async {
    if (state.mfaResolver == null) {
      throw StateError('No MFA resolver available');
    }
    final credential =
        await _authService.verifyMfaCode(state.mfaResolver!, code);
    // Build state from the resolved credential so downstream providers
    // immediately see the real userId and displayName — no transient
    // null-userId window between MFA completion and auth stream firing.
    final user = credential.user ?? _authService.currentUser;
    if (user != null) {
      state = AuthState.fromFirebaseUser(user);
    } else {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        mfaResolver: null,
      );
    }
  }

  /// Cancel MFA verification and return to sign-in.
  void cancelMfa() {
    state = const AuthState();
  }

  /// Create a new account with email, password, and display name.
  Future<void> createAccount(
    String email,
    String password,
    String name,
  ) async {
    await _authService.createAccount(email, password, name);
  }

  /// Delete the current user's account and clear all local storage.
  Future<void> deleteAccount({
    List<String> writableCollections = const [],
    List<String> readOnlyCollections = const [],
  }) async {
    await _secureStorage.clearAll();
    await _authService.deleteAccount(
      writableCollections: writableCollections,
      readOnlyCollections: readOnlyCollections,
    );
  }

  /// Whether the current user signed in with email/password (needs a
  /// password for re-authentication before deletion).
  bool get isPasswordUser => _authService.isPasswordUser;

  /// App Store–compliant account deletion (Guideline 5.1.1(v)):
  /// re-authenticates, revokes the Apple token for Apple users, deletes
  /// Firestore data, then deletes the Firebase user. Local secure storage
  /// is cleared only AFTER deletion succeeds, so a cancelled re-auth
  /// doesn't wipe the user's integration tokens.
  Future<void> deleteAccountWithReauth({
    String? password,
    List<String> writableCollections = const [],
    List<String> readOnlyCollections = const [],
  }) async {
    await _authService.deleteAccountWithReauth(
      password: password,
      writableCollections: writableCollections,
      readOnlyCollections: readOnlyCollections,
    );
    await _secureStorage.clearAll();
  }

  /// Sign out and clear all local secure storage.
  Future<void> signOut() async {
    await _secureStorage.clearAll();
    await _authService.signOut();
  }
}

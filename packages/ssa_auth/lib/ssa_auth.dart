/// Unified authentication package for So Smart Apps LLC.
///
/// Provides Google, Apple, and Email sign-in with optional TOTP MFA,
/// Riverpod state management, secure token storage, and account
/// deletion with Firestore cascade — used by all SSA Flutter apps.
library ssa_auth;

// Auth service
export 'src/auth_service.dart';
export 'src/sign_in_result.dart';

// Secure storage
export 'src/secure_storage_service.dart';

// Riverpod providers
export 'src/auth_provider.dart';
export 'src/auth_state.dart';

// Account deletion
export 'src/account_deletion_service.dart';

// Backward-compatible aliases for apps migrating from local auth code.
// These let existing code reference the old class names without renaming.
export 'src/compat.dart';

/// Backward-compatible type aliases for apps migrating from local auth code.
///
/// Use the `SSA`-prefixed names in new code. These aliases exist so that
/// existing integration services, providers, etc. can switch to the shared
/// package with only an import change — no class renaming needed.
library;

import 'auth_service.dart';
import 'secure_storage_service.dart';

/// Alias so `SecureStorageService` still works after swapping imports.
typedef SecureStorageService = SSASecureStorage;

/// Alias so `AuthService` still works after swapping imports.
typedef AuthService = SSAAuthService;

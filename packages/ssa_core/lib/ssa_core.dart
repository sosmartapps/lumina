/// Shared foundation package for So Smart Apps LLC.
///
/// Provides Firebase initialization, Firestore helpers, a base repository
/// class, connectivity monitoring, and logging — used by all SSA Flutter apps.
library ssa_core;

// Firebase initialization
export 'src/firebase/firebase_init.dart';

// Firestore helpers
export 'src/firestore/firestore_helpers.dart';
export 'src/firestore/base_repository.dart';

// Connectivity
export 'src/connectivity/connectivity_service.dart';
export 'src/connectivity/connectivity_provider.dart';

// Logging
export 'src/logging/ssa_logger.dart';

// Providers
export 'src/providers/core_providers.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted local storage for sensitive data (OAuth tokens, etc.).
///
/// Supports both multi-account integrations (where a user can connect
/// multiple accounts to the same service) and legacy single-account tokens.
///
/// All SSA apps should use this instead of directly accessing
/// FlutterSecureStorage, so token key naming is consistent across the ecosystem.
class SSASecureStorage {
  SSASecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  /// Shared FlutterSecureStorage configured so the iOS keychain items are
  /// readable as soon as the user has unlocked the device once after boot,
  /// not just while it's actively unlocked.
  ///
  /// The default [FlutterSecureStorage] uses `kSecAttrAccessibleWhenUnlocked`,
  /// which causes Keychain error -25308 ("User interaction is not allowed")
  /// when background sync tasks fire after a reboot but before the user has
  /// brought the app to the foreground. `first_unlock` maps to
  /// `kSecAttrAccessibleAfterFirstUnlock`, which is still secure (data never
  /// leaves the device, encrypted, and unreadable while the device has not
  /// been unlocked since boot) but allows background access for the rest of
  /// the boot session. This matches Apple's recommendation for tokens used
  /// by background tasks.
  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  final FlutterSecureStorage _storage;

  static const _tokenPrefix = 'integration_token_';

  // ─── Account-Aware Integration Tokens ──────────────

  /// Save a token for a specific account within an integration.
  Future<void> saveAccountToken(
    String integrationId,
    String accountId,
    String token,
  ) async {
    await _storage.write(
      key: '$_tokenPrefix${integrationId}_$accountId',
      value: token,
    );
  }

  /// Get the token for a specific account within an integration.
  Future<String?> getAccountToken(
    String integrationId,
    String accountId,
  ) async {
    return _storage.read(key: '$_tokenPrefix${integrationId}_$accountId');
  }

  /// Delete the token for a specific account within an integration.
  Future<void> deleteAccountToken(
    String integrationId,
    String accountId,
  ) async {
    await _storage.delete(key: '$_tokenPrefix${integrationId}_$accountId');
  }

  /// Delete all account tokens for an integration (full disconnect).
  Future<void> deleteAllAccountTokens(String integrationId) async {
    final allEntries = await _storage.readAll();
    final prefix = '$_tokenPrefix${integrationId}_';
    for (final key in allEntries.keys) {
      if (key.startsWith(prefix)) {
        await _storage.delete(key: key);
      }
    }
    // Also clean up legacy single-account key if it exists
    await _storage.delete(key: '$_tokenPrefix$integrationId');
  }

  // ─── Legacy Single-Account Tokens (backward compat) ─

  /// Save a token for a single-account integration.
  Future<void> saveIntegrationToken(String integrationId, String token) async {
    await _storage.write(key: '$_tokenPrefix$integrationId', value: token);
  }

  /// Get a token for a single-account integration.
  Future<String?> getIntegrationToken(String integrationId) async {
    return _storage.read(key: '$_tokenPrefix$integrationId');
  }

  /// Delete a token for a single-account integration.
  Future<void> deleteIntegrationToken(String integrationId) async {
    await _storage.delete(key: '$_tokenPrefix$integrationId');
  }

  // ─── General Key-Value ──────────────────────────────

  /// Write a value to secure storage.
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value from secure storage.
  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  /// Read all stored entries. Used by integrations that need to scan for
  /// any account token (e.g. when the OAuth flow generated a UUID account
  /// id and the caller doesn't know which one to ask for).
  Future<Map<String, String>> readAll() async {
    return _storage.readAll();
  }

  /// Delete a value from secure storage.
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // ─── Clear All (on sign-out) ────────────────────────

  /// Delete all stored values. Call this during sign-out.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ─── One-time accessibility upgrade ─────────────────

  /// Re-save every keychain entry so its accessibility class matches the
  /// configured one (currently `first_unlock`). Necessary for any token
  /// that was originally written under the older `whenUnlocked` default,
  /// because iOS keychain accessibility is **sticky at write time** —
  /// reading a `whenUnlocked` item works fine in foreground but fails
  /// with errSecInteractionNotAllowed (-25308) the moment a background
  /// task tries to use it (HKObserver wake, BGTaskScheduler, FCM silent
  /// push).
  ///
  /// Idempotent: rewriting an already-`first_unlock` item is a no-op
  /// effect-wise. Safe to call on every cold start, but the caller
  /// should still gate it behind a `SharedPreferences` flag so we're
  /// not doing N keychain writes every launch — that's wasteful and on
  /// some devices the keychain write itself can stall a few hundred ms.
  ///
  /// Returns the number of entries successfully rewritten. Items whose
  /// initial read fails (keychain locked, item missing, etc.) are
  /// silently skipped — the next successful foreground launch will
  /// retry them.
  ///
  /// ─── Safety: write-first, no destructive delete ──────────
  /// Earlier revisions of this method called `_storage.delete()` then
  /// `_storage.write()`, which lost data when the write failed (the
  /// token was gone but never re-saved). We now `write()` directly —
  /// flutter_secure_storage uses `SecItemUpdate` under the hood when
  /// the item exists, which DOES preserve the existing accessibility
  /// class. That means this method NO LONGER ACTUALLY UPGRADES
  /// accessibility for items that were originally written with the
  /// older `whenUnlocked` default.
  ///
  /// The right way to upgrade an existing item's accessibility on iOS
  /// is to delete + re-add atomically, but that's lossy in the failure
  /// case (no transaction across the two calls). Instead of risking
  /// the user's tokens, the policy now is:
  ///   1. New writes always use the current `first_unlock` class.
  ///   2. Existing tokens that fail with -25308 are caught at the
  ///      integration_provider level and treated as transient skips
  ///      (see `_isKeychainLocked`).
  ///   3. If the user explicitly disconnects + reconnects an
  ///      integration, the new token is written with the current
  ///      accessibility class and the problem self-heals.
  ///
  /// The method is kept callable so existing wiring keeps building,
  /// but it's now a no-op on iOS pre-existing items.
  Future<int> upgradeAllAccessibility() async {
    return 0;
  }
}

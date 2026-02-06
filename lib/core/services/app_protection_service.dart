import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Service for protecting the app from accidental deletion or exit
/// Implements Device Admin (Android), Kiosk Mode, and PIN protection
class AppProtectionService {
  static const MethodChannel _channel = MethodChannel('com.carecompanion/protection');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Protection states
  static bool _isDeviceAdminEnabled = false;
  static bool _isKioskModeEnabled = false;
  static bool _isAppPinned = false;

  // Getters
  static bool get isDeviceAdminEnabled => _isDeviceAdminEnabled;
  static bool get isKioskModeEnabled => _isKioskModeEnabled;
  static bool get isAppPinned => _isAppPinned;

  /// Initialize protection service
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await _checkDeviceAdminStatus();
      await _checkKioskModeStatus();
    }
  }

  /// Check if device admin is enabled (Android)
  static Future<bool> _checkDeviceAdminStatus() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('isDeviceAdminEnabled');
      _isDeviceAdminEnabled = result ?? false;
      return _isDeviceAdminEnabled;
    } catch (e) {
      debugPrint('Error checking device admin: $e');
      return false;
    }
  }

  /// Check if kiosk mode is enabled
  static Future<bool> _checkKioskModeStatus() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('isKioskModeEnabled');
      _isKioskModeEnabled = result ?? false;
      return _isKioskModeEnabled;
    } catch (e) {
      debugPrint('Error checking kiosk mode: $e');
      return false;
    }
  }

  /// Request device admin permission (Android)
  /// This allows the app to prevent uninstallation
  static Future<bool> requestDeviceAdmin() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('requestDeviceAdmin');
      _isDeviceAdminEnabled = result ?? false;
      return _isDeviceAdminEnabled;
    } catch (e) {
      debugPrint('Error requesting device admin: $e');
      return false;
    }
  }

  /// Remove device admin (requires caregiver PIN)
  static Future<bool> removeDeviceAdmin() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('removeDeviceAdmin');
      if (result == true) {
        _isDeviceAdminEnabled = false;
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error removing device admin: $e');
      return false;
    }
  }

  /// Enable kiosk mode (pins app to screen, Android)
  static Future<bool> enableKioskMode() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('enableKioskMode');
      _isKioskModeEnabled = result ?? false;
      _isAppPinned = _isKioskModeEnabled;
      return _isKioskModeEnabled;
    } catch (e) {
      debugPrint('Error enabling kiosk mode: $e');
      return false;
    }
  }

  /// Disable kiosk mode (requires caregiver authentication)
  static Future<bool> disableKioskMode() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('disableKioskMode');
      if (result == true) {
        _isKioskModeEnabled = false;
        _isAppPinned = false;
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error disabling kiosk mode: $e');
      return false;
    }
  }

  /// Start screen pinning (simpler alternative to kiosk mode)
  static Future<bool> startScreenPinning() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('startScreenPinning');
      _isAppPinned = result ?? false;
      return _isAppPinned;
    } catch (e) {
      debugPrint('Error starting screen pinning: $e');
      return false;
    }
  }

  /// Stop screen pinning
  static Future<bool> stopScreenPinning() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('stopScreenPinning');
      if (result == true) {
        _isAppPinned = false;
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error stopping screen pinning: $e');
      return false;
    }
  }

  // Rate limiting constants
  static const int _maxPinAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Save protection settings for a user
  static Future<void> saveProtectionSettings({
    required String userId,
    required bool deviceAdminEnabled,
    required bool kioskModeEnabled,
    required bool screenPinningEnabled,
    String? caregiverPin,
  }) async {
    final pinData = caregiverPin != null ? _hashPin(caregiverPin) : null;
    await _firestore.collection('users').doc(userId).update({
      'protectionSettings': {
        'deviceAdminEnabled': deviceAdminEnabled,
        'kioskModeEnabled': kioskModeEnabled,
        'screenPinningEnabled': screenPinningEnabled,
        'caregiverPinHash': pinData?['hash'],
        'caregiverPinSalt': pinData?['salt'],
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  /// Get protection settings for a user
  static Future<Map<String, dynamic>?> getProtectionSettings(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['protectionSettings'] as Map<String, dynamic>?;
  }

  /// Verify caregiver PIN with rate limiting
  static Future<bool> verifyCaregiverPin(String userId, String pin) async {
    final settings = await getProtectionSettings(userId);
    if (settings == null || settings['caregiverPinHash'] == null) {
      return true; // No PIN set, allow access
    }

    // Check rate limiting
    final failedAttempts = settings['failedPinAttempts'] ?? 0;
    final lastFailedAt = settings['lastFailedPinAt'] as Timestamp?;
    if (failedAttempts >= _maxPinAttempts && lastFailedAt != null) {
      final lockoutEnd = lastFailedAt.toDate().add(_lockoutDuration);
      if (DateTime.now().isBefore(lockoutEnd)) {
        debugPrint('PIN locked out until $lockoutEnd');
        return false;
      }
      // Lockout expired, reset attempts
      await _firestore.collection('users').doc(userId).update({
        'protectionSettings.failedPinAttempts': 0,
      });
    }

    final salt = settings['caregiverPinSalt'] as String?;
    final storedHash = settings['caregiverPinHash'] as String;
    final bool isValid;

    if (salt != null) {
      // New salted SHA-256 verification
      final hash = _hashPinWithSalt(pin, salt);
      isValid = storedHash == hash;
    } else {
      // Legacy: migrate on next setCaregiverPin call
      isValid = storedHash == _legacyHashPin(pin);
    }

    if (!isValid) {
      await _firestore.collection('users').doc(userId).update({
        'protectionSettings.failedPinAttempts': FieldValue.increment(1),
        'protectionSettings.lastFailedPinAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Reset failed attempts on success
      if (failedAttempts > 0) {
        await _firestore.collection('users').doc(userId).update({
          'protectionSettings.failedPinAttempts': 0,
        });
      }
    }

    return isValid;
  }

  /// Set caregiver PIN for protection features
  static Future<void> setCaregiverPin(String userId, String pin) async {
    final pinData = _hashPin(pin);
    await _firestore.collection('users').doc(userId).update({
      'protectionSettings.caregiverPinHash': pinData['hash'],
      'protectionSettings.caregiverPinSalt': pinData['salt'],
      'protectionSettings.failedPinAttempts': 0,
      'protectionSettings.updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Generate a random 32-byte salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Hash PIN with SHA-256 and a random salt
  static Map<String, String> _hashPin(String pin) {
    final salt = _generateSalt();
    return {
      'hash': _hashPinWithSalt(pin, salt),
      'salt': salt,
    };
  }

  /// Hash PIN with SHA-256 using a provided salt
  static String _hashPinWithSalt(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Legacy hash for backwards compatibility during migration
  static String _legacyHashPin(String pin) {
    int hash = 0;
    for (int i = 0; i < pin.length; i++) {
      hash = ((hash << 5) - hash) + pin.codeUnitAt(i);
      hash = hash & hash;
    }
    return hash.toString();
  }

  /// Check if running on a supported platform for protection features
  static bool get isProtectionSupported => Platform.isAndroid;

  /// Get protection status summary
  static Map<String, bool> getProtectionStatus() {
    return {
      'deviceAdmin': _isDeviceAdminEnabled,
      'kioskMode': _isKioskModeEnabled,
      'screenPinning': _isAppPinned,
      'supported': isProtectionSupported,
    };
  }
}

/// Protection settings model
class ProtectionSettings {
  final bool deviceAdminEnabled;
  final bool kioskModeEnabled;
  final bool screenPinningEnabled;
  final bool hasCaregiverPin;
  final DateTime? updatedAt;

  ProtectionSettings({
    this.deviceAdminEnabled = false,
    this.kioskModeEnabled = false,
    this.screenPinningEnabled = false,
    this.hasCaregiverPin = false,
    this.updatedAt,
  });

  factory ProtectionSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ProtectionSettings();

    return ProtectionSettings(
      deviceAdminEnabled: map['deviceAdminEnabled'] ?? false,
      kioskModeEnabled: map['kioskModeEnabled'] ?? false,
      screenPinningEnabled: map['screenPinningEnabled'] ?? false,
      hasCaregiverPin: map['caregiverPinHash'] != null,
      updatedAt: map['updatedAt']?.toDate(),
    );
  }
}

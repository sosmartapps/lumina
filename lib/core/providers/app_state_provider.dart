import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app-wide state
class AppStateProvider with ChangeNotifier {
  bool _isInitialized = false;
  bool _isSetupComplete = false;
  bool _isCaregiverMode = false;
  String? _currentUserId;
  String? _currentCaregiverId;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSetupComplete => _isSetupComplete;
  bool get isCaregiverMode => _isCaregiverMode;
  String? get currentUserId => _currentUserId;
  String? get currentCaregiverId => _currentCaregiverId;

  /// Initialize app state from shared preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    _isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
    _isCaregiverMode = prefs.getBool('isCaregiverMode') ?? false;
    _currentUserId = prefs.getString('currentUserId');
    _currentCaregiverId = prefs.getString('currentCaregiverId');

    _isInitialized = true;
    notifyListeners();
  }

  /// Set setup as complete
  Future<void> setSetupComplete({
    required String userId,
    String? caregiverId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isSetupComplete', true);
    await prefs.setString('currentUserId', userId);
    if (caregiverId != null) {
      await prefs.setString('currentCaregiverId', caregiverId);
    }

    _isSetupComplete = true;
    _currentUserId = userId;
    _currentCaregiverId = caregiverId;
    notifyListeners();
  }

  /// Switch to caregiver mode
  Future<void> setCaregiverMode(bool isCaregiver, {String? caregiverId}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isCaregiverMode', isCaregiver);
    if (caregiverId != null) {
      await prefs.setString('currentCaregiverId', caregiverId);
    }

    _isCaregiverMode = isCaregiver;
    _currentCaregiverId = caregiverId;
    notifyListeners();
  }

  /// Clear all stored data (for logout/reset)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isSetupComplete = false;
    _isCaregiverMode = false;
    _currentUserId = null;
    _currentCaregiverId = null;
    notifyListeners();
  }

  /// Update current user ID
  Future<void> setCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUserId', userId);
    _currentUserId = userId;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/reminder.dart';
import '../models/medication.dart';
import '../models/geo_zone.dart';

/// Provider for managing user data
class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _user;
  List<Reminder> _reminders = [];
  List<Medication> _medications = [];
  List<GeoZone> _geoZones = [];
  bool _isLoading = false;

  // Getters
  AppUser? get user => _user;
  List<Reminder> get reminders => _reminders;
  List<Medication> get medications => _medications;
  List<GeoZone> get geoZones => _geoZones;
  bool get isLoading => _isLoading;
  bool get hasUser => _user != null;

  /// Load user data
  Future<void> loadUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _user = AppUser.fromFirestore(doc);
        await _loadUserData(userId);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Listen to user changes
  void listenToUser(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((doc) {
      if (doc.exists) {
        _user = AppUser.fromFirestore(doc);
        notifyListeners();
      }
    });

    _listenToReminders(userId);
    _listenToMedications(userId);
    _listenToGeoZones(userId);
  }

  Future<void> _loadUserData(String userId) async {
    // Load reminders
    final remindersSnapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    _reminders =
        remindersSnapshot.docs.map((doc) => Reminder.fromFirestore(doc)).toList();

    // Load medications
    final medicationsSnapshot = await _firestore
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    _medications = medicationsSnapshot.docs
        .map((doc) => Medication.fromFirestore(doc))
        .toList();

    // Load geo zones
    final zonesSnapshot = await _firestore
        .collection('geo_zones')
        .where('userId', isEqualTo: userId)
        .get();

    _geoZones =
        zonesSnapshot.docs.map((doc) => GeoZone.fromFirestore(doc)).toList();
  }

  void _listenToReminders(String userId) {
    _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledTime')
        .snapshots()
        .listen((snapshot) {
      _reminders =
          snapshot.docs.map((doc) => Reminder.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  void _listenToMedications(String userId) {
    _firestore
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _medications =
          snapshot.docs.map((doc) => Medication.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  void _listenToGeoZones(String userId) {
    _firestore
        .collection('geo_zones')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _geoZones =
          snapshot.docs.map((doc) => GeoZone.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  /// Update user
  Future<void> updateUser(AppUser user) async {
    await _firestore.collection('users').doc(user.id).update(user.toFirestore());
    _user = user;
    notifyListeners();
  }

  /// Add saved location
  Future<void> addSavedLocation(SavedLocation location) async {
    if (_user == null) return;

    final updatedLocations = [..._user!.savedLocations, location];
    final updatedUser = _user!.copyWith(savedLocations: updatedLocations);

    await updateUser(updatedUser);
  }

  /// Remove saved location
  Future<void> removeSavedLocation(String locationId) async {
    if (_user == null) return;

    final updatedLocations =
        _user!.savedLocations.where((l) => l.id != locationId).toList();
    final updatedUser = _user!.copyWith(savedLocations: updatedLocations);

    await updateUser(updatedUser);
  }

  /// Add emergency contact
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (_user == null) return;

    final updatedContacts = [..._user!.emergencyContacts, contact];
    final updatedUser = _user!.copyWith(emergencyContacts: updatedContacts);

    await updateUser(updatedUser);
  }

  /// Remove emergency contact
  Future<void> removeEmergencyContact(String contactId) async {
    if (_user == null) return;

    final updatedContacts =
        _user!.emergencyContacts.where((c) => c.id != contactId).toList();
    final updatedUser = _user!.copyWith(emergencyContacts: updatedContacts);

    await updateUser(updatedUser);
  }

  /// Update user settings
  Future<void> updateSettings(UserSettings settings) async {
    if (_user == null) return;

    final updatedUser = _user!.copyWith(settings: settings);
    await updateUser(updatedUser);
  }

  /// Get today's reminders (repeat-aware — see Reminder.occursOn)
  List<Reminder> getTodayReminders() {
    final now = DateTime.now();
    return _reminders
        .where((r) => r.isActive && r.occursOn(now))
        .toList();
  }

  /// Get upcoming medications
  List<Map<String, dynamic>> getUpcomingMedications() {
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];

    for (final medication in _medications) {
      for (final schedule in medication.schedules) {
        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          schedule.hour,
          schedule.minute,
        );

        // Check if scheduled for today
        if (schedule.days == null || schedule.days!.contains(now.weekday)) {
          if (scheduledTime.isAfter(now)) {
            upcoming.add({
              'medication': medication,
              'schedule': schedule,
              'scheduledTime': scheduledTime,
            });
          }
        }
      }
    }

    upcoming.sort((a, b) =>
        (a['scheduledTime'] as DateTime).compareTo(b['scheduledTime'] as DateTime));

    return upcoming;
  }

  /// Clear provider data
  void clear() {
    _user = null;
    _reminders = [];
    _medications = [];
    _geoZones = [];
    notifyListeners();
  }
}

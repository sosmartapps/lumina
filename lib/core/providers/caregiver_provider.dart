import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caregiver.dart';
import '../models/app_user.dart';
import '../models/medication.dart';
import '../models/geo_zone.dart';

/// Provider for managing caregiver data and their managed users
class CaregiverProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Caregiver? _caregiver;
  List<AppUser> _managedUsers = [];
  AppUser? _selectedUser;
  bool _isLoading = false;

  // Getters
  Caregiver? get caregiver => _caregiver;
  List<AppUser> get managedUsers => _managedUsers;
  AppUser? get selectedUser => _selectedUser;
  bool get isLoading => _isLoading;
  bool get hasCaregiver => _caregiver != null;

  /// Load caregiver data
  Future<void> loadCaregiver(String caregiverId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('caregivers').doc(caregiverId).get();
      if (doc.exists) {
        _caregiver = Caregiver.fromFirestore(doc);
        await _loadManagedUsers();
      }
    } catch (e) {
      debugPrint('Error loading caregiver: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Listen to caregiver and managed users
  void listenToCaregiver(String caregiverId) {
    _firestore
        .collection('caregivers')
        .doc(caregiverId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _caregiver = Caregiver.fromFirestore(doc);
        _loadManagedUsers();
        notifyListeners();
      }
    });
  }

  /// Load managed users
  Future<void> _loadManagedUsers() async {
    if (_caregiver == null || _caregiver!.managedUserIds.isEmpty) {
      _managedUsers = [];
      return;
    }

    final users = <AppUser>[];
    for (final userId in _caregiver!.managedUserIds) {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        users.add(AppUser.fromFirestore(doc));
      }
    }

    _managedUsers = users;

    // Auto-select first user if none selected
    if (_selectedUser == null && _managedUsers.isNotEmpty) {
      _selectedUser = _managedUsers.first;
    }

    notifyListeners();
  }

  /// Select a user to manage
  void selectUser(AppUser user) {
    _selectedUser = user;
    notifyListeners();
  }

  /// Select user by ID
  void selectUserById(String userId) {
    _selectedUser = _managedUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => _managedUsers.first,
    );
    notifyListeners();
  }

  /// Update caregiver profile
  Future<void> updateCaregiver(Caregiver caregiver) async {
    await _firestore
        .collection('caregivers')
        .doc(caregiver.id)
        .update(caregiver.toFirestore());
    _caregiver = caregiver;
    notifyListeners();
  }

  /// Update managed user
  Future<void> updateManagedUser(AppUser user) async {
    await _firestore.collection('users').doc(user.id).update(user.toFirestore());

    final index = _managedUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _managedUsers[index] = user;
    }

    if (_selectedUser?.id == user.id) {
      _selectedUser = user;
    }

    notifyListeners();
  }

  /// Get user's current location
  Stream<GeoPoint?> watchUserLocation(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['currentLocation'] as GeoPoint?);
  }

  /// Get medication logs for a user
  Stream<List<MedicationLog>> getMedicationLogs(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('medication_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledTime', descending: true)
        .limit(100);

    if (startDate != null) {
      query = query.where('scheduledTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MedicationLog.fromFirestore(doc)).toList());
  }

  /// Get zone events for a user
  Stream<List<GeoZoneEvent>> getZoneEvents(String userId, {int limit = 50}) {
    return _firestore
        .collection('geo_zone_events')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GeoZoneEvent.fromFirestore(doc)).toList());
  }

  /// Add location to user
  Future<void> addUserLocation(String userId, SavedLocation location) async {
    final userIndex = _managedUsers.indexWhere((u) => u.id == userId);
    if (userIndex == -1) return;

    final user = _managedUsers[userIndex];
    final updatedLocations = [...user.savedLocations, location];
    final updatedUser = user.copyWith(savedLocations: updatedLocations);

    await updateManagedUser(updatedUser);
  }

  /// Add emergency contact to user
  Future<void> addUserContact(String userId, EmergencyContact contact) async {
    final userIndex = _managedUsers.indexWhere((u) => u.id == userId);
    if (userIndex == -1) return;

    final user = _managedUsers[userIndex];
    final updatedContacts = [...user.emergencyContacts, contact];
    final updatedUser = user.copyWith(emergencyContacts: updatedContacts);

    await updateManagedUser(updatedUser);
  }

  /// Add a newly created patient and auto-select them
  void addManagedUser(AppUser user) {
    _managedUsers.add(user);
    _selectedUser = user;
    notifyListeners();
  }

  /// Clear provider data
  void clear() {
    _caregiver = null;
    _managedUsers = [];
    _selectedUser = null;
    notifyListeners();
  }
}

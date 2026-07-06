import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/subscription.dart';

/// Wraps RevenueCat SDK. Subscriptions are tied to the patient ID (not caregiver).
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _initialized = false;

  /// Initialize RevenueCat with the patient as the customer.
  Future<void> initialize(String patientId) async {
    if (_initialized) return;

    final apiKey = Platform.isIOS
        ? dotenv.env['REVENUECAT_IOS_API_KEY']
        : dotenv.env['REVENUECAT_ANDROID_API_KEY'];

    if (apiKey == null || apiKey.isEmpty || apiKey.startsWith('your_')) {
      debugPrint('RevenueCat API key not configured, skipping initialization');
      return;
    }

    final config = PurchasesConfiguration(apiKey)..appUserID = patientId;
    await Purchases.configure(config);
    _initialized = true;
  }

  /// Get the current subscription status for a patient.
  Future<PatientSubscription> getSubscriptionStatus(String patientId) async {
    if (!_initialized) {
      return PatientSubscription(patientId: patientId);
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _toSubscription(patientId, customerInfo);
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      // Fall back to Firestore
      return _getFromFirestore(patientId);
    }
  }

  /// Fetch available offerings (packages/prices).
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Error getting offerings: $e');
      return null;
    }
  }

  /// Purchase a package for the given patient.
  Future<PatientSubscription> purchase(Package package, String patientId) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    final customerInfo = result.customerInfo;
    final sub = _toSubscription(patientId, customerInfo);
    await _syncToFirestore(patientId, customerInfo);
    return sub;
  }

  /// Restore purchases (e.g., on new device).
  Future<PatientSubscription> restorePurchases(String patientId) async {
    final customerInfo = await Purchases.restorePurchases();
    final sub = _toSubscription(patientId, customerInfo);
    await _syncToFirestore(patientId, customerInfo);
    return sub;
  }

  PatientSubscription _toSubscription(String patientId, CustomerInfo info) {
    final entitlement = info.entitlements.all['premium'];
    final isActive = entitlement?.isActive ?? false;

    return PatientSubscription(
      patientId: patientId,
      tier: isActive ? SubscriptionTier.premium : SubscriptionTier.free,
      expiresAt: entitlement?.expirationDate != null
          ? DateTime.parse(entitlement!.expirationDate!)
          : null,
      revenueCatCustomerId: info.originalAppUserId,
    );
  }

  Future<void> _syncToFirestore(String patientId, CustomerInfo info) async {
    final entitlement = info.entitlements.all['premium'];
    final isActive = entitlement?.isActive ?? false;

    await _firestore.collection('users').doc(patientId).update({
      'subscriptionTier': isActive ? 'premium' : 'free',
      'subscriptionExpiresAt': entitlement?.expirationDate != null
          ? Timestamp.fromDate(DateTime.parse(entitlement!.expirationDate!))
          : null,
      'revenueCatCustomerId': info.originalAppUserId,
    });
  }

  Future<PatientSubscription> _getFromFirestore(String patientId) async {
    final doc = await _firestore.collection('users').doc(patientId).get();
    final data = doc.data();
    if (data == null) return PatientSubscription(patientId: patientId);

    return PatientSubscription(
      patientId: patientId,
      tier: SubscriptionTier.fromString(data['subscriptionTier'] ?? 'free'),
      expiresAt: (data['subscriptionExpiresAt'] as Timestamp?)?.toDate(),
      revenueCatCustomerId: data['revenueCatCustomerId'],
    );
  }
}

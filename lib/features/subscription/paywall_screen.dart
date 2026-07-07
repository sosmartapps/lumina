import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Screen for viewing and purchasing subscription plans.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final subService = ref.read(subscriptionServiceProvider);
      final offerings = await subService.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load subscription options';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final subService = ref.read(subscriptionServiceProvider);
      final userProvider = ref.read(userNotifierProvider);
      final patientId = userProvider.user?.id;
      if (patientId == null) return;

      final sub = await subService.purchase(package, patientId);
      final subProvider = ref.read(subscriptionNotifierProvider);
      subProvider.updateSubscription(sub);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Lumina Premium!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('PurchasesCancelled')
              ? null
              : 'Purchase failed. Please try again.';
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final subService = ref.read(subscriptionServiceProvider);
      final userProvider = ref.read(userNotifierProvider);
      final patientId = userProvider.user?.id;
      if (patientId == null) return;

      final sub = await subService.restorePurchases(patientId);
      final subProvider = ref.read(subscriptionNotifierProvider);
      subProvider.updateSubscription(sub);

      if (mounted) {
        if (sub.isPremium) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription restored!'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
          Navigator.pop(context);
        } else {
          setState(() {
            _errorMessage = 'No active subscription found to restore';
            _isPurchasing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not restore purchases';
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = ref.watch(subscriptionNotifierProvider);
    final userProvider = ref.watch(userNotifierProvider);
    final patientName = userProvider.user?.name ?? 'your loved one';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Lumina Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Current tier badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: subProvider.isPremium
                          ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          subProvider.isPremium ? Icons.star : Icons.star_border,
                          color: subProvider.isPremium
                              ? AppTheme.primaryGreen
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          subProvider.isPremium ? 'Premium' : 'Free Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: subProvider.isPremium
                                ? AppTheme.primaryGreen
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Patient note
                  Text(
                    'Subscription is for $patientName\'s care plan',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Feature comparison
                  _buildFeatureComparison(),
                  const SizedBox(height: 32),

                  // Packages
                  if (!subProvider.isPremium && _offerings != null) ...[
                    ..._buildPackageCards(),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.primaryRed),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Restore purchases
                  TextButton(
                    onPressed: _isPurchasing ? null : _restore,
                    child: const Text(
                      'Restore Purchases',
                      style: TextStyle(fontSize: 16, color: AppTheme.primaryBlue),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureComparison() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'What you get',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _featureRow('Reminders', '5', 'Unlimited'),
            _featureRow('Medications', '3', 'Unlimited'),
            _featureRow('Saved Locations', '3', 'Unlimited'),
            _featureRow('Safe Zones / Geofencing', 'No', 'Yes'),
            _featureRow('Vehicle Tracking', 'No', 'Yes'),
            _featureRow('Invite Caregivers', 'No', 'Yes'),
            _featureRow('Medication Photos', 'No', 'Yes'),
            _featureRow('Emergency Contacts', 'Unlimited', 'Unlimited'),
            _featureRow('Lost Person Report', 'Yes', 'Yes'),
            _featureRow('Medical Profile', 'Yes', 'Yes'),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(String feature, String free, String premium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(feature, style: const TextStyle(fontSize: 14))),
          Expanded(
            flex: 1,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPackageCards() {
    final current = _offerings?.current;
    if (current == null) return [];

    return current.availablePackages.map((pkg) {
      final product = pkg.storeProduct;
      final isMonthly = pkg.packageType == PackageType.monthly;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: 72,
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : () => _purchase(pkg),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMonthly ? AppTheme.primaryBlue : AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isPurchasing
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        product.priceString,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }).toList();
  }
}

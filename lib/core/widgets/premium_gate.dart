import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../../features/subscription/paywall_screen.dart';

/// Wraps a child widget with a premium lock overlay when on the free tier.
///
/// Usage:
/// ```dart
/// PremiumGate(
///   feature: 'Geofencing',
///   child: ManageZonesScreen(),
/// )
/// ```
class PremiumGate extends ConsumerWidget {
  final String feature;
  final Widget child;

  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subProvider = ref.watch(subscriptionNotifierProvider);

    if (subProvider.isPremium) return child;

    return Stack(
      children: [
        // Blurred/dimmed child
        Opacity(opacity: 0.3, child: AbsorbPointer(child: child)),

        // Lock overlay
        Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 48,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$feature requires Premium',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upgrade to unlock $feature and all premium features.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'VIEW PLANS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows upgrade prompt when a limit is reached.
/// Returns true if the action is allowed, false if blocked.
bool checkLimitOrPrompt({
  required BuildContext context,
  required WidgetRef ref,
  required int currentCount,
  required int limit,
  required String itemName,
}) {
  if (limit == -1 || currentCount < limit) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Free plan allows up to $limit $itemName. Upgrade for unlimited.'),
      action: SnackBarAction(
        label: 'Upgrade',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        ),
      ),
      backgroundColor: AppTheme.primaryOrange,
    ),
  );
  return false;
}

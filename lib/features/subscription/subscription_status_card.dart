import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'paywall_screen.dart';

/// Small card for the dashboard overview showing subscription tier.
class SubscriptionStatusCard extends ConsumerWidget {
  const SubscriptionStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subProvider = ref.watch(subscriptionNotifierProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: subProvider.isPremium
                      ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                      : AppTheme.primaryOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  subProvider.isPremium ? Icons.star : Icons.star_border,
                  color: subProvider.isPremium
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryOrange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subProvider.isPremium ? 'Premium Plan' : 'Free Plan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subProvider.isPremium
                          ? 'All features unlocked'
                          : 'Tap to upgrade for full access',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!subProvider.isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Upgrade',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

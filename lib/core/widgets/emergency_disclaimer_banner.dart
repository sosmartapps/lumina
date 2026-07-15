import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact "not an emergency service" disclaimer shown at the point of use
/// on safety-adjacent feature screens (safe zones, monitoring settings,
/// QuadTrack). Legal purpose: courts weigh whether a reasonable user was
/// warned WHERE they relied on the feature, not just in the ToS.
///
/// Placements are inventoried in docs/legal/LEGAL-IMPLEMENTATION.md —
/// update that file when adding or removing one.
class EmergencyDisclaimerBanner extends StatelessWidget {
  /// Optional feature-specific line appended after the standard text.
  final String? detail;

  /// Outer margin — set to EdgeInsets.zero inside already-padded lists.
  final EdgeInsetsGeometry margin;

  const EmergencyDisclaimerBanner({
    super.key,
    this.detail,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.primaryOrange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Alerts can fail or be delayed and are not a substitute for '
              'supervision. Lumina is not an emergency service — in an '
              'emergency, call 911.'
              '${detail != null ? ' $detail' : ''}',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

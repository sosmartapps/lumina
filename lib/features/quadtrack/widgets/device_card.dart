import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/quadtrack_device.dart';

/// Card widget for QuadTrack device in dashboard list
class DeviceCard extends StatelessWidget {
  final QuadTrackDevice device;
  final String? patientName;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.patientName,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (device.status) {
      case DeviceStatus.online:
        return AppTheme.primaryGreen;
      case DeviceStatus.sleeping:
        return Colors.orange.shade600;
      case DeviceStatus.offline:
      case DeviceStatus.lowBattery:
      case DeviceStatus.phoneDead:
        return AppTheme.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isPhoneDead = device.isPhoneDead;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status indicator + Device & Patient name
              Row(
                children: [
                  // Status indicator dot
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (patientName != null)
                          Text(
                            patientName!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondaryLight,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Last seen info
              Text(
                'Last seen: ${device.lastSeenAgo}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
              ),
              const SizedBox(height: 12),

              // Battery and tracking mode row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tracker battery mini display
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracker',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textSecondaryLight,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: device.trackerBatteryLevel / 100.0,
                            minHeight: 6,
                            valueColor: AlwaysStoppedAnimation(
                              device.trackerBatteryLevel > 50
                                  ? AppTheme.primaryGreen
                                  : device.trackerBatteryLevel > 20
                                      ? AppTheme.primaryOrange
                                      : AppTheme.primaryRed,
                            ),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${device.trackerBatteryLevel}%',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Phone battery mini display
                  if (device.phoneBatteryLevel != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (device.phoneBatteryLevel ?? 0) / 100.0,
                              minHeight: 6,
                              valueColor: AlwaysStoppedAnimation(
                                device.phoneBatteryLevel! > 50
                                    ? AppTheme.primaryGreen
                                    : device.phoneBatteryLevel! > 20
                                        ? AppTheme.primaryOrange
                                        : AppTheme.primaryRed,
                              ),
                              backgroundColor: Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${device.phoneBatteryLevel}%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Tracking mode badge
              Chip(
                label: Text(device.trackingMode.displayName),
                backgroundColor: _getTrackingModeColor(),
                labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              // Phone dead banner (if applicable)
              if (isPhoneDead)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryRed,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: AppTheme.primaryRed,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Phone Battery Dead — Emergency Tracking Active',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.primaryRed,
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTrackingModeColor() {
    switch (device.trackingMode) {
      case TrackingMode.normal:
        return AppTheme.primaryBlue;
      case TrackingMode.emergency:
        return AppTheme.primaryRed;
      case TrackingMode.idle:
        return Colors.grey.shade600;
    }
  }
}

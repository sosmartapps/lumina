import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/environment_connection.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Home temperature/humidity card for the caregiver dashboard.
///
/// Shows nothing unless the selected patient has an environment provider
/// linked (per-family, stored in environment_connections/{patientId}).
/// Renders instantly from the denormalized `latest` snapshot on the
/// connection doc (kept fresh by the pollEnvironment Cloud Function),
/// with a foreground auto-refresh that pulls live from the provider.
class EnvironmentStatusCard extends ConsumerWidget {
  const EnvironmentStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(caregiverNotifierProvider).selectedUser;
    if (patient == null) return const SizedBox.shrink();

    return ref.watch(environmentConnectionProvider(patient.id)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (connection) =>
              connection == null || !connection.hasAnyProvider
                  ? const SizedBox.shrink()
                  : _EnvironmentStatusBody(
                      key: ValueKey(connection.userId),
                      connection: connection,
                    ),
        );
  }
}

class _EnvironmentStatusBody extends ConsumerStatefulWidget {
  final EnvironmentConnection connection;
  const _EnvironmentStatusBody({super.key, required this.connection});

  @override
  ConsumerState<_EnvironmentStatusBody> createState() =>
      _EnvironmentStatusBodyState();
}

class _EnvironmentStatusBodyState
    extends ConsumerState<_EnvironmentStatusBody> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Live refresh on open, then every 5 minutes while visible.
    // (The Cloud Function keeps `latest` warm in the background anyway.)
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(environmentServiceProvider).refreshLatest(
            widget.connection,
            ref.read(nestAppConfigProvider),
          );
      // Result lands in Firestore `latest` → the stream rebuilds the card.
    } catch (_) {
      // Stale `latest` keeps showing; poller will flag needsReauth if real.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final latest = connection.latest;
    final alerts = connection.alerts;
    final needsReauth = (connection.sensorPush?.needsReauth ?? false) ||
        (connection.nest?.needsReauth ?? false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat,
                    color: AppTheme.primaryTeal, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Home Environment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        latest?.sensorName ?? _providerLabel(connection),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (_refreshing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 20),
                    color: Colors.grey.shade500,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (needsReauth) ...[
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.primaryOrange, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sensor account needs to be re-linked in '
                      'Home Environment settings.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            if (latest == null)
              Text(
                'Waiting for the first reading…',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _bigStat(
                      Icons.device_thermostat,
                      '${latest.tempF.toStringAsFixed(0)}°F',
                      'Temperature',
                      _tempColor(latest.tempF, alerts),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _bigStat(
                      Icons.water_drop_outlined,
                      '${latest.humidity.toStringAsFixed(0)}%',
                      'Humidity',
                      _humidityColor(latest.humidity, alerts),
                    ),
                  ),
                ],
              ),

            if (latest != null) ...[
              const SizedBox(height: 10),
              Text(
                'Updated ${_updatedLabel(latest.observedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bigStat(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _providerLabel(EnvironmentConnection c) {
    final parts = <String>[
      if (c.sensorPush != null) 'SensorPush',
      if (c.nest != null) 'Nest',
    ];
    return parts.join(' + ');
  }

  String _updatedLabel(DateTime observedAt) {
    final age = DateTime.now().difference(observedAt);
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) {
      return DateFormat('h:mm a').format(observedAt.toLocal());
    }
    return DateFormat('MMM d, h:mm a').format(observedAt.toLocal());
  }

  Color _tempColor(double tempF, EnvironmentAlertConfig alerts) {
    if (tempF > alerts.maxTempF || tempF < alerts.minTempF) {
      return AppTheme.primaryRed;
    }
    if (tempF > alerts.maxTempF - 3 || tempF < alerts.minTempF + 3) {
      return AppTheme.primaryOrange;
    }
    return AppTheme.primaryGreen;
  }

  Color _humidityColor(double humidity, EnvironmentAlertConfig alerts) {
    if (humidity > alerts.maxHumidity || humidity < alerts.minHumidity) {
      return AppTheme.primaryRed;
    }
    if (humidity > alerts.maxHumidity - 5 ||
        humidity < alerts.minHumidity + 5) {
      return AppTheme.primaryOrange;
    }
    return AppTheme.primaryGreen;
  }
}

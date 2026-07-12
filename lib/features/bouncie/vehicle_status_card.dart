import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

import '../../core/models/bouncie_connection.dart';

/// Live vehicle status card for the caregiver dashboard.
///
/// Shows nothing unless the selected patient has a Bouncie connection
/// (per-family, stored in bouncie_connections/{patientId}).
class VehicleStatusCard extends ConsumerWidget {
  const VehicleStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(caregiverNotifierProvider).selectedUser;
    if (patient == null) return const SizedBox.shrink();

    return ref.watch(bouncieConnectionProvider(patient.id)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (connection) => connection == null
              ? const SizedBox.shrink()
              : _VehicleStatusBody(
                  key: ValueKey(connection.imei),
                  connection: connection,
                ),
        );
  }
}

class _VehicleStatusBody extends ConsumerStatefulWidget {
  final BouncieConnection connection;
  const _VehicleStatusBody({super.key, required this.connection});

  @override
  ConsumerState<_VehicleStatusBody> createState() => _VehicleStatusCardState();
}

class _VehicleStatusCardState extends ConsumerState<_VehicleStatusBody> {
  Map<String, dynamic>? _vehicleData;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchVehicleData();
    // Auto-refresh every 60 seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchVehicleData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchVehicleData() async {
    try {
      final bouncie = bouncieServiceForConnection(
          ref.read(bouncieAppConfigProvider), widget.connection);
      final data = await bouncie.getVehicleData(widget.connection.imei);
      if (mounted) {
        setState(() {
          _vehicleData = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _vehicleData == null) {
      return _buildShell(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null && _vehicleData == null) {
      return _buildShell(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.primaryRed, size: 32),
              const SizedBox(height: 8),
              Text('Could not load vehicle data', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(onPressed: _fetchVehicleData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final stats = _vehicleData!['stats'] as Map<String, dynamic>? ?? {};
    final model = _vehicleData!['model'] as Map<String, dynamic>? ?? {};
    final nickName = _vehicleData!['nickName'] as String? ?? 'Vehicle';
    final make = model['make'] as String? ?? '';
    final modelName = model['name'] as String? ?? '';
    final year = model['year'];

    final isRunning = stats['isRunning'] == true;
    final speed = (stats['speed'] as num?)?.toDouble() ?? 0.0;
    final fuelLevel = (stats['fuelLevel'] as num?)?.toDouble() ?? 0.0;
    final location = stats['location'] as Map<String, dynamic>?;
    final address = location?['address'] as String?;
    final lastUpdated = stats['lastUpdated'] as String?;
    final battery = stats['battery'] as Map<String, dynamic>?;
    final batteryStatus = battery?['status'] as String? ?? 'unknown';
    final mil = stats['mil'] as Map<String, dynamic>?;
    final milOn = mil?['milOn'] == true;

    final updatedTime = lastUpdated != null
        ? DateFormat('h:mm a').format(DateTime.parse(lastUpdated).toLocal())
        : '--';

    return _buildShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: vehicle name + status
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: isRunning ? AppTheme.primaryGreen : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${year ?? ''} $make $modelName'.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: isRunning ? AppTheme.primaryGreen : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRunning ? '${speed.toStringAsFixed(0)} mph' : 'Parked',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isRunning ? AppTheme.primaryGreen : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Location
            if (address != null) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Stats row: fuel, battery, check engine
            Row(
              children: [
                _buildMiniStat(
                  Icons.local_gas_station,
                  '${fuelLevel.toStringAsFixed(0)}%',
                  _fuelColor(fuelLevel),
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                  Icons.battery_std,
                  batteryStatus == 'normal' ? 'OK' : batteryStatus,
                  batteryStatus == 'normal' ? AppTheme.primaryGreen : AppTheme.primaryOrange,
                ),
                if (milOn) ...[
                  const SizedBox(width: 16),
                  _buildMiniStat(
                    Icons.warning_amber_rounded,
                    'Check Engine',
                    AppTheme.primaryRed,
                  ),
                ],
                Expanded(
                  child: Text(
                    'Updated $updatedTime',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShell({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildMiniStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Color _fuelColor(double percent) {
    if (percent <= 15) return AppTheme.primaryRed;
    if (percent <= 30) return AppTheme.primaryOrange;
    return AppTheme.primaryGreen;
  }
}

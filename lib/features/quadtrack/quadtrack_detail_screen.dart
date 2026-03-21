import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/quadtrack_provider.dart';
import '../../core/models/quadtrack_device.dart';
import 'widgets/battery_gauge.dart';
import 'quadtrack_navigate_screen.dart';
import 'quadtrack_share_screen.dart';

/// Detail screen for a single QuadTrack device
class QuadTrackDetailScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final String caregiverId;

  const QuadTrackDetailScreen({
    super.key,
    required this.deviceId,
    required this.caregiverId,
  });

  @override
  ConsumerState<QuadTrackDetailScreen> createState() =>
      _QuadTrackDetailScreenState();
}

class _QuadTrackDetailScreenState extends ConsumerState<QuadTrackDetailScreen> {
  late GoogleMapController _mapController;
  bool _isMapReady = false;
  List<LatLng> _locationTrail = [];
  Set<Marker> _markers = {};

  @override
  void dispose() {
    if (_isMapReady) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;
  }

  void _updateMapContent(QuadTrackDevice device, List<QuadTrackPing> pings) {
    // Build location trail from pings
    final trail = <LatLng>[];
    for (final ping in pings.reversed) {
      trail.add(LatLng(ping.location.latitude, ping.location.longitude));
    }

    final newMarkers = <Marker>{};
    if (device.lastLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            device.lastLocation!.latitude,
            device.lastLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: device.name,
            snippet: 'Last seen: ${device.lastSeenAgo}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _locationTrail = trail;
        _markers = newMarkers;
      });
    }
  }

  void _showTrackingModeDialog(QuadTrackDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Tracking Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current mode: ${device.trackingMode.displayName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (device.trackingMode != TrackingMode.emergency)
              Column(
                children: [
                  Text(
                    'Emergency mode will increase tracking frequency to every 5 minutes and notify all caregivers.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryRed,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (device.trackingMode != TrackingMode.normal)
            TextButton(
              onPressed: () {
                ref
                    .read(quadTrackServiceProvider)
                    .updateTrackingMode(widget.deviceId, TrackingMode.normal);
                Navigator.pop(context);
              },
              child: const Text('Normal'),
            ),
          if (device.trackingMode != TrackingMode.emergency)
            ElevatedButton(
              onPressed: () {
                ref
                    .read(quadTrackServiceProvider)
                    .updateTrackingMode(widget.deviceId, TrackingMode.emergency);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency tracking activated'),
                    backgroundColor: AppTheme.primaryRed,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
              ),
              child: const Text('Emergency'),
            ),
          if (device.trackingMode != TrackingMode.idle)
            TextButton(
              onPressed: () {
                ref
                    .read(quadTrackServiceProvider)
                    .updateTrackingMode(widget.deviceId, TrackingMode.idle);
                Navigator.pop(context);
              },
              child: const Text('Idle'),
            ),
        ],
      ),
    );
  }

  void _showRenameDialog(QuadTrackDevice device) {
    final controller = TextEditingController(text: device.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            hintText: 'e.g., Mom\'s Tracker',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != device.name) {
                ref
                    .read(quadTrackServiceProvider)
                    .updateTrackingMode(widget.deviceId, device.trackingMode);
                // TODO: Implement rename in service
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(QuadTrackDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text(
          'Are you sure you want to remove "${device.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(quadTrackServiceProvider).removeDevice(widget.deviceId);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${device.name} removed'),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceDetailProvider(widget.deviceId));
    final pingsAsync = ref.watch(devicePingsProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Device Details'),
        centerTitle: true,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Rename'),
                onTap: () {
                  deviceAsync.whenData((device) {
                    if (device != null) {
                      _showRenameDialog(device);
                    }
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Remove Device'),
                onTap: () {
                  deviceAsync.whenData((device) {
                    if (device != null) {
                      _showRemoveDialog(device);
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: deviceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.primaryRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text('Error loading device'),
            ],
          ),
        ),
        data: (device) {
          if (device == null) {
            return const Center(child: Text('Device not found'));
          }

          return pingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading pings')),
            data: (pings) {
              _updateMapContent(device, pings);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map section
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: device.lastLocation != null
                              ? LatLng(
                                  device.lastLocation!.latitude,
                                  device.lastLocation!.longitude,
                                )
                              : const LatLng(0, 0),
                          zoom: 14,
                        ),
                        markers: _markers,
                        polylines: {
                          if (_locationTrail.isNotEmpty)
                            Polyline(
                              polylineId: const PolylineId('trail'),
                              points: _locationTrail,
                              color: AppTheme.primaryBlue,
                              width: 4,
                              geodesic: true,
                            ),
                        },
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        QuadTrackNavigateScreen(
                                      deviceId: widget.deviceId,
                                      caregiverId: widget.caregiverId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.directions),
                              label: const Text('Navigate to Device'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        QuadTrackShareScreen(
                                      deviceId: widget.deviceId,
                                      caregiverId: widget.caregiverId,
                                      patientName: device.name,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.badge),
                              label:
                                  const Text('Share with Law Enforcement'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: device.trackingMode ==
                                          TrackingMode.emergency
                                      ? AppTheme.primaryRed
                                      : AppTheme.primaryBlue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Info section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device info card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Name', device.name),
                                  _buildInfoRow(
                                    'Status',
                                    device.status.displayName,
                                    valueColor: _getStatusColor(device.status),
                                  ),
                                  _buildInfoRow(
                                    'Last Seen',
                                    device.lastSeenAgo,
                                  ),
                                  if (device.firmwareVersion != null)
                                    _buildInfoRow(
                                      'Firmware',
                                      device.firmwareVersion!,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Battery section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Battery Status',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: BatteryGauge(
                                          percentage:
                                              device.trackerBatteryLevel,
                                          label: 'Tracker',
                                          chargingState:
                                              device.chargingState,
                                        ),
                                      ),
                                      if (device.phoneBatteryLevel != null)
                                        Expanded(
                                          child: BatteryGauge(
                                            percentage:
                                                device.phoneBatteryLevel!,
                                            label: 'Phone',
                                            isPhoneBattery: true,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tracking mode selector
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tracking Mode',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildModeButton(
                                        context,
                                        device,
                                        TrackingMode.normal,
                                      ),
                                      _buildModeButton(
                                        context,
                                        device,
                                        TrackingMode.emergency,
                                      ),
                                      _buildModeButton(
                                        context,
                                        device,
                                        TrackingMode.idle,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Location history
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location History',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (pings.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'No location history',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppTheme.textSecondaryLight,
                                              ),
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount:
                                          pings.length.clamp(0, 10), // Show last 10
                                      separatorBuilder: (_, __) =>
                                          const Divider(),
                                      itemBuilder: (context, index) {
                                        final ping = pings[index];
                                        final time = DateFormat.jm()
                                            .format(ping.timestamp);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      time,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium,
                                                    ),
                                                    Text(
                                                      '${ping.location.latitude.toStringAsFixed(4)}, ${ping.location.longitude.toStringAsFixed(4)}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: AppTheme
                                                                .textSecondaryLight,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '${ping.batteryLevel}%',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    QuadTrackDevice device,
    TrackingMode mode,
  ) {
    final isSelected = device.trackingMode == mode;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: isSelected
              ? null
              : () => _showTrackingModeDialog(device),
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected
                ? _getModeColor(mode)
                : Colors.transparent,
            side: BorderSide(
              color: _getModeColor(mode),
              width: isSelected ? 0 : 2,
            ),
          ),
          child: Text(
            mode.displayName,
            style: TextStyle(
              color: isSelected ? Colors.white : _getModeColor(mode),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getModeColor(TrackingMode mode) {
    switch (mode) {
      case TrackingMode.normal:
        return AppTheme.primaryBlue;
      case TrackingMode.emergency:
        return AppTheme.primaryRed;
      case TrackingMode.idle:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return AppTheme.primaryGreen;
      case DeviceStatus.offline:
      case DeviceStatus.lowBattery:
      case DeviceStatus.phoneDead:
        return AppTheme.primaryRed;
      case DeviceStatus.sleeping:
        return AppTheme.primaryOrange;
    }
  }
}

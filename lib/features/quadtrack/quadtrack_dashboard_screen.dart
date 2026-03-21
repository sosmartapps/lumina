import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/quadtrack_provider.dart';
import '../../core/models/quadtrack_device.dart';
import 'widgets/device_card.dart';
import 'quadtrack_detail_screen.dart';
import 'quadtrack_register_screen.dart';

/// Main dashboard for caregivers to monitor all QuadTrack devices
class QuadTrackDashboardScreen extends ConsumerStatefulWidget {
  final String caregiverId;

  const QuadTrackDashboardScreen({
    super.key,
    required this.caregiverId,
  });

  @override
  ConsumerState<QuadTrackDashboardScreen> createState() =>
      _QuadTrackDashboardScreenState();
}

class _QuadTrackDashboardScreenState
    extends ConsumerState<QuadTrackDashboardScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  bool _isMapReady = false;

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

  void _updateMarkers(List<QuadTrackDevice> devices) {
    final newMarkers = <Marker>{};

    for (final device in devices) {
      if (device.lastLocation == null) continue;

      final markerId = MarkerId(device.id);
      final position = LatLng(
        device.lastLocation!.latitude,
        device.lastLocation!.longitude,
      );

      // Determine marker color based on status
      BitmapDescriptor markerColor;
      switch (device.status) {
        case DeviceStatus.online:
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          );
          break;
        case DeviceStatus.sleeping:
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          );
          break;
        case DeviceStatus.offline:
        case DeviceStatus.lowBattery:
        case DeviceStatus.phoneDead:
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          );
          break;
      }

      newMarkers.add(
        Marker(
          markerId: markerId,
          position: position,
          infoWindow: InfoWindow(
            title: device.name,
            snippet: 'Last seen: ${device.lastSeenAgo}',
          ),
          icon: markerColor,
        ),
      );
    }

    if (mounted) {
      setState(() => _markers = newMarkers);
    }
  }

  void _showRegisterDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuadTrackRegisterScreen(
          caregiverId: widget.caregiverId,
        ),
      ),
    );
  }

  void _navigateToDetail(QuadTrackDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuadTrackDetailScreen(
          deviceId: device.id,
          caregiverId: widget.caregiverId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(
      caregiverDevicesProvider(widget.caregiverId),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('QuadTrack Devices'),
        centerTitle: true,
      ),
      body: devicesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
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
              Text(
                'Error loading devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (devices) {
          // Update markers whenever devices change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMarkers(devices);
          });

          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No QuadTrack Devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register a device to get started with location tracking',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showRegisterDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Register Device'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Trigger a refresh by invalidating the provider
              ref.invalidate(
                caregiverDevicesProvider(widget.caregiverId),
              );
            },
            child: Column(
              children: [
                // Google Map at the top
                SizedBox(
                  height: 250,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        devices.first.lastLocation?.latitude ?? 0,
                        devices.first.lastLocation?.longitude ?? 0,
                      ),
                      zoom: 12,
                    ),
                    markers: _markers,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                  ),
                ),
                // Device list below map
                Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return DeviceCard(
                        device: device,
                        patientName: null, // Could load from user data
                        onTap: () => _navigateToDetail(device),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRegisterDialog,
        tooltip: 'Register New Device',
        backgroundColor: AppTheme.primaryTeal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

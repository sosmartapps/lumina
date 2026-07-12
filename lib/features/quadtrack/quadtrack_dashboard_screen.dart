import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  MapType _mapType = MapType.normal;

  /// Small white overlay button that toggles street/satellite view
  Widget _buildMapTypeToggle() {
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: IconButton(
          tooltip: _mapType == MapType.normal
              ? 'Satellite view'
              : 'Street view',
          icon: Icon(
            _mapType == MapType.normal ? Icons.satellite_alt : Icons.map,
            color: AppTheme.primaryTeal,
          ),
          onPressed: () {
            setState(() {
              _mapType = _mapType == MapType.normal
                  ? MapType.hybrid
                  : MapType.normal;
            });
          },
        ),
      ),
    );
  }

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
                // Google Map at the top — placeholder until a device has
                // reported a location ((0,0) is just empty ocean)
                if (!devices.any((d) => d.lastLocation != null))
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Waiting for first location ping',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 250,
                    child: Stack(
                      children: [
                        GoogleMap(
                          onMapCreated: _onMapCreated,
                          mapType: _mapType,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              devices
                                  .firstWhere((d) => d.lastLocation != null)
                                  .lastLocation!
                                  .latitude,
                              devices
                                  .firstWhere((d) => d.lastLocation != null)
                                  .lastLocation!
                                  .longitude,
                            ),
                            zoom: 12,
                          ),
                          markers: _markers,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                        ),
                        _buildMapTypeToggle(),
                      ],
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

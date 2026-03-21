import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/quadtrack_provider.dart';

/// Live directions screen showing caregiver position and patient tracker location
class QuadTrackNavigateScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final String caregiverId;

  const QuadTrackNavigateScreen({
    super.key,
    required this.deviceId,
    required this.caregiverId,
  });

  @override
  ConsumerState<QuadTrackNavigateScreen> createState() =>
      _QuadTrackNavigateScreenState();
}

class _QuadTrackNavigateScreenState
    extends ConsumerState<QuadTrackNavigateScreen> {
  late GoogleMapController _mapController;
  bool _isMapReady = false;
  Position? _caregiverPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }

  @override
  void dispose() {
    if (_isMapReady) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _startLocationStream() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // Update when moved 10+ meters
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _caregiverPosition = position;
        });
        _updateMap();
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;
    _updateMap();
  }

  void _updateMap() {
    if (!_isMapReady) return;

    final deviceAsync = ref.read(deviceDetailProvider(widget.deviceId));

    deviceAsync.whenData((device) {
      if (device == null || _caregiverPosition == null) return;

      final newMarkers = <Marker>{};

      // Caregiver position (blue dot)
      newMarkers.add(
        Marker(
          markerId: const MarkerId('caregiver_location'),
          position: LatLng(_caregiverPosition!.latitude,
              _caregiverPosition!.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Caregiver position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue),
        ),
      );

      // Patient tracker position (red marker)
      if (device.lastLocation != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('patient_location'),
            position: LatLng(
              device.lastLocation!.latitude,
              device.lastLocation!.longitude,
            ),
            infoWindow: InfoWindow(
              title: device.name,
              snippet: 'Patient location',
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );

        // Draw polyline between positions
        final newPolylines = <Polyline>{};
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('caregiver_to_patient'),
            points: [
              LatLng(_caregiverPosition!.latitude,
                  _caregiverPosition!.longitude),
              LatLng(device.lastLocation!.latitude,
                  device.lastLocation!.longitude),
            ],
            color: AppTheme.primaryBlue,
            width: 4,
            geodesic: true,
          ),
        );

        // Center map to show both positions
        _mapController.animateCamera(
          CameraUpdateOptions(
            bounds: _calculateBounds(
              LatLng(_caregiverPosition!.latitude,
                  _caregiverPosition!.longitude),
              LatLng(device.lastLocation!.latitude,
                  device.lastLocation!.longitude),
            ),
            padding: const EdgeInsets.all(100),
          ),
        );

        setState(() {
          _markers = newMarkers;
          _polylines = newPolylines;
        });
      }
    });
  }

  CameraUpdateOptions _calculateBounds(LatLng p1, LatLng p2) {
    final sw = LatLng(
      (p1.latitude < p2.latitude) ? p1.latitude : p2.latitude,
      (p1.longitude < p2.longitude) ? p1.longitude : p2.longitude,
    );
    final ne = LatLng(
      (p1.latitude > p2.latitude) ? p1.latitude : p2.latitude,
      (p1.longitude > p2.longitude) ? p1.longitude : p2.longitude,
    );

    return CameraUpdateOptions(
      bounds: LatLngBounds(southwest: sw, northeast: ne),
      padding: const EdgeInsets.all(100),
    );
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371; // Radius in km
    final dLat = _toRad(to.latitude - from.latitude);
    final dLng = _toRad(to.longitude - from.longitude);

    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        _toRad(from.latitude).cos() *
            _toRad(to.latitude).cos() *
            (dLng / 2).sin() *
            (dLng / 2).sin();

    final c = 2 * a.asin().clamp(-1.0, 1.0).asin();

    return earthRadius * c;
  }

  double _toRad(double degree) {
    return degree * (3.141592653589793 / 180.0);
  }

  String _getETA(double distanceKm) {
    // Assume average driving speed of 50 km/h
    const averageSpeedKmh = 50;
    final minutes = ((distanceKm / averageSpeedKmh) * 60).toInt();

    if (minutes < 1) return '< 1 min';
    if (minutes == 1) return '1 min';
    return '$minutes mins';
  }

  Future<void> _openGoogleMaps() async {
    final deviceAsync = ref.read(deviceDetailProvider(widget.deviceId));

    deviceAsync.whenData((device) {
      if (device?.lastLocation == null) return;

      final lat = device!.lastLocation!.latitude;
      final lng = device.lastLocation!.longitude;

      final url =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceDetailProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Navigate to Device'),
        centerTitle: true,
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
              const Text('Error loading device location'),
            ],
          ),
        ),
        data: (device) {
          if (device == null) {
            return const Center(child: Text('Device not found'));
          }

          if (device.lastLocation == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off,
                    color: AppTheme.primaryOrange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text('No location data available'),
                ],
              ),
            );
          }

          final distance = _caregiverPosition != null
              ? _calculateDistance(
                  LatLng(_caregiverPosition!.latitude,
                      _caregiverPosition!.longitude),
                  LatLng(device.lastLocation!.latitude,
                      device.lastLocation!.longitude),
                )
              : 0.0;

          final eta = _getETA(distance);

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      device.lastLocation!.latitude,
                      device.lastLocation!.longitude,
                    ),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          device.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: device.trackerBatteryLevel > 50
                                ? AppTheme.primaryGreen
                                : device.trackerBatteryLevel > 20
                                    ? AppTheme.primaryOrange
                                    : AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${device.trackerBatteryLevel}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distance',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryLight,
                                    ),
                              ),
                              Text(
                                '${distance.toStringAsFixed(1)} km',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Time',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryLight,
                                    ),
                              ),
                              Text(
                                eta,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Ping',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryLight,
                                    ),
                              ),
                              Text(
                                device.lastSeenAgo,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.directions),
                        label: const Text('Open in Google Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

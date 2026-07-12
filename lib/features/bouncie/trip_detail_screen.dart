import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

/// Detail view for a single Bouncie trip: the driven route drawn on a map
/// (with satellite toggle) plus driving-behavior stats.
class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  late final List<LatLng> _route;

  @override
  void initState() {
    super.initState();
    final gps = widget.trip['gps'];
    _route = gps is String ? _decodePolyline(gps) : const [];
  }

  /// Standard Google encoded-polyline decoder (no package dependency).
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _cycleMapType() {
    setState(() {
      _mapType = switch (_mapType) {
        MapType.normal => MapType.satellite,
        MapType.satellite => MapType.hybrid,
        _ => MapType.normal,
      };
    });
  }

  String get _mapTypeLabel => switch (_mapType) {
        MapType.satellite => 'Satellite',
        MapType.hybrid => 'Hybrid',
        _ => 'Map',
      };

  Future<void> _fitRoute() async {
    if (_route.length < 2 || _mapController == null) return;
    double minLat = _route.first.latitude, maxLat = _route.first.latitude;
    double minLng = _route.first.longitude, maxLng = _route.first.longitude;
    for (final p in _route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  DateTime? _parseTime(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final startTime = _parseTime(trip['startTime']);
    final endTime = _parseTime(trip['endTime']);
    final distance = (trip['distance'] as num?)?.toDouble() ?? 0.0;
    final avgSpeed = (trip['averageSpeed'] as num?)?.toDouble();
    final maxSpeed = (trip['maxSpeed'] as num?)?.toDouble();
    final fuel = (trip['fuelConsumed'] as num?)?.toDouble();
    final hardBrakes = (trip['hardBrakingCount'] ?? trip['hardBrakes']) as int? ?? 0;
    final hardAccels =
        (trip['hardAccelerationCount'] ?? trip['hardAccelerations']) as int? ?? 0;
    final startOdo = (trip['startOdometer'] as num?)?.toDouble();
    final endOdo = (trip['endOdometer'] as num?)?.toDouble();

    final duration = (startTime != null && endTime != null)
        ? endTime.difference(startTime)
        : null;
    final title = startTime != null
        ? DateFormat('EEE, MMM d · h:mm a').format(startTime)
        : 'Trip';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: Text(title, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton.icon(
            onPressed: _cycleMapType,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.layers),
            label: Text(_mapTypeLabel),
          ),
        ],
      ),
      body: Column(
        children: [
          // Route map
          Expanded(
            child: _route.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('No route data for this trip',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _route.first,
                      zoom: 13,
                    ),
                    mapType: _mapType,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Fit after the map settles.
                      Future.delayed(
                          const Duration(milliseconds: 300), _fitRoute);
                    },
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('trip_route'),
                        points: _route,
                        color: AppTheme.primaryBlue,
                        width: 5,
                      ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('start'),
                        position: _route.first,
                        infoWindow: const InfoWindow(title: 'Start'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                      ),
                      Marker(
                        markerId: const MarkerId('end'),
                        position: _route.last,
                        infoWindow: const InfoWindow(title: 'End'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
          ),

          // Stats panel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _statChip(Icons.straighten,
                        '${distance.toStringAsFixed(1)} mi', 'Distance'),
                    if (duration != null)
                      _statChip(
                          Icons.timer, _formatDuration(duration), 'Duration'),
                    if (avgSpeed != null)
                      _statChip(Icons.speed,
                          '${avgSpeed.toStringAsFixed(0)} mph', 'Avg speed'),
                    if (maxSpeed != null)
                      _statChip(Icons.rocket_launch,
                          '${maxSpeed.toStringAsFixed(0)} mph', 'Top speed'),
                    _statChip(
                      Icons.warning_amber,
                      '$hardBrakes',
                      'Hard brakes',
                      color: hardBrakes > 0
                          ? AppTheme.primaryOrange
                          : AppTheme.primaryGreen,
                    ),
                    _statChip(
                      Icons.bolt,
                      '$hardAccels',
                      'Hard accels',
                      color: hardAccels > 0
                          ? AppTheme.primaryOrange
                          : AppTheme.primaryGreen,
                    ),
                    if (fuel != null)
                      _statChip(Icons.local_gas_station,
                          '${fuel.toStringAsFixed(2)} gal', 'Fuel used'),
                    if (startOdo != null && endOdo != null)
                      _statChip(
                          Icons.pin,
                          '${endOdo.toStringAsFixed(0)} mi',
                          'Odometer'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, {Color? color}) {
    final c = color ?? AppTheme.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 4),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: c)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

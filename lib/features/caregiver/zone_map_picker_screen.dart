import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Result returned by [ZoneMapPickerScreen].
class ZonePickResult {
  final LatLng center;
  final double radiusMeters;

  /// Reverse-geocoded address of [center], if resolvable.
  final String? address;

  ZonePickResult({
    required this.center,
    required this.radiusMeters,
    this.address,
  });
}

/// Full-screen map for picking a zone center directly on the map,
/// with a live radius preview and a map/satellite/hybrid toggle.
/// Works identically on iOS and Android (google_maps_flutter).
class ZoneMapPickerScreen extends ConsumerStatefulWidget {
  final LatLng initialCenter;
  final double initialRadius;
  final Color zoneColor;

  const ZoneMapPickerScreen({
    super.key,
    required this.initialCenter,
    this.initialRadius = 100,
    this.zoneColor = AppTheme.primaryTeal,
  });

  @override
  ConsumerState<ZoneMapPickerScreen> createState() =>
      _ZoneMapPickerScreenState();
}

class _ZoneMapPickerScreenState extends ConsumerState<ZoneMapPickerScreen> {
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;

  LatLng? _selected;
  late double _radius;
  MapType _mapType = MapType.normal;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searching = true);
    final locationService = ref.read(locationServiceProvider);
    final point = await locationService.resolveLocationQuery(query);
    if (!mounted) return;
    setState(() => _searching = false);

    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Not found — try an address, "lat, lng", or ///what.three.words'),
        ),
      );
      return;
    }

    final target = LatLng(point.latitude, point.longitude);
    setState(() => _selected = target);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16),
    );
  }

  Future<void> _confirm() async {
    if (_selected == null) return;

    // Best-effort reverse geocode for a display address.
    String? address;
    try {
      final locationService = ref.read(locationServiceProvider);
      address = await locationService
          .getAddressFromLocation(
            GeoPoint(_selected!.latitude, _selected!.longitude),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      address = null;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      ZonePickResult(
        center: _selected!,
        radiusMeters: _radius,
        address: address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.zoneColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Pick Zone Center'),
        actions: [
          // Map type toggle
          TextButton.icon(
            onPressed: _cycleMapType,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.layers),
            label: Text(_mapTypeLabel),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter,
              zoom: 15,
            ),
            mapType: _mapType,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (position) => setState(() => _selected = position),
            markers: {
              if (_selected != null)
                Marker(
                  markerId: const MarkerId('zone_center'),
                  position: _selected!,
                  draggable: true,
                  onDragEnd: (position) =>
                      setState(() => _selected = position),
                ),
            },
            circles: {
              if (_selected != null)
                Circle(
                  circleId: const CircleId('zone_preview'),
                  center: _selected!,
                  radius: _radius,
                  fillColor: color.withValues(alpha: 0.2),
                  strokeColor: color,
                  strokeWidth: 2,
                ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Address search bar
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(
                      '[\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u206F\\uFEFF]')),
                ],
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAddress(),
                decoration: InputDecoration(
                  hintText: 'Address, lat,lng, or ///what.three.words',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _searchAddress,
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Bottom card: radius + confirm
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selected == null
                          ? 'Tap the map to place the zone center'
                          : 'Radius: ${_radius.toInt()} meters',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_selected != null) ...[
                      Slider(
                        value: _radius,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        label: '${_radius.toInt()}m',
                        onChanged: (value) => setState(() => _radius = value),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _selected == null ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Use This Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

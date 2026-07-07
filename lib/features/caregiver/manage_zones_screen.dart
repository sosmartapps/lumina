import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/providers/caregiver_provider.dart';
import '../../core/services/geofence_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/geo_zone.dart';
import 'zone_map_picker_screen.dart';

/// Screen for caregivers to manage geofence zones
class ManageZonesScreen extends ConsumerStatefulWidget {
  const ManageZonesScreen({super.key});

  @override
  ConsumerState<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends ConsumerState<ManageZonesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Safe Zones'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddZoneDialog(context),
        backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.add),
        label: const Text('Add Zone'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final geofenceService = ref.read(geofenceServiceProvider);

          return StreamBuilder<List<GeoZone>>(
            stream: geofenceService.getZones(user.id),
            builder: (context, snapshot) {
              final zones = snapshot.data ?? [];

              if (zones.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: zones.length,
                itemBuilder: (context, index) {
                  final zone = zones[index];
                  return _buildZoneCard(zone, provider, geofenceService);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No zones set up',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add safe zones to monitor user location',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(
    GeoZone zone,
    CaregiverProvider provider,
    GeofenceServiceWrapper geofenceService,
  ) {
    final color = _getZoneColor(zone.type);
    final icon = _getZoneIcon(zone.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          zone.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                zone.type.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: zone.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                zone.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12,
                  color: zone.isActive ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini map preview
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          zone.center.latitude,
                          zone.center.longitude,
                        ),
                        zoom: 15,
                      ),
                      circles: {
                        Circle(
                          circleId: CircleId(zone.id),
                          center: LatLng(
                            zone.center.latitude,
                            zone.center.longitude,
                          ),
                          radius: zone.radiusMeters,
                          fillColor: color.withValues(alpha: 0.2),
                          strokeColor: color,
                          strokeWidth: 2,
                        ),
                      },
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Zone details
                Row(
                  children: [
                    const Icon(Icons.radar, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Radius: ${zone.radiusMeters.toInt()}m'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.notifications, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Alert on: ${zone.alertOnEntry ? "Entry" : ""}${zone.alertOnEntry && zone.alertOnExit ? " & " : ""}${zone.alertOnExit ? "Exit" : ""}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          await geofenceService.updateZone(
                            zone.copyWith(isActive: !zone.isActive),
                          );
                        },
                        icon: Icon(
                          zone.isActive ? Icons.pause : Icons.play_arrow,
                        ),
                        label: Text(zone.isActive ? 'Disable' : 'Enable'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _showEditZoneDialog(zone, geofenceService),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _showDeleteConfirmation(zone, geofenceService),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getZoneColor(GeoZoneType type) {
    switch (type) {
      case GeoZoneType.home:
        return AppTheme.primaryGreen;
      case GeoZoneType.safe:
        return AppTheme.primaryBlue;
      case GeoZoneType.danger:
        return AppTheme.primaryRed;
      case GeoZoneType.work:
        return AppTheme.primaryOrange;
      case GeoZoneType.medical:
        return AppTheme.primaryPurple;
    }
  }

  IconData _getZoneIcon(GeoZoneType type) {
    switch (type) {
      case GeoZoneType.home:
        return Icons.home;
      case GeoZoneType.safe:
        return Icons.shield;
      case GeoZoneType.danger:
        return Icons.warning;
      case GeoZoneType.work:
        return Icons.work;
      case GeoZoneType.medical:
        return Icons.local_hospital;
    }
  }

  /// Default camera target for the map picker: existing pick > patient's
  /// home > Tucson fallback.
  LatLng _pickerStart(GeoPoint? current) {
    if (current != null) {
      return LatLng(current.latitude, current.longitude);
    }
    final home = ref.read(caregiverNotifierProvider).selectedUser?.homeLocation;
    if (home != null) return LatLng(home.latitude, home.longitude);
    return const LatLng(32.2226, -110.9747); // Tucson
  }

  void _showAddZoneDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    GeoZoneType selectedType = GeoZoneType.safe;
    double radius = 100;
    bool alertOnEntry = false;
    bool alertOnExit = true;
    bool isLoading = false;
    GeoPoint? pickedCenter;
    String? pickedLabel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Safe Zone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name *',
                    prefixIcon: Icon(Icons.label),
                    hintText: 'e.g., Home Area',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: pickedCenter == null
                        ? 'Zone Center *'
                        : 'Zone Center (optional)',
                    prefixIcon: const Icon(Icons.place),
                    hintText: 'Address, lat,lng, or ///what.three.words',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                // Pick directly on the map (with satellite view)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<ZonePickResult>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ZoneMapPickerScreen(
                            initialCenter: _pickerStart(pickedCenter),
                            initialRadius: radius,
                            zoneColor: _getZoneColor(selectedType),
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          pickedCenter = GeoPoint(
                            result.center.latitude,
                            result.center.longitude,
                          );
                          radius = result.radiusMeters;
                          pickedLabel = result.address ??
                              '${result.center.latitude.toStringAsFixed(5)}, '
                                  '${result.center.longitude.toStringAsFixed(5)}';
                          if (result.address != null &&
                              addressController.text.isEmpty) {
                            addressController.text = result.address!;
                          }
                        });
                      }
                    },
                    icon: Icon(
                      pickedCenter == null ? Icons.map : Icons.check_circle,
                      color: pickedCenter == null
                          ? null
                          : AppTheme.primaryGreen,
                    ),
                    label: Text(
                      pickedCenter == null
                          ? 'Pick on Map'
                          : 'Pinned: $pickedLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<GeoZoneType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Zone Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: GeoZoneType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                        // Set default alerts based on type
                        if (value == GeoZoneType.danger) {
                          alertOnEntry = true;
                          alertOnExit = false;
                        } else {
                          alertOnEntry = false;
                          alertOnExit = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Radius: ${radius.toInt()} meters'),
                Slider(
                  value: radius,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${radius.toInt()}m',
                  onChanged: (value) => setState(() => radius = value),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alert when entering'),
                  value: alertOnEntry,
                  onChanged: (value) => setState(() => alertOnEntry = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alert when leaving'),
                  value: alertOnExit,
                  onChanged: (value) => setState(() => alertOnExit = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // A map pin OR an address is required (plus a name).
                      if (nameController.text.isEmpty ||
                          (pickedCenter == null &&
                              addressController.text.isEmpty)) {
                        return;
                      }

                      setState(() => isLoading = true);

                      // Map pin wins; otherwise resolve the typed query
                      // (address, coordinates, or what3words).
                      GeoPoint? center = pickedCenter;
                      if (center == null) {
                        final locationService =
                            ref.read(locationServiceProvider);
                        center = await locationService.resolveLocationQuery(
                            addressController.text.trim());
                      }

                      if (!context.mounted) return;

                      if (center == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not find address')),
                        );
                        setState(() => isLoading = false);
                        return;
                      }

                      final provider =
                          ref.read(caregiverNotifierProvider);
                      final geofenceService =
                          ref.read(geofenceServiceProvider);
                      final user = provider.selectedUser!;

                      final zone = GeoZone(
                        id: '',
                        userId: user.id,
                        name: nameController.text.trim(),
                        center: center,
                        radiusMeters: radius,
                        type: selectedType,
                        alertOnEntry: alertOnEntry,
                        alertOnExit: alertOnExit,
                        createdBy: provider.caregiver!.id,
                      );

                      try {
                        await geofenceService.createZone(zone);
                      } catch (e) {
                        if (!context.mounted) return;
                        setState(() => isLoading = false);
                        final msg = e.toString().contains('permission-denied')
                            ? 'Safe zones require a Premium subscription for this patient.'
                            : 'Could not save zone: $e';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditZoneDialog(GeoZone zone, GeofenceServiceWrapper geofenceService) {
    final nameController = TextEditingController(text: zone.name);
    GeoZoneType selectedType = zone.type;
    double radius = zone.radiusMeters;
    bool alertOnEntry = zone.alertOnEntry;
    bool alertOnExit = zone.alertOnExit;
    GeoPoint center = zone.center;
    bool centerMoved = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Zone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                // Move the zone center on the map (satellite available)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<ZonePickResult>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ZoneMapPickerScreen(
                            initialCenter:
                                LatLng(center.latitude, center.longitude),
                            initialRadius: radius,
                            zoneColor: _getZoneColor(selectedType),
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          center = GeoPoint(result.center.latitude,
                              result.center.longitude);
                          radius = result.radiusMeters;
                          centerMoved = true;
                        });
                      }
                    },
                    icon: Icon(
                      centerMoved ? Icons.check_circle : Icons.map,
                      color: centerMoved ? AppTheme.primaryGreen : null,
                    ),
                    label: Text(
                        centerMoved ? 'Center moved' : 'Move Center on Map'),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<GeoZoneType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Zone Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: GeoZoneType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                Text('Radius: ${radius.toInt()} meters'),
                Slider(
                  value: radius,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${radius.toInt()}m',
                  onChanged: (value) => setState(() => radius = value),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alert when entering'),
                  value: alertOnEntry,
                  onChanged: (value) => setState(() => alertOnEntry = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alert when leaving'),
                  value: alertOnExit,
                  onChanged: (value) => setState(() => alertOnExit = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;

                final updatedZone = zone.copyWith(
                  name: nameController.text.trim(),
                  type: selectedType,
                  center: center,
                  radiusMeters: radius,
                  alertOnEntry: alertOnEntry,
                  alertOnExit: alertOnExit,
                );

                try {
                  await geofenceService.updateZone(updatedZone);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update zone: $e')),
                  );
                  return;
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(GeoZone zone, GeofenceServiceWrapper geofenceService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone'),
        content: Text('Are you sure you want to remove "${zone.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await geofenceService.deleteZone(zone.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

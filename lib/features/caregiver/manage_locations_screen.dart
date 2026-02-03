import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/caregiver_provider.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/app_user.dart';

/// Screen for caregivers to manage saved locations
class ManageLocationsScreen extends StatelessWidget {
  const ManageLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Saved Locations'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLocationDialog(context),
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add),
        label: const Text('Add Location'),
      ),
      body: Consumer<CaregiverProvider>(
        builder: (context, provider, child) {
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Home location (special)
                const Text(
                  'HOME',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHomeLocationCard(context, user, provider),

                const SizedBox(height: 24),

                // Other locations
                if (user.savedLocations.isNotEmpty) ...[
                  const Text(
                    'OTHER LOCATIONS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...user.savedLocations.asMap().entries.map((entry) {
                    return _buildLocationCard(
                      context,
                      entry.value,
                      entry.key,
                      provider,
                      user,
                    );
                  }),
                ],

                if (user.savedLocations.isEmpty && user.homeLocation == null)
                  _buildEmptyState(),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeLocationCard(
    BuildContext context,
    AppUser user,
    CaregiverProvider provider,
  ) {
    if (user.homeLocation == null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_home, color: Colors.grey),
          ),
          title: const Text('Add Home Address'),
          subtitle: const Text('Set the user\'s home location'),
          onTap: () => _showEditHomeDialog(context, user, provider),
        ),
      );
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.home, color: AppTheme.primaryGreen),
        ),
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          user.homeAddress ?? 'Address not specified',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditHomeDialog(context, user, provider),
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
    SavedLocation location,
    int index,
    CaregiverProvider provider,
    AppUser user,
  ) {
    final color = AppTheme.tileColors[index % AppTheme.tileColors.length];
    final icon = _getLocationIcon(location.iconName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          location.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          location.address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  _showEditLocationDialog(context, location, provider, user),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () =>
                  _showDeleteConfirmation(context, location, provider, user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.place, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No locations saved',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add locations for quick navigation',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getLocationIcon(String? iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'medical':
        return Icons.local_hospital;
      case 'restaurant':
        return Icons.restaurant;
      case 'store':
        return Icons.store;
      case 'church':
        return Icons.church;
      case 'park':
        return Icons.park;
      case 'gym':
        return Icons.fitness_center;
      case 'friend':
        return Icons.person;
      default:
        return Icons.place;
    }
  }

  void _showEditHomeDialog(
    BuildContext context,
    AppUser user,
    CaregiverProvider provider,
  ) {
    final addressController = TextEditingController(text: user.homeAddress ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Home Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home),
                  hintText: '123 Main St, City, State',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the full address for accurate navigation',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
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
                      if (addressController.text.isEmpty) return;

                      setState(() => isLoading = true);

                      final locationService =
                          Provider.of<LocationService>(context, listen: false);
                      final location = await locationService
                          .getLocationFromAddress(addressController.text.trim());

                      if (!context.mounted) return;

                      if (location == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not find address'),
                          ),
                        );
                        setState(() => isLoading = false);
                        return;
                      }

                      provider.updateManagedUser(user.copyWith(
                        homeLocation: location,
                        homeAddress: addressController.text.trim(),
                      ));

                      Navigator.pop(context);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLocationDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String selectedIcon = 'place';
    bool isLoading = false;

    final icons = [
      'place',
      'work',
      'medical',
      'restaurant',
      'store',
      'church',
      'park',
      'gym',
      'friend'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.label),
                    hintText: 'e.g., Doctor\'s Office',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    prefixIcon: Icon(Icons.place),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: icons.map((iconName) {
                    final isSelected = selectedIcon == iconName;
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = iconName),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getLocationIcon(iconName),
                          color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
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
                      if (nameController.text.isEmpty ||
                          addressController.text.isEmpty) {
                        return;
                      }

                      setState(() => isLoading = true);

                      final locationService =
                          Provider.of<LocationService>(context, listen: false);
                      final geoPoint = await locationService
                          .getLocationFromAddress(addressController.text.trim());

                      if (!context.mounted) return;

                      if (geoPoint == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not find address')),
                        );
                        setState(() => isLoading = false);
                        return;
                      }

                      final provider =
                          Provider.of<CaregiverProvider>(context, listen: false);
                      final user = provider.selectedUser!;

                      final location = SavedLocation(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        address: addressController.text.trim(),
                        location: geoPoint,
                        iconName: selectedIcon,
                        orderIndex: user.savedLocations.length,
                      );

                      provider.addUserLocation(user.id, location);
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

  void _showEditLocationDialog(
    BuildContext context,
    SavedLocation location,
    CaregiverProvider provider,
    AppUser user,
  ) {
    final nameController = TextEditingController(text: location.name);
    final addressController = TextEditingController(text: location.address);
    String selectedIcon = location.iconName ?? 'place';
    bool isLoading = false;

    final icons = [
      'place',
      'work',
      'medical',
      'restaurant',
      'store',
      'church',
      'park',
      'gym',
      'friend'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.place),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: icons.map((iconName) {
                    final isSelected = selectedIcon == iconName;
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = iconName),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getLocationIcon(iconName),
                          color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
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
                      if (nameController.text.isEmpty ||
                          addressController.text.isEmpty) {
                        return;
                      }

                      setState(() => isLoading = true);

                      GeoPoint geoPoint = location.location;
                      if (addressController.text.trim() != location.address) {
                        final locationService = Provider.of<LocationService>(
                            context,
                            listen: false);
                        final newGeoPoint = await locationService
                            .getLocationFromAddress(addressController.text.trim());
                        if (!context.mounted) return;
                        if (newGeoPoint != null) {
                          geoPoint = newGeoPoint;
                        }
                      }

                      final updatedLocation = SavedLocation(
                        id: location.id,
                        name: nameController.text.trim(),
                        address: addressController.text.trim(),
                        location: geoPoint,
                        iconName: selectedIcon,
                        orderIndex: location.orderIndex,
                      );

                      final updatedLocations = user.savedLocations.map((l) {
                        return l.id == location.id ? updatedLocation : l;
                      }).toList();

                      provider.updateManagedUser(
                        user.copyWith(savedLocations: updatedLocations),
                      );
                      Navigator.pop(context);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    SavedLocation location,
    CaregiverProvider provider,
    AppUser user,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to remove ${location.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedLocations =
                  user.savedLocations.where((l) => l.id != location.id).toList();
              provider.updateManagedUser(
                user.copyWith(savedLocations: updatedLocations),
              );
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

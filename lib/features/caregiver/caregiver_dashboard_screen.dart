import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/caregiver_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/app_user.dart';
import '../../core/models/medication.dart';
import '../../core/models/geo_zone.dart';
import '../user_home/user_home_screen.dart';
import 'manage_contacts_screen.dart';
import 'manage_locations_screen.dart';
import 'manage_medications_screen.dart';
import 'manage_reminders_screen.dart';
import 'manage_zones_screen.dart';
import 'app_protection_screen.dart';
import 'sundown_settings_screen.dart';
import 'user_settings_screen.dart';
import 'medical_profile_screen.dart';
import 'user_profile_screen.dart';

/// Main dashboard for caregivers
class CaregiverDashboardScreen extends ConsumerStatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  ConsumerState<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends ConsumerState<CaregiverDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Caregiver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitCaregiverMode,
            tooltip: 'Exit to User Mode',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final caregiverProvider = ref.read(caregiverNotifierProvider);
          if (caregiverProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = caregiverProvider.selectedUser;
          if (user == null) {
            return _buildNoUserSelected();
          }

          return IndexedStack(
            index: _selectedIndex,
            children: [
              _buildOverviewTab(user, caregiverProvider),
              _buildLocationTab(user, caregiverProvider),
              _buildManageTab(user),
              _buildHistoryTab(user, caregiverProvider),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Location',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Manage',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildNoUserSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No user selected',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(AppUser user, CaregiverProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User card
          _buildUserCard(user),
          const SizedBox(height: 20),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Contacts',
                  user.emergencyContacts.length.toString(),
                  Icons.contacts,
                  AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Locations',
                  (user.savedLocations.length + (user.homeLocation != null ? 1 : 0))
                      .toString(),
                  Icons.place,
                  AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medication status
          StreamBuilder<List<MedicationLog>>(
            stream: provider.getMedicationLogs(
              user.id,
              startDate: DateTime.now().subtract(const Duration(days: 1)),
            ),
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              final taken =
                  logs.where((l) => l.status == MedicationLogStatus.taken).length;
              final missed =
                  logs.where((l) => l.status == MedicationLogStatus.missed).length;

              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Taken (24h)',
                      taken.toString(),
                      Icons.check_circle,
                      AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Missed (24h)',
                      missed.toString(),
                      Icons.cancel,
                      missed > 0 ? AppTheme.primaryRed : Colors.grey,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Recent activity
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<GeoZoneEvent>>(
            stream: provider.getZoneEvents(user.id, limit: 5),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('No recent location events'),
                  ),
                );
              }

              return Column(
                children: events.map((event) {
                  return _buildActivityItem(event);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.phoneNumber != null)
                  Text(
                    user.phoneNumber!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(GeoZoneEvent event) {
    final isEntry = event.eventType == GeoZoneEventType.enter;
    final timeStr = DateFormat('MMM d, h:mm a').format(event.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isEntry ? Icons.login : Icons.logout,
            color: isEntry ? AppTheme.primaryGreen : AppTheme.primaryOrange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEntry ? 'Entered zone' : 'Left zone',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab(AppUser user, CaregiverProvider provider) {
    return Column(
      children: [
        // Map
        Expanded(
          child: StreamBuilder<GeoPoint?>(
            stream: provider.watchUserLocation(user.id),
            builder: (context, snapshot) {
              final location = snapshot.data;
              final defaultPosition = user.homeLocation != null
                  ? LatLng(user.homeLocation!.latitude, user.homeLocation!.longitude)
                  : const LatLng(37.7749, -122.4194); // Default to SF

              final userPosition = location != null
                  ? LatLng(location.latitude, location.longitude)
                  : defaultPosition;

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: userPosition,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  // Controller available for future use
                },
                markers: {
                  if (location != null)
                    Marker(
                      markerId: const MarkerId('user'),
                      position: userPosition,
                      infoWindow: InfoWindow(title: user.name),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      ),
                    ),
                  if (user.homeLocation != null)
                    Marker(
                      markerId: const MarkerId('home'),
                      position: LatLng(
                        user.homeLocation!.latitude,
                        user.homeLocation!.longitude,
                      ),
                      infoWindow: const InfoWindow(title: 'Home'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              );
            },
          ),
        ),

        // Location info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin_circle, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder<GeoPoint?>(
                      stream: provider.watchUserLocation(user.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text('Location unknown');
                        }
                        return const Text(
                          'User location updated',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageZonesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Manage Zones'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManageTab(AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildManageItem(
            'Emergency Contacts',
            'Manage people the user can call',
            Icons.contacts,
            AppTheme.primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageContactsScreen()),
            ),
          ),
          _buildManageItem(
            'User Profile',
            'Identity, photos, lost person report',
            Icons.person,
            Colors.indigo,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: user.id),
              ),
            ),
          ),
          _buildManageItem(
            'Saved Locations',
            'Add places for quick navigation',
            Icons.place,
            AppTheme.primaryBlue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageLocationsScreen()),
            ),
          ),
          _buildManageItem(
            'Medical Profile',
            'Health conditions, allergies, prescriptions',
            Icons.medical_information,
            Colors.pink,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MedicalProfileScreen()),
            ),
          ),
          _buildManageItem(
            'Medications',
            'Set up medication schedules',
            Icons.medication,
            AppTheme.primaryOrange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageMedicationsScreen()),
            ),
          ),
          _buildManageItem(
            'Reminders',
            'Create daily tasks and reminders',
            Icons.notifications,
            AppTheme.primaryPurple,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageRemindersScreen()),
            ),
          ),
          _buildManageItem(
            'Safe Zones',
            'Define geofence boundaries',
            Icons.shield,
            AppTheme.primaryTeal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageZonesScreen()),
            ),
          ),
          _buildManageItem(
            'App Protection',
            'Prevent accidental app deletion',
            Icons.security,
            AppTheme.primaryRed,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppProtectionScreen()),
            ),
          ),
          _buildManageItem(
            'Sundown Alerts',
            'Return home before sunset reminders',
            Icons.wb_twilight,
            AppTheme.primaryOrange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SundownSettingsScreen()),
            ),
          ),
          _buildManageItem(
            'User Settings',
            'Customize app behavior',
            Icons.settings,
            Colors.blueGrey,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UserSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildHistoryTab(AppUser user, CaregiverProvider provider) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppTheme.primaryPurple,
            tabs: [
              Tab(text: 'Medications'),
              Tab(text: 'Location'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Medication history
                StreamBuilder<List<MedicationLog>>(
                  stream: provider.getMedicationLogs(user.id),
                  builder: (context, snapshot) {
                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) {
                      return const Center(child: Text('No medication history'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _buildMedicationLogItem(log);
                      },
                    );
                  },
                ),

                // Location history
                StreamBuilder<List<GeoZoneEvent>>(
                  stream: provider.getZoneEvents(user.id),
                  builder: (context, snapshot) {
                    final events = snapshot.data ?? [];
                    if (events.isEmpty) {
                      return const Center(child: Text('No location history'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _buildActivityItem(events[index]);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationLogItem(MedicationLog log) {
    final timeStr = DateFormat('MMM d, h:mm a').format(log.scheduledTime);
    final statusColor = log.status == MedicationLogStatus.taken
        ? AppTheme.primaryGreen
        : log.status == MedicationLogStatus.missed
            ? AppTheme.primaryRed
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.medication, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.status.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (log.photoUrl != null)
            const Icon(Icons.photo, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  void _exitCaregiverMode() async {
    final appState = ref.read(appStateNotifierProvider);
    await appState.setCaregiverMode(false);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UserHomeScreen()),
    );
  }
}

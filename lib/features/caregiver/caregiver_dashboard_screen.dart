import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/caregiver_provider.dart';
import '../../core/providers/quadtrack_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/app_user.dart';
import '../../core/models/medication.dart';
import '../../core/models/geo_zone.dart';
import '../../core/models/quadtrack_device.dart' show DeviceStatus;
import '../battery/battery_status_card.dart';
import '../bouncie/vehicle_status_card.dart';
import '../bouncie/trip_history_screen.dart';
import '../bouncie/vehicle_tracking_screen.dart';
import '../environment/environment_settings_screen.dart';
import '../environment/environment_status_card.dart';
import '../user_home/user_home_screen.dart';
import 'monitoring_settings_screen.dart';
import 'manage_contacts_screen.dart';
import 'manage_locations_screen.dart';
import 'manage_medications_screen.dart';
import '../medication/manage_prescriptions_screen.dart';
import 'manage_reminders_screen.dart';
import 'activity_library_screen.dart';
import 'manage_expenses_screen.dart';
import '../pet_feeding/manage_pet_feeding_screen.dart';
import 'manage_zones_screen.dart';
import 'app_protection_screen.dart';
import 'sundown_settings_screen.dart';
import 'user_settings_screen.dart';
import 'medical_profile_screen.dart';
import 'user_profile_screen.dart';
import 'add_patient_screen.dart';
import 'invite_caregiver_screen.dart';
import 'manage_caregivers_screen.dart';
import 'patients_overview_screen.dart';
import 'redeem_invite_dialog.dart';
import 'account_settings_screen.dart';
import '../onboarding/caregiver_onboarding_screen.dart';
import '../../features/subscription/subscription_status_card.dart';
import '../../features/subscription/paywall_screen.dart';
import '../medical_records/medical_records_screen.dart';
import '../quadtrack/quadtrack_dashboard_screen.dart';
import '../quadtrack/quadtrack_detail_screen.dart';
import '../../core/services/notification_service.dart';

/// Main dashboard for caregivers
class CaregiverDashboardScreen extends ConsumerStatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  ConsumerState<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends ConsumerState<CaregiverDashboardScreen> {
  int _selectedIndex = 0;
  LatLng? _vehiclePosition;

  Function(String?)? _previousNotificationHandler;

  @override
  void initState() {
    super.initState();
    _refreshVehicleLocation();
    _registerFcmToken();
    _wireNotificationTaps();
  }

  /// Route QuadTrack notification taps (`quadtrack:<deviceDocId>`) to the
  /// device detail screen; delegate anything else to the previous handler.
  void _wireNotificationTaps() {
    _previousNotificationHandler = NotificationService.onNotificationTapped;
    NotificationService.onNotificationTapped = (payload) {
      if (payload != null && payload.startsWith('quadtrack:') && mounted) {
        final deviceId = payload.replaceFirst('quadtrack:', '');
        final caregiverId = ref.read(caregiverNotifierProvider).caregiver?.id ??
            ref.read(appStateNotifierProvider).currentCaregiverId ??
            '';
        if (caregiverId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuadTrackDetailScreen(
                deviceId: deviceId,
                caregiverId: caregiverId,
              ),
            ),
          );
          return;
        }
      }
      _previousNotificationHandler?.call(payload);
    };
  }

  /// Store this device's FCM token on the caregiver doc so
  /// notifyCaregivers / Cloud Functions can reach this caregiver.
  /// (saveFCMToken existed but was never called anywhere — no caregiver
  /// ever had a token, so no push ever delivered.)
  Future<void> _registerFcmToken() async {
    try {
      final caregiverId = ref.read(caregiverNotifierProvider).caregiver?.id ??
          ref.read(appStateNotifierProvider).currentCaregiverId;
      if (caregiverId != null && caregiverId.isNotEmpty) {
        await NotificationService.saveFCMToken(
          id: caregiverId,
          isCaregiver: true,
        );
      }
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _openDirectionsToVehicle() async {
    if (_vehiclePosition == null) return;
    final lat = _vehiclePosition!.latitude;
    final lng = _vehiclePosition!.longitude;
    // Apple Maps on iOS, Google Maps on Android
    final uri = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
    );
    final googleUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _refreshVehicleLocation() async {
    try {
      // Per-family Bouncie connection; no connection = no vehicle marker.
      final patientId = ref.read(caregiverNotifierProvider).selectedUser?.id ??
          ref.read(appStateNotifierProvider).currentUserId;
      if (patientId == null) return;
      final connection =
          await ref.read(bouncieConnectionProvider(patientId).future);
      if (connection == null) return;
      final bouncie = bouncieServiceForConnection(
          ref.read(bouncieAppConfigProvider), connection);
      final loc = await bouncie.getVehicleLocation(connection.imei);
      if (loc != null && mounted) {
        setState(() => _vehiclePosition = LatLng(loc.latitude, loc.longitude));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole screen (incl. AppBar title) on patient switch —
    // works now that caregiverNotifierProvider is a ChangeNotifierProvider.
    ref.watch(caregiverNotifierProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: _buildPatientSwitcher(),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'All Patients',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PatientsOverviewScreen()),
            ),
          ),
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

  Widget _buildPatientSwitcher() {
    final caregiverProvider = ref.read(caregiverNotifierProvider);
    final users = caregiverProvider.managedUsers;
    final selected = caregiverProvider.selectedUser;

    if (users.length <= 1) {
      return Text(selected?.name ?? 'Caregiver Dashboard');
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == '_add_patient') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPatientScreen()),
          );
        } else {
          caregiverProvider.selectUserById(value);
          ref.read(appStateNotifierProvider).setCurrentUserId(value);
        }
      },
      itemBuilder: (context) => [
        ...users.map((u) => PopupMenuItem<String>(
              value: u.id,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    child: Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(u.name)),
                  if (u.id == selected?.id)
                    const Icon(Icons.check, color: AppTheme.primaryGreen, size: 20),
                ],
              ),
            )),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '_add_patient',
          child: Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.primaryBlue),
              SizedBox(width: 12),
              Text('Add Patient', style: TextStyle(color: AppTheme.primaryBlue)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              selected?.name ?? 'Dashboard',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 24),
        ],
      ),
    );
  }

  Widget _buildNoUserSelected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'No patients yet',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new patient, or join an existing '
              'care team with an invite code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddPatientScreen()),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Patient'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showRedeemInviteDialog(context, ref),
              icon: const Icon(Icons.qr_code),
              label: const Text('Have an invite code?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(AppUser user, CaregiverProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Setup Guide nudge (hidden once complete or dismissed)
          const SetupProgressCard(),

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

          // Home environment (temp/humidity)
          const EnvironmentStatusCard(),
          const SizedBox(height: 12),

          // Vehicle status
          const VehicleStatusCard(),
          const SizedBox(height: 12),

          // Phone battery
          const BatteryStatusCard(),
          const SizedBox(height: 12),

          // QuadTrack devices
          _buildQuadTrackCard(),
          const SizedBox(height: 12),

          // Subscription status
          const SubscriptionStatusCard(),
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
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String label = 'Active';
                    Color dotColor = Colors.green;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      final lastActive = (data?['lastActiveAt'] as Timestamp?)?.toDate();
                      if (lastActive != null) {
                        final diff = DateTime.now().difference(lastActive);
                        if (diff.inMinutes < 5) {
                          label = 'Active now';
                        } else if (diff.inHours < 1) {
                          label = 'Active ${diff.inMinutes}m ago';
                        } else if (diff.inHours < 24) {
                          label = 'Active ${diff.inHours}h ago';
                          dotColor = Colors.orange;
                        } else {
                          label = 'Last active ${DateFormat.MMMd().format(lastActive)}';
                          dotColor = Colors.grey;
                        }
                      }
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: dotColor, size: 10),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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
                  if (_vehiclePosition != null)
                    Marker(
                      markerId: const MarkerId('vehicle'),
                      position: _vehiclePosition!,
                      infoWindow: const InfoWindow(title: 'Vehicle'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                      onTap: () => _openDirectionsToVehicle(),
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
            'QuadTrack Devices',
            'GPS trackers for patient safety',
            Icons.track_changes,
            AppTheme.primaryTeal,
            () {
              final caregiverId = ref.read(caregiverNotifierProvider).caregiver?.id ??
                  ref.read(appStateNotifierProvider).currentCaregiverId ??
                  '';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuadTrackDashboardScreen(
                    caregiverId: caregiverId,
                  ),
                ),
              );
            },
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
            'Prescriptions',
            'Scan labels, track RX numbers & refills',
            Icons.receipt_long,
            Colors.deepPurple,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManagePrescriptionsScreen()),
            ),
          ),
          _buildManageItem(
            'Medical Records',
            'Export & share records with providers (PDF)',
            Icons.folder_shared,
            Colors.teal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MedicalRecordsScreen()),
            ),
          ),
          _buildManageItem(
            'Expenses & Reimbursements',
            'Track receipts and family repayments',
            Icons.attach_money,
            AppTheme.primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageExpensesScreen()),
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
            'Daily Activities',
            'Purposeful activities for structure and engagement',
            Icons.spa,
            AppTheme.primaryTeal,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ActivityLibraryScreen()),
            ),
          ),
          _buildManageItem(
            'Pet Feeding',
            'Feeding schedules & reminders for pets',
            Icons.pets,
            AppTheme.primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ManagePetFeedingScreen()),
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
            'Setup Guide',
            'Step-by-step checklist to get Lumina ready',
            Icons.checklist,
            AppTheme.primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CaregiverOnboardingScreen()),
            ),
          ),
          _buildManageItem(
            'Account',
            'Sign out or delete your account',
            Icons.manage_accounts,
            AppTheme.primaryPurple,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AccountSettingsScreen()),
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
            'Home Environment',
            'Temperature & humidity in the home',
            Icons.thermostat,
            AppTheme.primaryTeal,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EnvironmentSettingsScreen()),
            ),
          ),
          _buildManageItem(
            'Vehicle Tracking',
            'Connect the family Bouncie account',
            Icons.directions_car,
            AppTheme.primaryBlue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VehicleTrackingScreen()),
            ),
          ),
          _buildManageItem(
            'Trip History',
            'View recent vehicle trips',
            Icons.route,
            AppTheme.primaryBlue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TripHistoryScreen()),
            ),
          ),
          _buildManageItem(
            'Monitoring',
            'Battery & fuel alert thresholds',
            Icons.monitor_heart,
            AppTheme.primaryOrange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MonitoringSettingsScreen()),
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
          _buildManageItem(
            'Caregivers',
            'View and manage linked caregivers',
            Icons.group,
            Colors.deepOrange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageCaregiversScreen()),
            ),
          ),
          _buildManageItem(
            'Invite Caregiver',
            'Share access with family or healthcare',
            Icons.person_add,
            AppTheme.primaryTeal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InviteCaregiverScreen()),
            ),
          ),
          _buildManageItem(
            'Subscription',
            'View plan, upgrade, or restore purchases',
            Icons.star,
            Colors.amber,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PaywallScreen()),
            ),
          ),
        ],
      ),
    );
  }

  /// QuadTrack devices status card for the Overview tab
  Widget _buildQuadTrackCard() {
    final caregiverId = ref.read(caregiverNotifierProvider).caregiver?.id ??
        ref.read(appStateNotifierProvider).currentCaregiverId ??
        '';
    if (caregiverId.isEmpty) return const SizedBox.shrink();

    final devicesAsync = ref.watch(caregiverDevicesProvider(caregiverId));

    return devicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (devices) {
        // QuadTrack is opt-in (hardware still in development) — don't
        // advertise it on the Overview tab until a device is registered.
        // Discovery/registration lives in the Manage tab.
        if (devices.isEmpty) return const SizedBox.shrink();

        final online = devices
            .where((d) => d.status == DeviceStatus.online)
            .length;
        final alerts = devices
            .where((d) =>
                d.status == DeviceStatus.lowBattery ||
                d.status == DeviceStatus.phoneDead ||
                d.status == DeviceStatus.offline)
            .length;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuadTrackDashboardScreen(
                  caregiverId: caregiverId,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.track_changes,
                    color: AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QuadTrack Devices',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      if (devices.isEmpty)
                        Text(
                          'No devices registered',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryLight,
                              ),
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$online online',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (alerts > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: AppTheme.primaryOrange,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$alerts alert${alerts == 1 ? '' : 's'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.primaryOrange),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${devices.length} total',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryLight,
                                    ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
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

  /// Completed-task history from the task_completions log, newest first,
  /// with the AI/caregiver verification verdict and tap-to-view photo.
  Widget _buildTaskHistoryList(AppUser user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('task_completions')
          .where('userId', isEqualTo: user.id)
          .orderBy('completedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No completed tasks yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final completedAt = (d['completedAt'] as Timestamp?)?.toDate();
            final status = d['verificationStatus'] as String?;
            final photoUrl = d['photoUrl'] as String?;
            final statusColor = switch (status) {
              'verified' => AppTheme.primaryGreen,
              'failed' => AppTheme.primaryRed,
              'pending' => Colors.orange,
              _ => Colors.grey,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              // Border-only decoration; the Material below owns the fill
              // (ListTile needs a Material ancestor for ink/background)
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border(
                    left: BorderSide(color: statusColor, width: 4)),
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                leading: Icon(
                  switch (status) {
                    'verified' => Icons.check_circle,
                    'failed' => Icons.error,
                    'pending' => Icons.hourglass_top,
                    _ => Icons.task_alt,
                  },
                  color: statusColor,
                ),
                title: Text(d['title'] ?? 'Task',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${completedAt != null ? DateFormat('MMM d, h:mm a').format(completedAt) : '—'}'
                  '${d['verificationReason'] != null ? '\n${d['verificationReason']}' : ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: photoUrl != null
                    ? const Icon(Icons.photo, color: AppTheme.primaryBlue)
                    : null,
                // Full detail: photo AND complete verdict text (list rows
                // truncate; tapping used to show only the photo, 2026-07-13)
                onTap: () => showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(d['title'] ?? 'Task'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (photoUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(photoUrl,
                                  height: 240,
                                  width: double.maxFinite,
                                  fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            'Completed: '
                            '${completedAt != null ? DateFormat('EEE, MMM d · h:mm a').format(completedAt) : '—'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verification: ${status ?? 'not required'}',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: statusColor),
                          ),
                          if (d['verificationReason'] != null) ...[
                            const SizedBox(height: 4),
                            Text(d['verificationReason'],
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(AppUser user, CaregiverProvider provider) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppTheme.primaryPurple,
            tabs: [
              Tab(text: 'Tasks'),
              Tab(text: 'Medications'),
              Tab(text: 'Location'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Completed-task history (photo verification trail)
                _buildTaskHistoryList(user),
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

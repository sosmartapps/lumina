import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/large_action_tile.dart';
import '../../core/models/app_user.dart';
import '../navigation/navigation_screen.dart';
import '../contacts/contacts_screen.dart';
import '../reminders/reminders_screen.dart';
import '../caregiver/caregiver_login_screen.dart';

/// Main home screen for users - large, accessible tiles
class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  int _caregiverTapCount = 0;

  @override
  void initState() {
    super.initState();
    _speakWelcome();
  }

  void _speakWelcome() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final userProvider = ref.read(userNotifierProvider);
    final tts = ref.read(ttsServiceProvider);

    if (userProvider.user != null &&
        userProvider.user!.settings.voicePromptsEnabled) {
      await tts.speak(
        'Hello ${userProvider.user!.name}. Tap any button to get help.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ref.read(userNotifierProvider),
          builder: (context, child) {
            final userProvider = ref.read(userNotifierProvider);
            final user = userProvider.user;

            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                // Header
                _buildHeader(user),

                // Main grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.9,
                      children: [
                        // Go Home
                        LargeActionTile(
                          title: 'GO HOME',
                          icon: Icons.home,
                          color: AppTheme.tileColors[0],
                          onTap: () => _navigateToHome(user),
                        ),

                        // Call
                        LargeActionTile(
                          title: 'CALL',
                          icon: Icons.phone,
                          color: AppTheme.tileColors[1],
                          onTap: () => _openContacts(),
                        ),

                        // Emergency
                        LargeActionTile(
                          title: 'HELP',
                          subtitle: 'Emergency',
                          icon: Icons.emergency,
                          color: AppTheme.tileColors[2],
                          onTap: () => _callEmergencyContact(user),
                        ),

                        // Medications
                        LargeActionTile(
                          title: 'MEDICINE',
                          icon: Icons.medication,
                          color: AppTheme.tileColors[3],
                          showBadge: true,
                          badgeCount: userProvider.getUpcomingMedications().length,
                          onTap: () => _openReminders(),
                        ),

                        // Places
                        LargeActionTile(
                          title: 'GO TO',
                          subtitle: 'Places',
                          icon: Icons.place,
                          color: AppTheme.tileColors[4],
                          onTap: () => _openNavigation(),
                        ),

                        // Reminders
                        LargeActionTile(
                          title: 'TASKS',
                          icon: Icons.check_circle,
                          color: AppTheme.tileColors[5],
                          showBadge: true,
                          badgeCount: userProvider.getTodayReminders().length,
                          onTap: () => _openReminders(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom quick contacts
                if (user.emergencyContacts.isNotEmpty)
                  _buildQuickContacts(user.emergencyContacts),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppUser user) {
    return GestureDetector(
      onTap: () {
        // Hidden caregiver access (5 taps to access)
        _caregiverTapCount++;
        if (_caregiverTapCount >= 5) {
          _caregiverTapCount = 0;
          _openCaregiverMode();
        }

        // Reset counter after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _caregiverTapCount = 0);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Greeting
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${user.name.split(' ').first}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getTimeGreeting(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Time
            Column(
              children: [
                Text(
                  _formatTime(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickContacts(List<EmergencyContact> contacts) {
    final topContacts = contacts.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'QUICK CALL',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Row(
            children: topContacts.asMap().entries.map((entry) {
              final index = entry.key;
              final contact = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 8,
                    right: index == topContacts.length - 1 ? 0 : 8,
                  ),
                  child: _buildQuickContactButton(contact, index),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactButton(EmergencyContact contact, int index) {
    final color = AppTheme.tileColors[index % AppTheme.tileColors.length];

    return GestureDetector(
      onTap: () => _callContact(contact),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              contact.name.split(' ').first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate() {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _navigateToHome(AppUser user) async {
    HapticFeedback.heavyImpact();

    if (user.homeLocation == null) {
      _showMessage('Home address not set. Ask your caregiver to add it.');
      return;
    }

    final locationService = ref.read(locationServiceProvider);
    final url = await locationService.getGoogleMapsDirectionsUrl(
      destination: user.homeLocation!,
      destinationName: user.homeAddress ?? 'Home',
    );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openContacts() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ContactsScreen()),
    );
  }

  Future<void> _callEmergencyContact(AppUser user) async {
    HapticFeedback.heavyImpact();

    if (user.emergencyContacts.isEmpty) {
      _showMessage('No emergency contacts set.');
      return;
    }

    // Call primary caregiver or first contact
    final contact = user.emergencyContacts.first;
    _callContact(contact);
  }

  Future<void> _callContact(EmergencyContact contact) async {
    HapticFeedback.heavyImpact();

    final tts = ref.read(ttsServiceProvider);
    await tts.speak('Calling ${contact.name}');

    final uri = Uri.parse('tel:${contact.phoneNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openReminders() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RemindersScreen()),
    );
  }

  void _openNavigation() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NavigationScreen()),
    );
  }

  void _openCaregiverMode() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CaregiverLoginScreen()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

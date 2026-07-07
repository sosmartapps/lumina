import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/large_action_tile.dart';
import '../../core/widgets/reminder_popup.dart';
import '../../core/widgets/sundown_alert_popup.dart';
import '../../core/models/app_user.dart';
import '../../core/models/reminder.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sundown_service.dart';
import '../../core/services/device_motion_service.dart';
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

class _UserHomeScreenState extends ConsumerState<UserHomeScreen>
    with WidgetsBindingObserver {
  int _caregiverTapCount = 0;
  bool _sundownPopupShowing = false;
  bool _reminderPopupShowing = false;
  Timer? _reminderCheckTimer;
  StreamSubscription? _reminderSubscription;
  StreamSubscription? _userSettingsSubscription;
  List<Reminder> _todayReminders = [];
  final List<Reminder> _deferredReminders = []; // Home-only reminders waiting for arrival
  bool _wasAtHome = false; // Track home arrival
  final List<_PendingAlert> _alertQueue = []; // Queued alerts to prevent stacking
  StreamSubscription<DateTime>? _motionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speakWelcome();
    _listenForSundownAlerts();
    _listenForUserSettingsChanges();
    _setupReminderSystem();
    _startMotionDetection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _reminderCheckTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // Restart periodic reminder check
      _reminderCheckTimer?.cancel();
      _reminderCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _checkDueReminders();
      });
    }
  }

  void _listenForSundownAlerts() {
    final sundownService = ref.read(sundownServiceProvider);
    sundownService.alertNotifier.addListener(_onSundownAlert);
  }

  /// Listen for user settings changes and propagate to SundownService
  void _listenForUserSettingsChanges() {
    final appState = ref.read(appStateNotifierProvider);
    final userId = appState.currentUserId;
    if (userId == null) return;

    _userSettingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final user = AppUser.fromFirestore(doc);
      final sundownService = ref.read(sundownServiceProvider);
      sundownService.updateUser(user);
    });
  }

  void _onSundownAlert() {
    if (!mounted) return;
    final sundownService = ref.read(sundownServiceProvider);
    final result = sundownService.alertNotifier.value;

    if (result != null && !_sundownPopupShowing) {
      if (_reminderPopupShowing) {
        // Queue sundown alert — shows when reminder popup closes
        _alertQueue.add(_PendingAlert.sundown(result));
      } else {
        _showSundownAlert(result);
      }
    }
  }

  void _showSundownAlert(SundownCheckResult result) {
    final userProvider = ref.read(userNotifierProvider);
    final user = userProvider.user;
    if (user == null || user.homeLocation == null) return;

    _sundownPopupShowing = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SundownAlertPopup(
          userName: user.displayName,
          checkResult: result,
          homeLocation: user.homeLocation!,
          homeAddress: user.homeAddress,
          onDismiss: () {
            Navigator.of(context).pop();
            _sundownPopupShowing = false;
            ref.read(sundownServiceProvider).onAlertDismissed();
          },
        ),
      ),
    ).then((_) {
      _sundownPopupShowing = false;
      _processAlertQueue();
    });
  }

  /// Set up the reminder notification handler and periodic check
  void _setupReminderSystem() {
    final appState = ref.read(appStateNotifierProvider);
    final userId = appState.currentUserId;
    if (userId == null) return;

    // Wire notification tap handler to show ReminderPopup
    NotificationService.onNotificationTapped = (payload) {
      if (payload != null && payload.startsWith('reminder:') && mounted) {
        final reminderId = payload.replaceFirst('reminder:', '');
        _showReminderPopupById(reminderId);
      }
    };

    // Schedule all notifications
    final userProvider = ref.read(userNotifierProvider);
    if (userProvider.user != null) {
      final reminderService = ref.read(reminderServiceProvider);
      reminderService.scheduleAllNotifications(userId, userProvider.user!.displayName);

      // Schedule pet feeding reminders
      final petFeedingService = ref.read(petFeedingServiceProvider);
      petFeedingService.scheduleAllFeedingNotifications(userId);
    }

    // Subscribe to today's reminders for auto-trigger
    final reminderService = ref.read(reminderServiceProvider);
    _reminderSubscription = reminderService.getTodayReminders(userId).listen((reminders) {
      _todayReminders = reminders;
    });

    // Check every 30 seconds if a reminder is due
    _reminderCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDueReminders();
    });
  }

  /// Check if user is within 200m of home
  bool _isUserAtHome() {
    final locationService = ref.read(locationServiceProvider);
    final userProvider = ref.read(userNotifierProvider);
    final user = userProvider.user;
    final position = locationService.lastPosition;

    if (user?.homeLocation == null || position == null) {
      // If we can't determine location, allow reminders to fire
      return true;
    }

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      user!.homeLocation!.latitude,
      user.homeLocation!.longitude,
    );

    return distance <= 200;
  }

  /// Check if any reminder is due and show popup (location-aware)
  void _checkDueReminders() {
    if (!mounted || _reminderPopupShowing) return;

    final isAtHome = _isUserAtHome();

    // If user just arrived home, fire all deferred reminders first
    if (isAtHome && !_wasAtHome && _deferredReminders.isNotEmpty) {
      _wasAtHome = true;
      final next = _deferredReminders.removeAt(0);
      _showReminderPopup(next);
      return;
    }
    _wasAtHome = isAtHome;

    final now = DateTime.now();
    for (final reminder in _todayReminders) {
      if (reminder.completedAt != null) continue;
      if (_deferredReminders.any((d) => d.id == reminder.id)) continue;

      final diff = now.difference(reminder.scheduledTime).inMinutes;
      // Show popup if reminder is due (within 0-5 min window)
      if (diff >= 0 && diff <= 5 && reminder.lastTriggeredAt == null) {
        if (reminder.homeOnly && !isAtHome) {
          // Defer home-only reminders until user arrives home
          _deferredReminders.add(reminder);
          debugPrint('Deferred home-only reminder: ${reminder.title}');
          continue;
        }
        if (_sundownPopupShowing) {
          // Queue reminder — shows when sundown popup closes
          _alertQueue.add(_PendingAlert.reminder(reminder));
          break;
        }
        _showReminderPopup(reminder);
        break;
      }
    }
  }

  /// Show ReminderPopup by fetching reminder from Firestore
  Future<void> _showReminderPopupById(String reminderId) async {
    if (_reminderPopupShowing) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(reminderId)
          .get();
      if (!doc.exists || !mounted) return;
      final reminder = Reminder.fromFirestore(doc);
      _showReminderPopup(reminder);
    } catch (e) {
      debugPrint('Error loading reminder for popup: $e');
    }
  }

  /// Display the full-screen ReminderPopup
  void _showReminderPopup(Reminder reminder) {
    final userProvider = ref.read(userNotifierProvider);
    final user = userProvider.user;
    if (user == null) return;

    _reminderPopupShowing = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ReminderPopup(
          userName: user.displayName,
          title: reminder.title,
          message: reminder.getSpokenMessage(user.displayName),
          reminderType: reminder.type,
          requiresPhoto: reminder.requiresPhoto,
          onDismiss: () {
            Navigator.of(context).pop();
            _reminderPopupShowing = false;
          },
          onSnooze: () {
            Navigator.of(context).pop();
            _reminderPopupShowing = false;
            final reminderService = ref.read(reminderServiceProvider);
            reminderService.snoozeReminder(reminder.id, reminder.snoozeMinutes);
          },
          onComplete: (photoUrl) {
            Navigator.of(context).pop();
            _reminderPopupShowing = false;
            final reminderService = ref.read(reminderServiceProvider);
            reminderService.completeReminder(reminder.id, photoUrl: photoUrl);
          },
        ),
      ),
    ).then((_) {
      _reminderPopupShowing = false;
      // Process queued alerts first (e.g. sundown alert waiting)
      if (_alertQueue.isNotEmpty) {
        _processAlertQueue();
      } else if (_deferredReminders.isNotEmpty && _isUserAtHome()) {
        // Then show deferred home-only reminders
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_reminderPopupShowing && !_sundownPopupShowing) {
            final next = _deferredReminders.removeAt(0);
            _showReminderPopup(next);
          }
        });
      }
    });
  }

  /// Process the next queued alert after a popup closes
  void _processAlertQueue() {
    if (_alertQueue.isEmpty || !mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _reminderPopupShowing || _sundownPopupShowing) return;
      final next = _alertQueue.removeAt(0);
      if (next.sundownResult != null) {
        _showSundownAlert(next.sundownResult!);
      } else if (next.reminder != null) {
        _showReminderPopup(next.reminder!);
      }
    });
  }

  /// Start accelerometer-based pickup detection if enabled.
  void _startMotionDetection() {
    final userProvider = ref.read(userNotifierProvider);
    final user = userProvider.user;
    if (user == null || !user.settings.motionDetectionEnabled) return;

    final appState = ref.read(appStateNotifierProvider);
    final userId = appState.currentUserId;
    if (userId == null) return;

    final motionService = ref.read(deviceMotionServiceProvider);
    motionService.start(userId);

    _motionSubscription = motionService.onPickup.listen((pickupTime) {
      if (!mounted) return;
      // If within the morning window, check for pending medications
      if (DeviceMotionService.isInMorningWindow(user.settings)) {
        _checkDueReminders();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderCheckTimer?.cancel();
    _reminderSubscription?.cancel();
    _userSettingsSubscription?.cancel();
    _motionSubscription?.cancel();
    final sundownService = ref.read(sundownServiceProvider);
    sundownService.alertNotifier.removeListener(_onSundownAlert);
    // Stop motion detection
    ref.read(deviceMotionServiceProvider).stop();
    super.dispose();
  }

  void _speakWelcome() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final userProvider = ref.read(userNotifierProvider);
    final tts = ref.read(ttsServiceProvider);

    if (userProvider.user != null &&
        userProvider.user!.settings.voicePromptsEnabled) {
      await tts.speak(
        'Hello ${userProvider.user!.displayName}. Tap any button to get help.',
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

                // Main grid — fixed 2×3, sized to always fit on screen with
                // no scrolling (users with cognitive impairments should see
                // every action at once).
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: LargeActionTile(
                                  title: 'GO HOME',
                                  icon: Icons.home,
                                  color: AppTheme.tileColors[0],
                                  onTap: () => _navigateToHome(user),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LargeActionTile(
                                  title: 'CALL',
                                  icon: Icons.phone,
                                  color: AppTheme.tileColors[1],
                                  onTap: () => _openContacts(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: LargeActionTile(
                                  title: 'HELP',
                                  subtitle: 'Emergency',
                                  icon: Icons.emergency,
                                  color: AppTheme.tileColors[2],
                                  onTap: () => _callEmergencyContact(user),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LargeActionTile(
                                  title: 'MEDICINE',
                                  icon: Icons.medication,
                                  color: AppTheme.tileColors[3],
                                  showBadge: true,
                                  badgeCount:
                                      userProvider.getUpcomingMedications().length,
                                  onTap: () => _openReminders(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: LargeActionTile(
                                  title: 'GO TO',
                                  subtitle: 'Places',
                                  icon: Icons.place,
                                  color: AppTheme.tileColors[4],
                                  onTap: () => _openNavigation(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LargeActionTile(
                                  title: 'TASKS',
                                  icon: Icons.check_circle,
                                  color: AppTheme.tileColors[5],
                                  showBadge: true,
                                  badgeCount:
                                      userProvider.getTodayReminders().length,
                                  onTap: () => _openReminders(),
                                ),
                              ),
                            ],
                          ),
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

            // Greeting — each line scales down to fit rather than
            // wrapping word-per-line when the clock takes its share.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hello, ${user.displayName}!',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _getTimeGreeting(),
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                      ),
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

/// Represents a queued alert (sundown or reminder) waiting to be shown.
class _PendingAlert {
  final SundownCheckResult? sundownResult;
  final Reminder? reminder;

  _PendingAlert.sundown(SundownCheckResult result)
      : sundownResult = result,
        reminder = null;

  _PendingAlert.reminder(Reminder r)
      : reminder = r,
        sundownResult = null;
}

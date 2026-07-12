import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart' show bootReady;
import '../../core/providers/providers.dart';
import '../../core/services/background_service.dart';
import '../../core/services/deep_link_service.dart';
import '../../core/theme/app_theme.dart';
import '../setup/setup_screen.dart';
import '../user_home/user_home_screen.dart';
import '../caregiver/caregiver_login_screen.dart';
import '../caregiver/caregiver_dashboard_screen.dart';

/// Splash screen that handles app initialization
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs one splash init step with a hard timeout so a hung plugin or
  /// network call can never trap the user on the spinner (same pattern as
  /// _postBootInit in main.dart; added after the 2026-07-06 Android hang).
  Future<void> _step(
    String name,
    Future<void> Function() task, {
    int timeoutSeconds = 15,
  }) async {
    debugPrint('SPLASH: $name…');
    try {
      await task().timeout(Duration(seconds: timeoutSeconds));
      debugPrint('SPLASH: $name OK');
    } catch (e) {
      debugPrint('SPLASH: $name FAILED: $e');
    }
  }

  Future<void> _initializeApp() async {
    // Add a slight delay for splash visibility
    await Future.delayed(const Duration(milliseconds: 1000));

    // Wait for post-boot init (anonymous auth etc.) so Firestore reads
    // below don't race it. Every boot step is timeboxed, so this always
    // completes.
    await bootReady;

    if (!mounted) return;

    // Initialize app state
    final appState = ref.read(appStateNotifierProvider);
    await _step('app state', () => appState.initialize(), timeoutSeconds: 10);

    if (!mounted) return;

    // Request permissions (a permission dialog can take as long as the
    // user needs, but a hung platform channel must not block forever)
    final locationService = ref.read(locationServiceProvider);
    await _step(
        'location permission', () => locationService.checkAndRequestPermission(),
        timeoutSeconds: 60);

    if (!mounted) return;

    // Navigate based on setup state
    if (appState.isSetupComplete && appState.currentUserId != null) {
      // Load user data
      final userProv = ref.read(userNotifierProvider);
      await _step('load user', () async {
        await userProv.loadUser(appState.currentUserId!);
        userProv.listenToUser(appState.currentUserId!);
      });

      // Start location tracking
      await _step('location tracking',
          () => locationService.startTracking(userId: appState.currentUserId!),
          timeoutSeconds: 10);

      if (!mounted) return;

      // Initialize geofencing
      await _step(
          'geofencing',
          () =>
              ref.read(geofenceServiceProvider).initialize(appState.currentUserId!),
          timeoutSeconds: 10);

      if (!mounted) return;

      // Initialize sundown monitoring
      if (userProv.user != null) {
        await _step(
            'sundown',
            () => ref
                .read(sundownServiceProvider)
                .initialize(appState.currentUserId!, userProv.user!),
            timeoutSeconds: 10);
      }

      // Schedule all reminder notifications
      if (userProv.user != null) {
        await _step(
            'reminder notifications',
            () => ref.read(reminderServiceProvider).scheduleAllNotifications(
                  appState.currentUserId!,
                  userProv.user!.name,
                ),
            timeoutSeconds: 10);

        // Schedule pet feeding reminders
        await _step(
            'pet feeding notifications',
            () => ref
                .read(petFeedingServiceProvider)
                .scheduleAllFeedingNotifications(appState.currentUserId!),
            timeoutSeconds: 10);
      }

      // Initialize subscription status
      await _step('subscription', () async {
        final subService = ref.read(subscriptionServiceProvider);
        await subService.initialize(appState.currentUserId!);
        final subProvider = ref.read(subscriptionNotifierProvider);
        await subProvider.loadSubscription(appState.currentUserId!);
      }, timeoutSeconds: 10);

      // Start background monitoring service
      await _step('background monitoring',
          () => BackgroundMonitoringService.start(),
          timeoutSeconds: 10);

      if (!mounted) return;

      if (appState.isCaregiverMode && appState.currentCaregiverId != null) {
        // Caregiver mode
        final caregiverProv = ref.read(caregiverNotifierProvider);
        await caregiverProv.loadCaregiver(appState.currentCaregiverId!);

        // Restore last-viewed patient selection
        if (appState.currentUserId != null) {
          caregiverProv.selectUserById(appState.currentUserId!);
        }

        // Check for pending invite deep link
        final deepLinkService = DeepLinkService();
        if (deepLinkService.pendingInviteCode != null) {
          try {
            final inviteService = ref.read(inviteServiceProvider);
            final patients = await inviteService.redeemInviteCode(
              code: deepLinkService.pendingInviteCode!,
              caregiverId: appState.currentCaregiverId!,
            );
            deepLinkService.clearPendingInviteCode();
            await caregiverProv.loadCaregiver(appState.currentCaregiverId!);
            caregiverProv.selectUserById(patients.first.id);
            _navigateTo(const CaregiverDashboardScreen());
          } catch (e) {
            debugPrint('Deep link invite redeem failed: $e');
            deepLinkService.clearPendingInviteCode();
            _navigateTo(const CaregiverLoginScreen());
          }
        } else {
          _navigateTo(const CaregiverLoginScreen());
        }
      } else {
        // User mode
        _navigateTo(const UserHomeScreen());
      }
    } else {
      // First time setup
      _navigateTo(const SetupScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lumina brand mark on a white card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/lumina_mark.png',
                        width: 96,
                        height: 96,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // App name
                    const Text(
                      'Lumina',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Daily Care Assistant',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

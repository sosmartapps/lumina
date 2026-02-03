import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/caregiver_provider.dart';
import '../../core/services/location_service.dart';
import '../../core/services/geofence_service.dart';
import '../../core/theme/app_theme.dart';
import '../setup/setup_screen.dart';
import '../user_home/user_home_screen.dart';
import '../caregiver/caregiver_login_screen.dart';

/// Splash screen that handles app initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
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

  Future<void> _initializeApp() async {
    // Add a slight delay for splash visibility
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Initialize app state
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    await appState.initialize();

    if (!mounted) return;

    // Request permissions
    final locationService = Provider.of<LocationService>(context, listen: false);
    await locationService.checkAndRequestPermission();

    if (!mounted) return;

    // Navigate based on setup state
    if (appState.isSetupComplete && appState.currentUserId != null) {
      // Load user data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser(appState.currentUserId!);
      userProvider.listenToUser(appState.currentUserId!);

      // Start location tracking
      await locationService.startTracking(userId: appState.currentUserId!);

      if (!mounted) return;

      // Initialize geofencing
      final geofenceService =
          Provider.of<GeofenceServiceWrapper>(context, listen: false);
      await geofenceService.initialize(appState.currentUserId!);

      if (!mounted) return;

      if (appState.isCaregiverMode && appState.currentCaregiverId != null) {
        // Caregiver mode
        final caregiverProvider =
            Provider.of<CaregiverProvider>(context, listen: false);
        await caregiverProvider.loadCaregiver(appState.currentCaregiverId!);

        _navigateTo(const CaregiverLoginScreen());
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
                    // App icon
                    Container(
                      padding: const EdgeInsets.all(24),
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
                      child: const Icon(
                        Icons.favorite,
                        size: 80,
                        color: AppTheme.primaryBlue,
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

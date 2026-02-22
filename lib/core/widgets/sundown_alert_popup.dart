import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../services/sundown_service.dart';
import '../theme/app_theme.dart';

/// Full-screen persistent alert telling the user to head home before sunset.
class SundownAlertPopup extends ConsumerStatefulWidget {
  final String userName;
  final SundownCheckResult checkResult;
  final GeoPoint homeLocation;
  final String? homeAddress;
  final VoidCallback onDismiss;

  const SundownAlertPopup({
    super.key,
    required this.userName,
    required this.checkResult,
    required this.homeLocation,
    this.homeAddress,
    required this.onDismiss,
  });

  @override
  ConsumerState<SundownAlertPopup> createState() => _SundownAlertPopupState();
}

class _SundownAlertPopupState extends ConsumerState<SundownAlertPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    // Speak alert immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playVoiceAlert();
    });

    // Repeat voice alert every 30 seconds
    _repeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _playVoiceAlert();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _repeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _playVoiceAlert() async {
    final tts = ref.read(ttsServiceProvider);

    String message;
    switch (widget.checkResult.alertLevel) {
      case 3:
        message = '${widget.userName}, it\'s getting dark. You need to go home now.';
        break;
      case 2:
        message = '${widget.userName}, you need to go home now. The sun is setting very soon.';
        break;
      default:
        message = '${widget.userName}, it\'s getting late. You should start heading home now.';
    }

    await tts.speak(message);
    HapticFeedback.heavyImpact();
  }

  Color _getAlertColor() {
    switch (widget.checkResult.alertLevel) {
      case 3:
        return AppTheme.primaryRed;
      case 2:
        return Colors.deepOrange;
      default:
        return AppTheme.primaryOrange;
    }
  }

  String _getTitle() {
    switch (widget.checkResult.alertLevel) {
      case 3:
        return "IT'S GETTING DARK";
      case 2:
        return 'GO HOME NOW!';
      default:
        return 'TIME TO HEAD HOME';
    }
  }

  String _getMessage() {
    final result = widget.checkResult;
    if (result.alertLevel == 3) {
      return 'The sun has set. It will take about ${result.estimatedTravelMinutes} minutes to get home.';
    }
    return 'The sun sets in ${result.minutesToSunset} minutes. '
        'It will take about ${result.estimatedTravelMinutes} minutes to get home.';
  }

  Future<void> _navigateHome() async {
    HapticFeedback.heavyImpact();

    final locationService = ref.read(locationServiceProvider);
    final tts = ref.read(ttsServiceProvider);

    final travelModeStr =
        widget.checkResult.travelMode == TravelMode.driving ? 'driving' : 'walking';

    await tts.speak('Getting directions to Home');

    final url = await locationService.getGoogleMapsDirectionsUrl(
      destination: widget.homeLocation,
      origin: widget.checkResult.currentLocation,
      destinationName: widget.homeAddress ?? 'Home',
      travelMode: travelModeStr,
    );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getAlertColor();

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black87,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with hidden caregiver close (double tap)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onDoubleTap: widget.onDismiss,
                      child: const SizedBox(width: 48, height: 48),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated sunset icon
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                      alpha: 0.3 + (_pulseAnimation.value * 0.3)),
                                  blurRadius: 30 + (_pulseAnimation.value * 20),
                                  spreadRadius: _pulseAnimation.value * 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.wb_twilight,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Title
                    Text(
                      _getTitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _getMessage(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Travel mode indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.checkResult.travelMode == TravelMode.driving
                              ? Icons.directions_car
                              : Icons.directions_walk,
                          color: Colors.white54,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.checkResult.travelMode == TravelMode.driving
                              ? 'Driving'
                              : 'Walking',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // GO HOME button
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton(
                        onPressed: _navigateHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home, size: 36),
                            SizedBox(width: 12),
                            Text(
                              'GO HOME',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // I'M HEADING HOME dismiss button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onDismiss();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 32),
                            SizedBox(width: 12),
                            Text(
                              "I'M HEADING HOME",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

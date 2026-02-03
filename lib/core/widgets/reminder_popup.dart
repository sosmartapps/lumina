import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/reminder.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Full-screen reminder popup with voice and visual alerts
class ReminderPopup extends StatefulWidget {
  final String userName;
  final String title;
  final String message;
  final ReminderType reminderType;
  final bool requiresPhoto;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;
  final Function(String? photoUrl)? onComplete;

  const ReminderPopup({
    super.key,
    required this.userName,
    required this.title,
    required this.message,
    required this.reminderType,
    this.requiresPhoto = false,
    required this.onDismiss,
    required this.onSnooze,
    this.onComplete,
  });

  @override
  State<ReminderPopup> createState() => _ReminderPopupState();
}

class _ReminderPopupState extends State<ReminderPopup>
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

    // Start voice alert
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
    final tts = Provider.of<TTSService>(context, listen: false);

    if (widget.reminderType == ReminderType.medication) {
      await tts.speakMedicationReminder(
        userName: widget.userName,
        medicationName: widget.title,
      );
    } else {
      await tts.speakReminder(
        userName: widget.userName,
        message: widget.message,
      );
    }

    // Vibrate
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getReminderColor();

    return PopScope(
      canPop: false, // Prevent back button dismiss
      child: Material(
        color: Colors.black87,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with close (for caregivers only)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Hidden close for caregivers (triple tap)
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
                    // Animated icon
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
                                  color: color.withValues(alpha:
                                      0.3 + (_pulseAnimation.value * 0.3)),
                                  blurRadius: 30 + (_pulseAnimation.value * 20),
                                  spreadRadius: _pulseAnimation.value * 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getReminderIcon(),
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
                      widget.title,
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
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Main action button
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          if (widget.requiresPhoto && widget.onComplete != null) {
                            _showPhotoCapture();
                          } else {
                            widget.onComplete?.call(null);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 36),
                            const SizedBox(width: 12),
                            Text(
                              widget.requiresPhoto ? 'DONE - TAKE PHOTO' : 'DONE',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Snooze button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onSnooze();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.snooze, size: 32),
                            SizedBox(width: 12),
                            Text(
                              'REMIND ME LATER',
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

  void _showPhotoCapture() {
    // Navigate to photo capture screen
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PhotoCaptureScreen(
          title: 'Show Empty ${widget.title}',
          instructions: 'Take a photo of the empty pill container',
          onPhotoTaken: (photoUrl) {
            Navigator.of(context).pop();
            widget.onComplete?.call(photoUrl);
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Color _getReminderColor() {
    switch (widget.reminderType) {
      case ReminderType.medication:
        return AppTheme.primaryOrange;
      case ReminderType.petCare:
        return AppTheme.primaryPurple;
      case ReminderType.mealTime:
        return AppTheme.primaryGreen;
      case ReminderType.hydration:
        return AppTheme.primaryTeal;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getReminderIcon() {
    switch (widget.reminderType) {
      case ReminderType.medication:
        return Icons.medication;
      case ReminderType.petCare:
        return Icons.pets;
      case ReminderType.mealTime:
        return Icons.restaurant;
      case ReminderType.hydration:
        return Icons.water_drop;
      case ReminderType.exercise:
        return Icons.fitness_center;
      case ReminderType.appointment:
        return Icons.event;
      default:
        return Icons.notifications_active;
    }
  }
}

/// Photo capture screen for verification
class PhotoCaptureScreen extends StatefulWidget {
  final String title;
  final String instructions;
  final Function(String) onPhotoTaken;
  final VoidCallback onCancel;

  const PhotoCaptureScreen({
    super.key,
    required this.title,
    required this.instructions,
    required this.onPhotoTaken,
    required this.onCancel,
  });

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Camera initialization would go here
    // Using image_picker for simplicity
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Camera preview area
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.instructions,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Capture button
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  // Simulate photo capture
                  // In real implementation, use image_picker or camera package
                  widget.onPhotoTaken('photo_url_placeholder');
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryBlue, width: 4),
                  ),
                  child: const Icon(
                    Icons.camera,
                    size: 40,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

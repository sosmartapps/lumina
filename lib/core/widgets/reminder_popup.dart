import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
// image_picker kept in pubspec for caregiver screens (profile, receipt, etc.)
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../providers/providers.dart';
import '../services/photo_match_service.dart';
import '../theme/app_theme.dart';

/// Full-screen reminder popup with voice and visual alerts
class ReminderPopup extends ConsumerStatefulWidget {
  final String userName;
  final String title;
  final String message;
  final ReminderType reminderType;
  final bool requiresPhoto;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;
  /// Called with the completion photo URL and its on-device perceptual
  /// hash (both null for non-photo tasks).
  final Function(String? photoUrl, String? photoHash)? onComplete;

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
  ConsumerState<ReminderPopup> createState() => _ReminderPopupState();
}

class _ReminderPopupState extends ConsumerState<ReminderPopup>
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
    final tts = ref.read(ttsServiceProvider);

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
                            widget.onComplete?.call(null, null);
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
                            // Flexible+FittedBox: survives large text
                            // scale (overflowed 15px at 1.2x, 2026-07-12)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.requiresPhoto
                                      ? 'DONE - TAKE PHOTO'
                                      : 'DONE',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
    final userId = ref.read(appStateNotifierProvider).currentUserId;
    final (photoTitle, photoInstructions) = switch (widget.reminderType) {
      ReminderType.medication => (
          'Show Empty ${widget.title}',
          'Take a photo of the empty pill container'
        ),
      ReminderType.petCare => (
          'Show the Pet Bowls',
          'Take a photo of the food and water in the bowls'
        ),
      ReminderType.mealTime => (
          'Show Your Meal',
          'Take a photo of your food or finished plate'
        ),
      ReminderType.hydration => (
          'Show Your Drink',
          'Take a photo of your glass or bottle'
        ),
      _ => (
          "Show It's Done",
          'Take a photo showing "${widget.title}" is complete'
        ),
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PhotoCaptureScreen(
          title: photoTitle,
          instructions: photoInstructions,
          userId: userId,
          onPhotoTaken: (photoUrl, photoHash) {
            Navigator.of(context).pop();
            // Schedule onComplete for the next frame so the
            // PhotoCaptureScreen pop finishes before the
            // ReminderPopup pop starts (double-pop race fix).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onComplete?.call(photoUrl, photoHash);
            });
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

/// One-tap photo capture for task verification.
/// Full-screen camera preview with a single shutter button — no system
/// camera dialog, no preview/confirm step. Tap shutter → auto-uploads →
/// "ALL DONE!" → dismisses.
class PhotoCaptureScreen extends StatefulWidget {
  final String title;
  final String instructions;
  final Function(String url, String? hash) onPhotoTaken;
  final VoidCallback onCancel;
  final String? userId;

  const PhotoCaptureScreen({
    super.key,
    required this.title,
    required this.instructions,
    required this.onPhotoTaken,
    required this.onCancel,
    this.userId,
  });

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isUploading = false;
  bool _uploadSucceeded = false;
  bool _isTakingPicture = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  Future<void> _capture() async {
    if (_isTakingPicture || _controller == null) return;
    _isTakingPicture = true;
    HapticFeedback.heavyImpact();

    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;
      setState(() => _isUploading = true);
      await _upload(File(xFile.path));
    } catch (e) {
      _isTakingPicture = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _upload(File photo) async {
    try {
      final photoId = const Uuid().v4();
      final filename = 'med_verify_$photoId.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('medication_photos')
          .child(widget.userId ?? 'unknown')
          .child(filename);

      final imageBytes = await photo.readAsBytes();
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();
      final photoHash = await PhotoMatchService.computeDHash(photo);
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadSucceeded = true;
        });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 2200));
      }
      widget.onPhotoTaken(downloadUrl, photoHash);
    } catch (e) {
      _isTakingPicture = false;
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uploadSucceeded) {
      return Scaffold(
        backgroundColor: AppTheme.primaryGreen,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    size: 140, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'ALL DONE!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Great job! Your photo was sent to your care team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isUploading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
              SizedBox(height: 24),
              Text('Saving photo...',
                  style: TextStyle(color: Colors.white70, fontSize: 22)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? Center(
              child: Text(_error!,
                  style: const TextStyle(color: Colors.white, fontSize: 20)))
          : _controller == null || !_controller!.value.isInitialized
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    // Instructions at top
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.instructions,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                        ),
                      ),
                    ),
                    // Shutter button at bottom
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 5),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

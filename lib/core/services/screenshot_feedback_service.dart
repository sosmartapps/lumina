import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service that detects when screenshots are taken and offers to send feedback.
///
/// Similar to TestFlight's screenshot feedback feature - when a user takes a
/// screenshot while using the app, this service can automatically prompt them
/// to send it as feedback to the developer.
///
/// This is particularly useful for the Lumina app to allow caregivers
/// to easily report bugs or suggest improvements.
class ScreenshotFeedbackService {
  ScreenshotFeedbackService({
    required this.onFeedbackRequested,
    this.enabled = true,
    this.autoPrompt = true,
    this.promptDelay = const Duration(milliseconds: 500),
  });

  /// Callback when user wants to send feedback with a screenshot
  final Future<void> Function(File? screenshot) onFeedbackRequested;

  /// Whether screenshot detection is enabled
  final bool enabled;

  /// Whether to automatically show feedback prompt after screenshot
  final bool autoPrompt;

  /// Delay before showing prompt after screenshot is taken
  final Duration promptDelay;

  StreamSubscription<void>? _subscription;
  File? _latestScreenshot;

  /// Initialize the screenshot listener
  void initialize() {
    if (!enabled) return;

    // Listen for screenshot events on iOS
    if (Platform.isIOS) {
      _initializeIOS();
    } else if (Platform.isAndroid) {
      _initializeAndroid();
    }
  }

  /// Initialize iOS screenshot detection
  void _initializeIOS() {
    // Use method channel to listen for UIApplication.userDidTakeScreenshotNotification
    const channel = MethodChannel('com.carecompanion/screenshot');

    channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshot') {
        await _handleScreenshotTaken();
      }
    });

    // Request native iOS to start listening
    channel.invokeMethod('startListening');
  }

  /// Initialize Android screenshot detection
  void _initializeAndroid() {
    // Android screenshot detection uses ContentObserver to monitor MediaStore
    const channel = MethodChannel('com.carecompanion/screenshot');

    channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshot') {
        await _handleScreenshotTaken();
      }
    });

    // Request native Android to start listening
    channel.invokeMethod('startListening');
  }

  /// Handle when a screenshot is detected
  Future<void> _handleScreenshotTaken() async {
    try {
      // Try to get the most recent screenshot from the system
      final screenshot = await _getMostRecentScreenshot();
      _latestScreenshot = screenshot;

      if (autoPrompt) {
        // Wait a moment for the screenshot to be saved
        await Future.delayed(promptDelay);

        // Show feedback prompt
        await onFeedbackRequested(screenshot);
      }
    } catch (e) {
      // Silent fail - don't interrupt user experience
      debugPrint('Screenshot feedback error: $e');
    }
  }

  /// Attempt to get the most recent screenshot from the device
  Future<File?> _getMostRecentScreenshot() async {
    try {
      // Get the screenshot from the native platform
      const channel = MethodChannel('com.carecompanion/screenshot');
      final path = await channel.invokeMethod<String>('getLatestScreenshot');

      if (path != null) {
        return File(path);
      }
    } catch (e) {
      debugPrint('Could not retrieve screenshot: $e');
    }

    return null;
  }

  /// Manually trigger feedback with optional screenshot
  Future<void> sendFeedback({File? screenshot}) async {
    await onFeedbackRequested(screenshot ?? _latestScreenshot);
  }

  /// Dispose of resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;

    // Stop native listeners
    try {
      const channel = MethodChannel('com.carecompanion/screenshot');
      channel.invokeMethod('stopListening');
    } catch (_) {}
  }
}

/// Widget that wraps your app and enables screenshot feedback
class ScreenshotFeedbackWrapper extends StatefulWidget {
  const ScreenshotFeedbackWrapper({
    super.key,
    required this.child,
    required this.onFeedbackRequested,
    this.enabled = true,
    this.autoPrompt = true,
  });

  final Widget child;
  final Future<void> Function(BuildContext context, File? screenshot)
      onFeedbackRequested;
  final bool enabled;
  final bool autoPrompt;

  @override
  State<ScreenshotFeedbackWrapper> createState() =>
      _ScreenshotFeedbackWrapperState();
}

class _ScreenshotFeedbackWrapperState extends State<ScreenshotFeedbackWrapper> {
  late ScreenshotFeedbackService _service;

  @override
  void initState() {
    super.initState();

    _service = ScreenshotFeedbackService(
      enabled: widget.enabled,
      autoPrompt: widget.autoPrompt,
      onFeedbackRequested: (screenshot) async {
        if (!mounted) return;
        await widget.onFeedbackRequested(context, screenshot);
      },
    );

    _service.initialize();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Show a bottom sheet prompting user to send feedback with screenshot
Future<void> showScreenshotFeedbackPrompt({
  required BuildContext context,
  required VoidCallback onSendFeedback,
  File? screenshot,
}) async {
  await showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Screenshot preview
            if (screenshot != null) ...[
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    screenshot,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Send Feedback?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              screenshot != null
                  ? 'Share this screenshot with the developer to report a bug or suggest an improvement.'
                  : 'Send feedback to the developer about this app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Send Feedback button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onSendFeedback();
                },
                icon: const Icon(Icons.feedback),
                label: const Text('Send Feedback'),
              ),
            ),
            const SizedBox(height: 8),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not Now'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

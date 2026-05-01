import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class ScreenshotService {
  /// Wrap your app's root widget with this controller in main.dart so
  /// screenshots can be captured from anywhere.
  static final ScreenshotController controller = ScreenshotController();

  /// Captures the current screen. Returns null if capture fails.
  static Future<File?> capture(BuildContext context) async {
    try {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final imageBytes = await controller.capture(pixelRatio: pixelRatio);
      if (imageBytes == null) return null;

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/screenshot_$timestamp.png');
      await file.writeAsBytes(imageBytes);
      return file;
    } catch (_) {
      return null;
    }
  }
}

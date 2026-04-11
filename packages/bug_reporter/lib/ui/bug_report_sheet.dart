import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/bug_report.dart';
import '../models/report_type.dart';
import '../services/report_uploader.dart';
import '../services/screenshot_service.dart';
import '../services/voice_recorder.dart';
import 'photo_picker_widget.dart';

class BugReportSheet extends StatefulWidget {
  final String? crashLog;
  final bool isCrashReport;
  final File? autoScreenshot;

  const BugReportSheet({
    super.key,
    this.crashLog,
    this.isCrashReport = false,
    this.autoScreenshot,
  });

  /// Convenience method to capture screenshot + show sheet in one call.
  static Future<void> show(
    BuildContext context, {
    String? crashLog,
    bool isCrashReport = false,
  }) async {
    final screenshot = await ScreenshotService.capture(context);
    if (!context.mounted) return;

    // Guard against missing Navigator (e.g. when called from
    // PlatformDispatcher.onError before the widget tree is ready).
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      debugPrint('BugReportSheet.show: no Navigator found — skipping.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BugReportSheet(
        crashLog: crashLog,
        isCrashReport: isCrashReport,
        autoScreenshot: screenshot,
      ),
    );
  }

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  final _descController = TextEditingController();
  final _voiceRecorder = VoiceRecorder();
  final _userPhotos = <File>[];

  ReportType _selectedType = ReportType.bug;
  bool _isRecording = false;
  bool _isSubmitting = false;
  String _voiceTranscript = '';

  @override
  void initState() {
    super.initState();
    if (widget.isCrashReport) _selectedType = ReportType.crash;
    _voiceRecorder.initialize();
  }

  @override
  void dispose() {
    _descController.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_isRecording) {
      final result = await _voiceRecorder.stopListening();
      setState(() {
        _isRecording = false;
        _voiceTranscript = result;
        if (result.isNotEmpty) {
          _descController.text =
              '${_descController.text}\n$result'.trimLeft();
        }
      });
    } else {
      setState(() => _isRecording = true);
      await _voiceRecorder.startListening(
        onResult: (t) => setState(() => _voiceTranscript = t),
      );
    }
  }

  /// Cross-platform device info extraction.
  Future<({String model, String osVersion})> _getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return (model: info.utsname.machine, osVersion: info.systemVersion);
    } else if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return (
        model: '${info.manufacturer} ${info.model}',
        osVersion: 'Android ${info.version.release} (SDK ${info.version.sdkInt})',
      );
    }
    return (model: 'Unknown', osVersion: 'Unknown');
  }

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty && widget.crashLog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = await _getDeviceInfo();

    final report = BugReport(
      id: const Uuid().v4(),
      type: _selectedType,
      description: _descController.text.trim(),
      voiceTranscript: _voiceTranscript.isEmpty ? null : _voiceTranscript,
      screenshots:
          widget.autoScreenshot != null ? [widget.autoScreenshot!] : [],
      userPhotos: _userPhotos,
      crashLog: widget.crashLog,
      appName: packageInfo.appName,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      deviceModel: deviceInfo.model,
      osVersion: deviceInfo.osVersion,
      timestamp: DateTime.now(),
    );

    final success = await ReportUploader.upload(report);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Report submitted. Thank you!'
            : 'Saved — will retry when online.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                widget.isCrashReport
                    ? '💥 App crashed — want to report it?'
                    : '📋 Submit a Report',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Type selector
              SegmentedButton<ReportType>(
                segments: ReportType.values
                    .map((t) => ButtonSegment(
                          value: t,
                          label: Text(t.label),
                        ))
                    .toList(),
                selected: {_selectedType},
                onSelectionChanged: (set) =>
                    setState(() => _selectedType = set.first),
              ),
              const SizedBox(height: 16),

              // Auto screenshot preview
              if (widget.autoScreenshot != null) ...[
                const Text('Auto-captured screenshot:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(widget.autoScreenshot!,
                      height: 180, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
              ],

              // Description field
              TextField(
                controller: _descController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe the bug, crash, or suggestion…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Voice button
              Row(
                children: [
                  IconButton.filled(
                    onPressed: _toggleVoice,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    color: _isRecording ? Colors.red : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isRecording
                          ? 'Recording… tap to stop'
                          : _voiceTranscript.isEmpty
                              ? 'Tap mic to describe by voice'
                              : '✓ Voice added to description',
                      style: TextStyle(
                          color: _isRecording ? Colors.red : Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Photo picker
              const Text('Add photos:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              PhotoPickerWidget(
                onPhotosChanged: (photos) => setState(() {
                  _userPhotos.clear();
                  _userPhotos.addAll(photos);
                }),
              ),

              // Crash log (collapsible)
              if (widget.crashLog != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Crash details'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[100],
                      child: Text(
                        widget.crashLog!,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Report'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }
}

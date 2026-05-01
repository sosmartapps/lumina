import 'dart:io';
import 'report_type.dart';

class BugReport {
  final String id;
  final ReportType type;
  final String description;
  final String? voiceTranscript;
  final List<File> screenshots;
  final List<File> userPhotos;
  final String? crashLog;
  final String appName;
  final String appVersion;
  final String buildNumber;
  final String deviceModel;
  final String osVersion;
  final DateTime timestamp;

  const BugReport({
    required this.id,
    required this.type,
    required this.description,
    this.voiceTranscript,
    required this.screenshots,
    required this.userPhotos,
    this.crashLog,
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
    required this.deviceModel,
    required this.osVersion,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'description': description,
        'voiceTranscript': voiceTranscript,
        'crashLog': crashLog,
        'appName': appName,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'timestamp': timestamp.toIso8601String(),
        // screenshots/photos are uploaded separately as multipart
      };

  /// All attached files (auto screenshot + user-added photos).
  List<File> get allAttachments => [...screenshots, ...userPhotos];
}

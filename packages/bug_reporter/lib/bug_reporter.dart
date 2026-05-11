/// Bug Reporter — shared package for all So Smart Apps.
/// Provides crash detection, screenshot capture, voice-to-text,
/// photo attachments, and report submission.
library;

export 'models/bug_report.dart';
export 'models/report_type.dart';
export 'services/crash_handler.dart';
export 'services/screenshot_service.dart';
export 'services/voice_recorder.dart';
export 'services/report_uploader.dart';
export 'ui/bug_report_fab.dart';
export 'ui/bug_report_sheet.dart';
export 'ui/photo_picker_widget.dart';
export 'bug_reporter_initializer.dart';

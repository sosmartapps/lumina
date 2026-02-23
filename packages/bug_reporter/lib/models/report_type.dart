enum ReportType {
  bug,
  crash,
  suggestion;

  String get label => switch (this) {
        ReportType.bug => '🐛 Bug',
        ReportType.crash => '💥 Crash',
        ReportType.suggestion => '💡 Suggestion',
      };
}
